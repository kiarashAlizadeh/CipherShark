#!/bin/bash

# CipherShark
# By Kiarash Alizadeh
# https://github.com/kiarashAlizadeh
# Ubuntu 22 VPN Server Setup Script
# Supports 3X-UI, Outline VPN, SSH VPN, and L2TP/IPSec
# Author: VPN Setup Assistant
# Compatible with Ubuntu 22.04 LTS

# Don't exit on error, handle errors manually
set +e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Global variables to store user choices and data
CHANGE_PASSWORD=""
NEW_PASSWORD=""
INSTALL_3XUI=""
INSTALL_OUTLINE=""
SETUP_SSH_VPN=""
INSTALL_L2TP=""
DISABLE_ROOT_SSH=""
NEW_ADMIN_USER=""
NEW_ADMIN_PASS=""
CHANGE_SSH_PORT=""
NEW_SSH_PORT=""
SETUP_FIREWALL=""
FIREWALL_SSH_PORT=""
REBOOT_SERVER=""
RUN_SPEED_TEST=""

# VPN configuration variables
XUI_USERNAME=""
XUI_PASSWORD=""
XUI_ACCESS_URL=""
XUI_PANEL_PORT=""
OUTLINE_API_URL=""
OUTLINE_MANAGEMENT_PORT=""
OUTLINE_ACCESS_PORT=""
SSH_VPN_UDPGW_PORT=""
L2TP_PSK=""
L2TP_USERNAME=""
L2TP_PASSWORD=""
SERVER_IP=""
SPEED_TEST_RESULTS=""

# Array to store multiple SSH VPN users
declare -a SSH_VPN_USERS=()
declare -a SSH_VPN_PASSWORDS=()

# Function to print colored output
print_colored() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to print section headers
print_header() {
    echo ""
    print_colored $CYAN "================================================="
    print_colored $CYAN "🚀 $1"
    print_colored $CYAN "================================================="
    echo ""
}

# Function to print success messages
print_success() {
    print_colored $GREEN "✅ $1"
}

# Function to print error messages
print_error() {
    print_colored $RED "❌ ERROR: $1"
}

# Function to print warning messages
print_warning() {
    print_colored $YELLOW "⚠️  WARNING: $1"
}

# Function to print info messages
print_info() {
    print_colored $BLUE "ℹ️  $1"
}

# Function to ask yes/no questions
ask_yes_no() {
    local question=$1
    local response
    while true; do
        print_colored $YELLOW "❓ $question (y/n): "
        read -r response
        case $response in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) print_error "Please answer yes (y) or no (n).";;
        esac
    done
}

# Function to get user input
get_input() {
    local prompt=$1
    local variable_name=$2
    local is_password=$3
    
    print_colored $CYAN "📝 $prompt"
    if [[ $is_password == "true" ]]; then
        read -s -r input
        echo ""
    else
        read -r input
    fi
    
    eval "$variable_name='$input'"
}

# Function to validate port number
validate_port() {
    local port=$1
    if [[ $port =~ ^[0-9]+$ ]] && [ $port -ge 1 ] && [ $port -le 65535 ]; then
        return 0
    else
        return 1
    fi
}

# Function to get server IP address (IPv4 only)
get_server_ip() {
    # Try multiple methods to get external IPv4
    SERVER_IP=""
    
    print_info "Detecting server's public IPv4 address..."
    
    # Method 1: ifconfig.co with IPv4 force
    SERVER_IP=$(curl -s --connect-timeout 10 -4 ifconfig.co 2>/dev/null | grep -oE "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$" || echo "")
    
    # Method 2: ipinfo.io if first fails
    if [[ -z "$SERVER_IP" ]]; then
        SERVER_IP=$(curl -s --connect-timeout 10 -4 ipinfo.io/ip 2>/dev/null | grep -oE "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$" || echo "")
    fi
    
    # Method 3: ipv4.icanhazip.com if second fails
    if [[ -z "$SERVER_IP" ]]; then
        SERVER_IP=$(curl -s --connect-timeout 10 ipv4.icanhazip.com 2>/dev/null | grep -oE "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$" || echo "")
    fi
    
    # Method 4: dig command as additional fallback
    if [[ -z "$SERVER_IP" ]]; then
        SERVER_IP=$(dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null | grep -oE "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$" || echo "")
    fi
    
    # Method 5: hostname -I and filter IPv4 as fallback
    if [[ -z "$SERVER_IP" ]]; then
        SERVER_IP=$(hostname -I | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | head -1 2>/dev/null || echo "")
    fi
    
    # Method 6: ip route get to find the primary IPv4
    if [[ -z "$SERVER_IP" ]]; then
        SERVER_IP=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K[0-9.]+' || echo "")
    fi
    
    # Validate if it's a proper IPv4 and not a private address
    if [[ $SERVER_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] && 
       [[ ! $SERVER_IP =~ ^192\.168\. ]] && 
       [[ ! $SERVER_IP =~ ^10\. ]] && 
       [[ ! $SERVER_IP =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] &&
       [[ ! $SERVER_IP =~ ^127\. ]]; then
        print_success "Server IPv4 detected: $SERVER_IP"
    else
        # If we still don't have a valid IP, try to get it from the config file
        if [[ -n "$SERVER_IP_FROM_CONFIG" && "$SERVER_IP_FROM_CONFIG" != "" ]]; then
            SERVER_IP="$SERVER_IP_FROM_CONFIG"
            print_info "Using server IP from config file: $SERVER_IP"
        else
            SERVER_IP="YOUR_SERVER_IP"
            print_warning "Could not detect public IPv4 address. Please replace YOUR_SERVER_IP manually."
        fi
    fi
}

# Function to collect SSH VPN users
collect_ssh_vpn_users() {
    local user_counter=1
    local temp_username
    local temp_password
    
    print_info "Now collecting SSH VPN user information..."
    print_info "All users will share the same UDPGW port for efficiency"
    
    while true; do
        print_colored $CYAN "📋 Creating SSH VPN User #$user_counter"
        
        # Get username and validate it's not empty and doesn't already exist
        while true; do
            get_input "Enter username for SSH VPN user #$user_counter:" "temp_username" "false"
            
            if [[ -z "$temp_username" ]]; then
                print_error "Username cannot be empty. Please enter a valid username."
                continue
            fi
            
            # Check if username already exists in our array
            local username_exists=false
            for existing_user in "${SSH_VPN_USERS[@]}"; do
                if [[ "$existing_user" == "$temp_username" ]]; then
                    username_exists=true
                    break
                fi
            done
            
            # Check if username already exists on system
            if id "$temp_username" &>/dev/null; then
                print_error "Username '$temp_username' already exists on the system. Please choose a different username."
                continue
            fi
            
            if [[ "$username_exists" == "true" ]]; then
                print_error "Username '$temp_username' is already in your SSH VPN user list. Please choose a different username."
                continue
            fi
            
            break
        done
        
        # Get password
        while true; do
            get_input "Enter password for SSH VPN user '$temp_username':" "temp_password" "true"
            if [[ -z "$temp_password" ]]; then
                print_error "Password cannot be empty. Please enter a valid password."
                continue
            fi
            break
        done
        
        # Add to arrays
        SSH_VPN_USERS+=("$temp_username")
        SSH_VPN_PASSWORDS+=("$temp_password")
        
        print_success "SSH VPN user '$temp_username' added to the list"
        
        # Ask if they want to add more users
        if ask_yes_no "Do you want to add another SSH VPN user?"; then
            ((user_counter++))
        else
            break
        fi
    done
    
    print_success "Total SSH VPN users to be created: ${#SSH_VPN_USERS[@]}"
    
    # Show summary
    print_info "SSH VPN Users Summary:"
    for i in "${!SSH_VPN_USERS[@]}"; do
        print_colored $WHITE "   User $((i+1)): ${SSH_VPN_USERS[i]}"
    done
}

# Load configuration from a config file
load_config_file() {
  local config_file="$1"

  # Disable history expansion so '!' in passwords won't break
  set +H

  if [[ -f "$config_file" ]]; then
    echo "Loading configuration from $config_file..."

    # Source the config file directly to keep original formatting
    source "$config_file"

    # Map config file variables to script variables
    if [[ -n "$CHANGE_ROOT_PASSWORD" ]]; then
        CHANGE_PASSWORD="$CHANGE_ROOT_PASSWORD"
        NEW_PASSWORD="$NEW_ROOT_PASSWORD"
    fi
    
    if [[ -n "$NEW_ADMIN_USER" ]]; then
        NEW_ADMIN_USER="$NEW_ADMIN_USER"
        NEW_ADMIN_PASS="$NEW_ADMIN_PASSWORD"
    fi
    
    if [[ -n "$CHANGE_SSH_PORT" ]]; then
        CHANGE_SSH_PORT="$CHANGE_SSH_PORT"
    fi
    
    if [[ -n "$NEW_SSH_PORT" ]]; then
        NEW_SSH_PORT="$NEW_SSH_PORT"
        CHANGE_SSH_PORT="yes"
    fi
    
    # Set firewall SSH port if SSH port is changed
    if [[ $CHANGE_SSH_PORT == "yes" ]]; then
        FIREWALL_SSH_PORT="$NEW_SSH_PORT"
    else
        FIREWALL_SSH_PORT="22"
    fi
    
    # Load firewall setting from config
    if [[ -n "$SETUP_FIREWALL" ]]; then
        SETUP_FIREWALL="$SETUP_FIREWALL"
    fi
    
    if [[ -n "$XUI_USERNAME" ]]; then
        XUI_USERNAME="$XUI_USERNAME"
        XUI_PASSWORD="$XUI_PASSWORD"
        XUI_PANEL_PORT="$XUI_PANEL_PORT"
    fi
    
    if [[ -n "$SSH_VPN_UDPGW_PORT" ]]; then
        SSH_VPN_UDPGW_PORT="$SSH_VPN_UDPGW_PORT"
    fi
    
    if [[ -n "$L2TP_PSK" ]]; then
        L2TP_PSK="$L2TP_PSK"
        L2TP_USERNAME="$L2TP_USERNAME"
        L2TP_PASSWORD="$L2TP_PASSWORD"
    fi
    
    # Process SSH VPN users from config file
    if [[ -n "$SSH_VPN_USERS" && ${#SSH_VPN_USERS[@]} -gt 0 ]]; then
        # Store the original array from config file before clearing
        local config_ssh_users=("${SSH_VPN_USERS[@]}")
        
        # Clear the global arrays to rebuild them
        SSH_VPN_USERS=()
        SSH_VPN_PASSWORDS=()
        
        # Process each user entry from the config
        for user_entry in "${config_ssh_users[@]}"; do
            # Split username:password format
            local username=$(echo "$user_entry" | cut -d':' -f1)
            local password=$(echo "$user_entry" | cut -d':' -f2)
            
            if [[ -n "$username" && -n "$password" ]]; then
                SSH_VPN_USERS+=("$username")
                SSH_VPN_PASSWORDS+=("$password")
            fi
        done
        
        print_info "Loaded ${#SSH_VPN_USERS[@]} SSH VPN users from config file"
    else
        print_warning "No SSH VPN users found in configuration"
    fi
    
    # Set server IP from config if provided (only if not empty)
    if [[ -n "$SERVER_IP" && "$SERVER_IP" != "" ]]; then
        SERVER_IP_FROM_CONFIG="$SERVER_IP"
        print_info "Server IP from config: $SERVER_IP_FROM_CONFIG"
    else
        print_info "No server IP specified in config, will auto-detect"
    fi

  else
    echo "❌ Configuration file '$config_file' not found!"
    exit 1
  fi

  # Re-enable history expansion after loading
  set -H
}





# Function to ask for configuration file
ask_for_config_file() {
    print_header "Configuration File Detection"
    
    if ask_yes_no "Do you have a configuration file for automated setup?"; then
        while true; do
            print_info "Please enter the name of your configuration file"
            print_info "Common names: vpn-config.conf, config.conf, setup.conf"
            print_info "The file should be in the same directory as this script"

            local config_file=""
            get_input "Enter configuration file name:" "config_file" "false"

            if [[ -f "$config_file" ]]; then
                if load_config_file "$config_file"; then
                    return 0
                else
                    print_error "Failed to load configuration file. Falling back to interactive mode."
                    return 1
                fi
            else
                print_error "Configuration file '$config_file' not found!"
                if ask_yes_no "Do you want to try another file name?"; then
                    continue
                else
                    return 1
                fi
            fi
        done
    fi
    
    return 1
}

# Function to collect all user preferences
collect_user_preferences() {
    
    # First, try to load configuration file
    if ask_for_config_file; then
        print_success "Using configuration file for automated setup!"
        print_info "All settings will be applied automatically."
        print_info "Configuration loaded successfully - skipping interactive questions."
        print_info "All configuration values will be loaded from the config file."
        print_info "Proceeding with automated installation..."
        sleep 2
        return
    fi
    
    print_info "No configuration file found or selected."
    print_info "Starting interactive configuration mode..."
    print_info "You will be asked a series of questions to configure your VPN server."
    sleep 1
    
    print_header "Initial Configuration Questions"
    
    # Ask about password change
    if ask_yes_no "Do you want to change the root password?"; then
        CHANGE_PASSWORD="yes"
        get_input "Enter new root password:" "NEW_PASSWORD" "true"
    fi
    
    # Ask about security settings first
    print_header "Security Configuration"
    
    if ask_yes_no "Do you want to disable SSH access for root user?"; then
        DISABLE_ROOT_SSH="yes"
        get_input "Enter username for new admin user:" "NEW_ADMIN_USER" "false"
        get_input "Enter password for new admin user:" "NEW_ADMIN_PASS" "true"
    fi
    
    if ask_yes_no "Do you want to change SSH port from default (22)?"; then
        CHANGE_SSH_PORT="yes"
        while true; do
            get_input "Enter new SSH port number:" "NEW_SSH_PORT" "false"
            if validate_port "$NEW_SSH_PORT"; then
                break
            else
                print_error "Invalid port number. Please enter a number between 1-65535."
            fi
        done
    fi
    
    if ask_yes_no "Do you want to setup firewall (UFW)?"; then
        SETUP_FIREWALL="yes"
        if [[ $CHANGE_SSH_PORT == "yes" ]]; then
            FIREWALL_SSH_PORT=$NEW_SSH_PORT
        else
            FIREWALL_SSH_PORT="22"
        fi
    fi
    
    # Ask about VPN installations
    print_header "VPN Services Selection"
    
    if ask_yes_no "Do you want to install 3X-UI panel?"; then
        INSTALL_3XUI="yes"
        get_input "Enter username for 3X-UI panel:" "XUI_USERNAME" "false"
        get_input "Enter password for 3X-UI panel:" "XUI_PASSWORD" "true"
        
        # Get panel port from user
        while true; do
            get_input "Enter panel port for 3X-UI (default is 2087):" "XUI_PANEL_PORT" "false"
            if [[ -z "$XUI_PANEL_PORT" ]]; then
                XUI_PANEL_PORT="2087"
                break
            elif validate_port "$XUI_PANEL_PORT"; then
                break
            else
                print_error "Invalid port number. Please enter a number between 1-65535."
            fi
        done
    fi
    
    if ask_yes_no "Do you want to install Outline VPN?"; then
        INSTALL_OUTLINE="yes"
    fi
    
    if ask_yes_no "Do you want to setup SSH VPN user accounts?"; then
        SETUP_SSH_VPN="yes"
        
        # Get UDPGW port (shared for all users)
        while true; do
            get_input "Enter UDPGW port for SSH VPN (avoid default 7300, this port will be shared by all SSH VPN users):" "SSH_VPN_UDPGW_PORT" "false"
            if validate_port "$SSH_VPN_UDPGW_PORT"; then
                if [[ $SSH_VPN_UDPGW_PORT != "7300" ]]; then
                    break
                else
                    print_warning "Port 7300 is the default port. For security, please choose a different port."
                fi
            else
                print_error "Invalid port number. Please enter a number between 1-65535."
            fi
        done
        
        # Collect multiple SSH VPN users
        collect_ssh_vpn_users
    fi
    
    if ask_yes_no "Do you want to install L2TP/IPSec VPN?"; then
        INSTALL_L2TP="yes"
        get_input "Enter PSK (Pre-Shared Key) for L2TP:" "L2TP_PSK" "false"
        get_input "Enter username for L2TP VPN:" "L2TP_USERNAME" "false"
        get_input "Enter password for L2TP VPN:" "L2TP_PASSWORD" "true"
    fi
    
    # Ask about speed test
    print_header "Performance Testing"
    if ask_yes_no "Do you want to run a speed test after installation?"; then
        RUN_SPEED_TEST="yes"
    fi
    
    # Final question about server reboot
    print_header "Final Configuration"
    if ask_yes_no "Do you want to reboot the server after installation completes?"; then
        REBOOT_SERVER="yes"
    fi
    
    print_success "All preferences collected! Starting installation..."
    sleep 2
}

# Function to change root password
change_root_password() {
    if [[ $CHANGE_PASSWORD == "yes" ]]; then
        print_header "Changing Root Password"
        print_info "Setting new root password..."
        
        # Use chpasswd for reliable password change
        echo "root:$NEW_PASSWORD" | chpasswd
        
        print_success "Root password changed successfully"
    fi
}

# Function to setup security configurations
setup_security() {
    print_header "Configuring Security Settings"
    
    # Create admin user if needed
    if [[ $DISABLE_ROOT_SSH == "yes" ]]; then
        print_info "Creating new admin user: $NEW_ADMIN_USER"
        
        # Create user and set password
        useradd -m -s /bin/bash "$NEW_ADMIN_USER" || true
        
        # Set password using chpasswd for better reliability
        echo "$NEW_ADMIN_USER:$NEW_ADMIN_PASS" | chpasswd
        
        # Add to sudo group
        usermod -aG sudo "$NEW_ADMIN_USER"
        
        print_success "Admin user created with sudo privileges"
    fi
    
    # Configure SSH settings
    print_info "Configuring SSH settings..."
    
    # Backup original sshd_config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    
    # Disable root SSH if requested
    if [[ $DISABLE_ROOT_SSH == "yes" ]]; then
        sed -i 's/#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
        print_success "Root SSH access disabled"
    fi
    
    # Change SSH port if requested
    if [[ $CHANGE_SSH_PORT == "yes" ]]; then
        sed -i "s/#*Port.*/Port $NEW_SSH_PORT/" /etc/ssh/sshd_config
        print_success "SSH port changed to $NEW_SSH_PORT"
    fi
    
    # Restart SSH service
    systemctl restart ssh
    print_success "SSH configuration updated"
}

# Function to setup firewall
setup_firewall_rules() {
    if [[ $SETUP_FIREWALL == "yes" ]]; then
        print_header "Configuring Firewall (UFW)"
        
        # Install UFW if not present
        apt install -y ufw
        
        # Reset UFW rules
        ufw --force reset
        
        # Default policies
        ufw default deny incoming
        ufw default allow outgoing
        
        # Allow essential ports
        ufw allow "$FIREWALL_SSH_PORT"/tcp comment 'SSH'
        ufw allow 80/tcp comment 'HTTP'
        ufw allow 443/tcp comment 'HTTPS'
        
        # Allow VPN ports if services will be installed
        if [[ $INSTALL_3XUI == "yes" ]]; then
            ufw allow "$XUI_PANEL_PORT"/tcp comment '3X-UI Panel'
            print_info "Opened port $XUI_PANEL_PORT for 3X-UI Panel"
        fi
        
        if [[ $INSTALL_OUTLINE == "yes" ]]; then
            ufw allow 443/tcp comment 'Outline VPN'
            ufw allow 443/udp comment 'Outline VPN UDP'
            print_info "Pre-opened common Outline ports (specific ports will be added after installation)"
        fi
        
        if [[ $SETUP_SSH_VPN == "yes" ]]; then
            ufw allow "$SSH_VPN_UDPGW_PORT"/udp comment 'SSH VPN UDPGW'
            print_info "Opened port $SSH_VPN_UDPGW_PORT for SSH VPN UDPGW (shared by all SSH VPN users)"
        fi
        
        if [[ $INSTALL_L2TP == "yes" ]]; then
            ufw allow 500/udp comment 'L2TP IPSec'
            ufw allow 4500/udp comment 'L2TP IPSec NAT'
            ufw allow 1701/udp comment 'L2TP'
            print_info "Opened L2TP/IPSec ports"
        fi
        
        # Enable UFW
        ufw --force enable
        
        print_success "Firewall configured and enabled"
    fi
}

# Function to update system
update_system() {
    print_header "Updating System Packages"
    
    export DEBIAN_FRONTEND=noninteractive
    apt update
    apt install -y curl wget unzip software-properties-common
    
    print_success "System updated successfully"
}

# Function to install 3X-UI
install_3x_ui() {
    if [[ $INSTALL_3XUI == "yes" ]]; then
        print_header "Installing 3X-UI Panel"
        
        # Download and run installation script with output capture
        print_info "Downloading 3X-UI installation script..."
        
        # Capture 3X-UI installation output
        bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh) << EOF > /tmp/3xui_install.txt 2>&1
y
$XUI_PANEL_PORT
EOF
        
        # Display the installation output
        cat /tmp/3xui_install.txt
        
        sleep 3
        
        # Extract Access URL from installation output - look for the correct pattern
        if grep -q "Access URL:" /tmp/3xui_install.txt; then
            # Extract the full Access URL including the path - use the exact URL from output
            XUI_ACCESS_URL=$(grep "Access URL:" /tmp/3xui_install.txt | sed 's/.*Access URL: //' | sed 's/[[:space:]].*//')
            print_info "Found 3X-UI Access URL: $XUI_ACCESS_URL"
            
        else
            print_warning "Could not extract Access URL from 3X-UI installation output"
            print_info "Please check the installation output above for the correct Access URL"
            XUI_ACCESS_URL=""
        fi
        
        # Configure 3X-UI with custom credentials
        print_info "Configuring 3X-UI credentials..."
        x-ui << EOF
6
y
$XUI_USERNAME
$XUI_PASSWORD
y
y

0
EOF
        
        # Clean up temp file
        rm -f /tmp/3xui_install.txt
        
        print_success "3X-UI installation completed"
        print_info "Custom credentials set: $XUI_USERNAME"
    fi
}

# Function to install Outline VPN
install_outline_vpn() {
    if [[ $INSTALL_OUTLINE == "yes" ]]; then
        print_header "Installing Outline VPN"
        
        print_info "Downloading and installing Outline server..."
        
        # Download the installation script first
        wget -O /tmp/outline_install.sh https://raw.githubusercontent.com/Jigsaw-Code/outline-server/master/src/server_manager/install_scripts/install_server.sh
        
        # Make it executable and run with automatic 'Y' response
        chmod +x /tmp/outline_install.sh
        echo "Y" | bash /tmp/outline_install.sh > /tmp/outline_output.txt 2>&1
        
        # Display installation output
        cat /tmp/outline_output.txt
        
        # Try to extract API URL and ports from output
        if grep -q "apiUrl" /tmp/outline_output.txt; then
            OUTLINE_API_URL=$(grep -o '{"apiUrl":"[^"]*","certSha256":"[^"]*"}' /tmp/outline_output.txt | head -1)
            
            # Extract Management port from API URL
            if [[ -n "$OUTLINE_API_URL" ]]; then
                OUTLINE_MANAGEMENT_PORT=$(echo "$OUTLINE_API_URL" | grep -o ':[0-9]\+/' | sed 's/[:/]//g')
                print_info "Extracted Management port: $OUTLINE_MANAGEMENT_PORT"
            fi
            
            # Extract Access key port from output text
            if grep -q "Access key port" /tmp/outline_output.txt; then
                OUTLINE_ACCESS_PORT=$(grep "Access key port" /tmp/outline_output.txt | grep -o '[0-9]\+' | head -1)
                print_info "Extracted Access key port: $OUTLINE_ACCESS_PORT"
            fi
            
            # Open firewall ports for Outline if firewall is enabled
            if [[ $SETUP_FIREWALL == "yes" ]]; then
                if [[ -n "$OUTLINE_MANAGEMENT_PORT" ]]; then
                    ufw allow "$OUTLINE_MANAGEMENT_PORT"/tcp comment 'Outline Management'
                    print_info "Opened port $OUTLINE_MANAGEMENT_PORT for Outline Management"
                fi
                
                if [[ -n "$OUTLINE_ACCESS_PORT" ]]; then
                    ufw allow "$OUTLINE_ACCESS_PORT"/tcp comment 'Outline Access'
                    ufw allow "$OUTLINE_ACCESS_PORT"/udp comment 'Outline Access'
                    print_info "Opened port $OUTLINE_ACCESS_PORT for Outline Access (TCP and UDP)"
                fi
            fi
            
            print_success "Outline VPN installation completed"
            print_info "API configuration captured for final display"
        else
            print_success "Outline VPN installation completed"
            print_warning "Please check the output above for API URL and certificate information"
        fi
        
        # Clean up temporary files
        rm -f /tmp/outline_install.sh /tmp/outline_output.txt
    fi
}

# Function to create SSH VPN users
create_ssh_vpn_users() {
    if [[ $SETUP_SSH_VPN == "yes" ]]; then
        print_header "Setting up SSH VPN Users"
        
        # Configure SSH for port forwarding first (only once)
        print_info "Configuring SSH for VPN support..."
        
        mkdir -p /run/sshd
        chmod 755 /run/sshd
        
        # Configure SSH for port forwarding
        if ! grep -q '^AllowTcpForwarding yes' /etc/ssh/sshd_config; then
            echo 'AllowTcpForwarding yes' >> /etc/ssh/sshd_config
        fi
        
        if ! grep -q '^X11Forwarding no' /etc/ssh/sshd_config; then
            echo 'X11Forwarding no' >> /etc/ssh/sshd_config
        fi
        
        # Check if we have SSH VPN users from config file
        if [[ ${#SSH_VPN_USERS[@]} -eq 0 ]]; then
            print_warning "No SSH VPN users found in configuration"
            print_info "SSH VPN users should be defined in the config file as:"
            print_info "SSH_VPN_USERS=(\"username1:password1\" \"username2:password2\")"
            return 0
        fi
        
        # Create each SSH VPN user
        local created_users=0
        for i in "${!SSH_VPN_USERS[@]}"; do
            local username="${SSH_VPN_USERS[i]}"
            local password="${SSH_VPN_PASSWORDS[i]}"
            
            # Validate username and password
            if [[ -z "$username" || -z "$password" ]]; then
                print_error "Invalid user entry at index $i: username='$username', password='$password'"
                continue
            fi
            
            print_info "Creating SSH VPN user $((i+1)): $username"
            
            # Create user with better error handling
            if id "$username" &>/dev/null; then
                print_warning "User '$username' already exists, skipping creation"
                ((created_users++))
            else
                if adduser --gecos "$username" --disabled-password "$username" 2>/dev/null; then
                    # Set password using chpasswd
                    echo "$username:$password" | chpasswd
                    
                    # Configure user for VPN only - use a simpler approach
                    usermod -s /usr/sbin/nologin "$username"
                    
                    # Create a simple welcome message for VPN users
                    echo "Welcome to SSH VPN user $username - This account is restricted to port forwarding only." > "/home/$username/.hushlogin"
                    chown "$username:$username" "/home/$username/.hushlogin"
                    
                    print_success "SSH VPN user '$username' created and configured"
                    ((created_users++))
                else
                    print_error "Failed to create SSH VPN user '$username'"
                fi
            fi
        done
        
        # Test and restart SSH (only once at the end)
        if [[ $created_users -gt 0 ]]; then
            print_info "Testing SSH configuration..."
            if sshd -t; then
                systemctl restart ssh
                print_success "SSH service restarted successfully"
                print_success "Total SSH VPN users created: $created_users"
            else
                print_warning "SSH configuration test failed, but continuing with installation..."
                print_info "SSH service may need manual configuration"
            fi
        fi
    fi
}

# Function to install L2TP/IPSec VPN
install_l2tp_vpn() {
    if [[ $INSTALL_L2TP == "yes" ]]; then
        print_header "Installing L2TP/IPSec VPN"
        
        # Set configuration variables
        local VPN_IP_RANGE_START="192.168.42.10"
        local VPN_IP_RANGE_END="192.168.42.250"
        local VPN_LOCAL_IP="192.168.42.1"
        local INTERFACE=$(ip route | grep default | awk '{print $5}')
        
        print_info "Installing required packages..."
        
        # Install packages
        export DEBIAN_FRONTEND=noninteractive
        apt install -y strongswan xl2tpd ppp iptables-persistent
        
        print_info "Configuring strongSwan..."
        
        # Configure strongSwan
        cat > /etc/ipsec.conf <<EOF
config setup
    uniqueids=no

conn %default
    keyexchange=ikev1
    authby=secret
    ike=aes256-sha1-modp1024!
    esp=aes256-sha1!

conn L2TP-PSK
    keyexchange=ikev1
    authby=secret
    type=transport
    left=%any
    leftprotoport=17/1701
    right=%any
    rightprotoport=17/1701
    auto=add
EOF
        
        # Set PSK
        cat > /etc/ipsec.secrets <<EOF
: PSK "$L2TP_PSK"
EOF
        
        print_info "Configuring xl2tpd..."
        
        # Configure xl2tpd
        cat > /etc/xl2tpd/xl2tpd.conf <<EOF
[global]
ipsec saref = yes

[lns default]
ip range = $VPN_IP_RANGE_START-$VPN_IP_RANGE_END
local ip = $VPN_LOCAL_IP
require chap = yes
refuse pap = yes
require authentication = yes
name = L2TPServer
ppp debug = yes
pppoptfile = /etc/ppp/options.xl2tpd
length bit = yes
EOF
        
        # Configure PPP options
        cat > /etc/ppp/options.xl2tpd <<EOF
require-mschap-v2
ms-dns 8.8.8.8
ms-dns 8.8.4.4
auth
mtu 1280
mru 1280
noccp
persist
logfile /var/log/ppp.log
EOF
        
        # Create VPN user
        cat > /etc/ppp/chap-secrets <<EOF
$L2TP_USERNAME    L2TPServer   $L2TP_PASSWORD   *
EOF
        
        print_info "Enabling IP forwarding..."
        
        # Enable IP forwarding
        if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
            echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
        fi
        sysctl -p
        
        print_info "Configuring iptables..."
        
        # Configure iptables
        iptables -t nat -A POSTROUTING -o "$INTERFACE" -j MASQUERADE
        iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
        iptables -A FORWARD -s 192.168.42.0/24 -j ACCEPT
        
        # Save iptables rules
        netfilter-persistent save
        
        print_info "Starting services..."
        
        # Enable and start services
        systemctl enable ipsec --now
        systemctl enable xl2tpd --now
        
        systemctl restart ipsec
        systemctl restart xl2tpd
        
        print_success "L2TP/IPSec VPN installation completed"
    fi
}

# Function to install and run Speedtest
run_speed_test() {
    if [[ $RUN_SPEED_TEST == "yes" ]]; then
        print_header "Running Speed Test"
        
        print_info "Installing Speedtest CLI..."
        
        # Install speedtest-cli using official method
        curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash
        apt update
        apt install -y speedtest
        
        print_info "Running speed test... This may take a few moments."
        print_warning "Please wait while we test your server's internet connection speed."
        
        # Run speedtest and capture output
        if speedtest --accept-license --accept-gdpr > /tmp/speedtest_result.txt 2>&1; then
            # Display results
            print_success "Speed test completed!"
            
            # Extract key metrics from speedtest output
            local download_speed=$(grep -i "Download:" /tmp/speedtest_result.txt | awk '{print $2" "$3}' || echo "N/A")
            local upload_speed=$(grep -i "Upload:" /tmp/speedtest_result.txt | awk '{print $2" "$3}' || echo "N/A")
            local ping=$(grep -i "Idle Latency:" /tmp/speedtest_result.txt | awk '{print $3" "$4}' || echo "N/A")
            local server_info=$(grep -i "Server:" /tmp/speedtest_result.txt | cut -d':' -f2- | xargs || echo "N/A")
            
            # Store results for final display
            SPEED_TEST_RESULTS="Download: $download_speed | Upload: $upload_speed | Ping: $ping | Server: $server_info"
            
            print_info "Speed Test Results:"
            print_colored $WHITE "   Download Speed: $download_speed"
            print_colored $WHITE "   Upload Speed: $upload_speed"
            print_colored $WHITE "   Ping: $ping"
            print_colored $WHITE "   Test Server: $server_info"
            
            # Show full output if needed
            print_info "Full speed test output saved for reference"
            
        else
            print_error "Speed test failed. Network connectivity issues may exist."
            SPEED_TEST_RESULTS="Speed test failed - please check network connectivity"
        fi
        
        # Clean up
        rm -f /tmp/speedtest_result.txt
    fi
}

# Function to display final configuration
display_final_config() {
    print_header "Installation Complete! 🎉"
    
    print_colored $GREEN "🎊 All selected services have been installed successfully!"
    echo ""
    
    if [[ $INSTALL_3XUI == "yes" ]]; then
        print_colored $PURPLE "📱 3X-UI Panel Information:"
        if [[ -n "$XUI_ACCESS_URL" ]]; then
            print_colored $WHITE "   Access URL: $XUI_ACCESS_URL"
        else
            print_colored $YELLOW "   ⚠️  Access URL not found - please check installation output above"
        fi
        print_colored $WHITE "   Username: $XUI_USERNAME"
        print_colored $WHITE "   Password: $XUI_PASSWORD"
        echo ""
    fi
    
    if [[ $INSTALL_OUTLINE == "yes" ]]; then
        print_colored $PURPLE "🔒 Outline VPN Information:"
        if [[ -n "$OUTLINE_MANAGEMENT_PORT" ]]; then
            print_colored $WHITE "   Management Port: $OUTLINE_MANAGEMENT_PORT (TCP)"
        fi
        if [[ -n "$OUTLINE_ACCESS_PORT" ]]; then
            print_colored $WHITE "   Access Key Port: $OUTLINE_ACCESS_PORT (TCP & UDP)"
        fi
        if [[ -n "$OUTLINE_API_URL" ]]; then
            print_colored $WHITE "   API Config: $OUTLINE_API_URL"
        else
            print_colored $YELLOW "   ⚠️  Please check the installation output above for the API URL and certificate"
        fi
        echo ""
    fi
    
    if [[ $SETUP_SSH_VPN == "yes" ]]; then
        print_colored $PURPLE "🌐 SSH VPN Information:"
        print_colored $WHITE "   Server IP: $SERVER_IP"
        if [[ $CHANGE_SSH_PORT == "yes" ]]; then
            print_colored $WHITE "   SSH Port: $NEW_SSH_PORT"
        else
            print_colored $WHITE "   SSH Port: 22"
        fi
        print_colored $WHITE "   UDPGW Port: $SSH_VPN_UDPGW_PORT"
        
        # Check if we have SSH VPN users (either from config or interactive)
        if [[ ${#SSH_VPN_USERS[@]} -gt 0 ]]; then
            print_colored $WHITE "   Total Users Created: ${#SSH_VPN_USERS[@]}"
            echo ""
            
            # Display each SSH VPN user with counter
            for i in "${!SSH_VPN_USERS[@]}"; do
                print_colored $CYAN "   📋 SSH VPN USER $((i+1)):"
                print_colored $WHITE "      Username: ${SSH_VPN_USERS[i]}"
                print_colored $WHITE "      Password: ${SSH_VPN_PASSWORDS[i]}"
                if [[ $i -lt $((${#SSH_VPN_USERS[@]} - 1)) ]]; then
                    echo ""
                fi
            done
        else
            print_colored $YELLOW "   ⚠️  No SSH VPN users configured"
        fi
        echo ""
    fi
    
    if [[ $INSTALL_L2TP == "yes" ]]; then
        print_colored $PURPLE "🔐 L2TP/IPSec VPN Information:"
        print_colored $WHITE "   Server IP: $SERVER_IP"
        print_colored $WHITE "   PSK: $L2TP_PSK"
        print_colored $WHITE "   Username: $L2TP_USERNAME"
        print_colored $WHITE "   Password: $L2TP_PASSWORD"
        echo ""
    fi
    
    if [[ $RUN_SPEED_TEST == "yes" && -n "$SPEED_TEST_RESULTS" ]]; then
        print_colored $GREEN "🚀 Server Speed Test Results:"
        print_colored $WHITE "   $SPEED_TEST_RESULTS"
        echo ""
    fi
    
    if [[ $DISABLE_ROOT_SSH == "yes" ]]; then
        print_colored $YELLOW "🔒 Security Notice:"
        print_colored $WHITE "   Root SSH access has been disabled"
        print_colored $WHITE "   New admin user: $NEW_ADMIN_USER"
        print_colored $WHITE "   Use this account for future SSH connections"
        echo ""
    fi
    
    if [[ $CHANGE_SSH_PORT == "yes" ]]; then
        print_colored $YELLOW "🚪 SSH Port Changed:"
        print_colored $WHITE "   New SSH port: $NEW_SSH_PORT"
        # Determine the correct username to display
        local ssh_username="root"
        if [[ $DISABLE_ROOT_SSH == "yes" ]]; then
            ssh_username="$NEW_ADMIN_USER"
        fi
        print_colored $WHITE "   Use: ssh $ssh_username@$SERVER_IP -p $NEW_SSH_PORT"
        echo ""
    fi
    
    if [[ $SETUP_FIREWALL == "yes" ]]; then
        print_colored $GREEN "🔥 Firewall Status: ENABLED"
        local firewall_ports="$FIREWALL_SSH_PORT (SSH), 80 (HTTP), 443 (HTTPS)"
        if [[ $INSTALL_3XUI == "yes" ]]; then
            firewall_ports="$firewall_ports, $XUI_PANEL_PORT (3X-UI)"
        fi
        if [[ $INSTALL_OUTLINE == "yes" ]]; then
            if [[ -n "$OUTLINE_MANAGEMENT_PORT" ]] && [[ -n "$OUTLINE_ACCESS_PORT" ]]; then
                firewall_ports="$firewall_ports, $OUTLINE_MANAGEMENT_PORT (Outline Mgmt), $OUTLINE_ACCESS_PORT (Outline Access)"
            else
                firewall_ports="$firewall_ports, Outline ports"
            fi
        fi
        if [[ $SETUP_SSH_VPN == "yes" ]]; then
            firewall_ports="$firewall_ports, $SSH_VPN_UDPGW_PORT (UDPGW)"
        fi
        if [[ $INSTALL_L2TP == "yes" ]]; then
            firewall_ports="$firewall_ports, 500/4500/1701 (L2TP)"
        fi
        print_colored $WHITE "   Allowed ports: $firewall_ports"
        echo ""
    fi
    
    print_colored $CYAN "📋 Next Steps:"
    print_colored $WHITE "   1. Save this configuration information"
    print_colored $WHITE "   2. Test all connections before closing this terminal"
    print_colored $WHITE "   3. Configure your VPN clients with the provided information"
    if [[ $SETUP_SSH_VPN == "yes" && ${#SSH_VPN_USERS[@]} -gt 0 ]]; then
        print_colored $WHITE "   4. Multiple SSH VPN users can connect simultaneously using the same ports"
        print_colored $WHITE "   5. Each SSH VPN user will have their own isolated session"
    fi
    if [[ $INSTALL_OUTLINE == "yes" ]]; then
        print_colored $WHITE "   6. Use Outline Manager app to import the API config and create access keys"
    fi
    echo ""
    
    if [[ $REBOOT_SERVER == "yes" ]]; then
        print_colored $YELLOW "🔄 Server will reboot in 10 seconds..."
        print_colored $WHITE "   Press Ctrl+C to cancel reboot"
        echo ""
        for i in {10..1}; do
            print_colored $YELLOW "   Rebooting in $i seconds..."
            sleep 1
        done
        print_colored $GREEN "🔄 Rebooting server now..."
        reboot
    else
        print_colored $GREEN "✨ Enjoy your new VPN server! ✨"
    fi
}

# Error handling function
handle_error() {
    print_error "An error occurred during installation!"
    print_error "Error on line $1"
    print_info "Please check the output above for details"
    
    # Try to display final configuration even if there was an error
    if [[ -n "$SERVER_IP" ]]; then
        echo ""
        print_warning "Attempting to display partial configuration..."
        display_final_config
    fi
    
    exit 1
}

# Set error trap
trap 'handle_error $LINENO' ERR

# Main execution
main() {
    print_header "Ubuntu 22 VPN Server Setup Script"
    print_info "This script will help you set up multiple VPN services on Ubuntu 22.04"
    print_warning "Make sure you're running this as root!"
    
    sleep 2
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root!"
        exit 1
    fi
    
    # Get server IP first
    get_server_ip
    
    # Collect all user preferences first
    collect_user_preferences
    
    # Execute installations based on user choices (continue even if some fail)
    change_root_password || print_warning "Password change failed, continuing..."
    update_system || print_warning "System update failed, continuing..."
    setup_security || print_warning "Security setup failed, continuing..."
    setup_firewall_rules || print_warning "Firewall setup failed, continuing..."
    install_3x_ui || print_warning "3X-UI installation failed, continuing..."
    install_outline_vpn || print_warning "Outline VPN installation failed, continuing..."
    create_ssh_vpn_users || print_warning "SSH VPN user creation failed, continuing..."
    install_l2tp_vpn || print_warning "L2TP VPN installation failed, continuing..."
    
    # Run speed test if requested
    run_speed_test || print_warning "Speed test failed, continuing..."
    
    # Always display final configuration
    display_final_config
}

# Run the main function
main "$@"
