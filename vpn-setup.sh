#!/bin/bash

# CipherShark
# By Kiarash Alizadeh
# https://github.com/kiarashAlizadeh
# Ubuntu 22 VPN Server Setup Script
# Supports 3X-UI, Outline VPN, SSH VPN, and L2TP/IPSec
# Author: VPN Setup Assistant
# Compatible with Ubuntu 22.04 LTS

set -e

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

# VPN configuration variables
XUI_USERNAME=""
XUI_PASSWORD=""
XUI_ACCESS_URL=""
OUTLINE_API_URL=""
SSH_VPN_USER=""
SSH_VPN_PASS=""
SSH_VPN_UDPGW_PORT=""
L2TP_PSK=""
L2TP_USERNAME=""
L2TP_PASSWORD=""
SERVER_IP=""

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
    
    # Method 4: hostname -I and filter IPv4 as fallback
    if [[ -z "$SERVER_IP" ]]; then
        SERVER_IP=$(hostname -I | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | head -1 2>/dev/null || echo "")
    fi
    
    # Method 5: ip route get to find the primary IPv4
    if [[ -z "$SERVER_IP" ]]; then
        SERVER_IP=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K[0-9.]+' || echo "")
    fi
    
    # Validate if it's a proper IPv4 and not a private address
    if [[ $SERVER_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] && 
       [[ ! $SERVER_IP =~ ^192\.168\. ]] && 
       [[ ! $SERVER_IP =~ ^10\. ]] && 
       [[ ! $SERVER_IP =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] &&
       [[ ! $SERVER_IP =~ ^127\. ]]; then
        print_info "Server IPv4 detected: $SERVER_IP"
    else
        SERVER_IP="YOUR_SERVER_IP"
        print_warning "Could not detect public IPv4 address. Please replace YOUR_SERVER_IP manually."
    fi
}

# Function to collect all user preferences
collect_user_preferences() {
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
    fi
    
    if ask_yes_no "Do you want to install Outline VPN?"; then
        INSTALL_OUTLINE="yes"
    fi
    
    if ask_yes_no "Do you want to setup SSH VPN user account?"; then
        SETUP_SSH_VPN="yes"
        get_input "Enter username for SSH VPN:" "SSH_VPN_USER" "false"
        get_input "Enter password for SSH VPN:" "SSH_VPN_PASS" "true"
        while true; do
            get_input "Enter UDPGW port for SSH VPN (avoid default 7300):" "SSH_VPN_UDPGW_PORT" "false"
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
    fi
    
    if ask_yes_no "Do you want to install L2TP/IPSec VPN?"; then
        INSTALL_L2TP="yes"
        get_input "Enter PSK (Pre-Shared Key) for L2TP:" "L2TP_PSK" "false"
        get_input "Enter username for L2TP VPN:" "L2TP_USERNAME" "false"
        get_input "Enter password for L2TP VPN:" "L2TP_PASSWORD" "true"
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
        echo -e "$NEW_ADMIN_PASS\n$NEW_ADMIN_PASS" | passwd "$NEW_ADMIN_USER"
        
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
            ufw allow 2087/tcp comment '3X-UI Panel'
            print_info "Opened port 2087 for 3X-UI Panel"
        fi
        
        if [[ $INSTALL_OUTLINE == "yes" ]]; then
            ufw allow 443/tcp comment 'Outline VPN'
            ufw allow 443/udp comment 'Outline VPN UDP'
            # Outline uses random high ports, we'll add them after installation
        fi
        
        if [[ $SETUP_SSH_VPN == "yes" ]]; then
            ufw allow "$SSH_VPN_UDPGW_PORT"/udp comment 'SSH VPN UDPGW'
            print_info "Opened port $SSH_VPN_UDPGW_PORT for SSH VPN UDPGW"
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
2087
EOF
        
        # Display the installation output
        cat /tmp/3xui_install.txt
        
        sleep 3
        
        # Extract Access URL from installation output - look for the correct pattern
        if grep -q "Access URL:" /tmp/3xui_install.txt; then
            # Extract the full Access URL including the path
            XUI_ACCESS_URL=$(grep "Access URL:" /tmp/3xui_install.txt | sed 's/.*Access URL: //' | sed 's/[[:space:]].*//')
            print_info "Found 3X-UI Access URL: $XUI_ACCESS_URL"
            
            # If the extracted URL contains IPv6, replace with IPv4
            if [[ $XUI_ACCESS_URL == *"["*"]"* ]] || [[ $XUI_ACCESS_URL == *":"*":"* ]]; then
                # Extract port and path from the URL
                PORT_AND_PATH=$(echo "$XUI_ACCESS_URL" | sed 's/.*:\([0-9]\+.*\)/\1/')
                XUI_ACCESS_URL="http://$SERVER_IP:$PORT_AND_PATH"
                print_info "Converted IPv6 to IPv4 URL: $XUI_ACCESS_URL"
            fi
        else
            XUI_ACCESS_URL="http://$SERVER_IP:2087"
            print_warning "Could not extract Access URL from output, using default: $XUI_ACCESS_URL"
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
        
        # Try to extract API URL from output
        if grep -q "apiUrl" /tmp/outline_output.txt; then
            OUTLINE_API_URL=$(grep -o '{"apiUrl":"[^"]*","certSha256":"[^"]*"}' /tmp/outline_output.txt | head -1)
            print_success "Outline VPN installation completed"
            print_info "API configuration captured for final display"
            
            # Extract and open firewall port for Outline
            if [[ $SETUP_FIREWALL == "yes" ]] && grep -q "Access key port" /tmp/outline_output.txt; then
                OUTLINE_PORT=$(grep "Access key port" /tmp/outline_output.txt | grep -o '[0-9]\+' | head -1)
                if [[ -n "$OUTLINE_PORT" ]]; then
                    ufw allow "$OUTLINE_PORT"/tcp comment 'Outline VPN Access'
                    ufw allow "$OUTLINE_PORT"/udp comment 'Outline VPN Access'
                    print_info "Opened port $OUTLINE_PORT for Outline VPN"
                fi
            fi
        else
            print_success "Outline VPN installation completed"
            print_warning "Please check the output above for API URL and certificate information"
        fi
        
        # Clean up temporary files
        rm -f /tmp/outline_install.sh /tmp/outline_output.txt
    fi
}

# Function to create SSH VPN user
create_ssh_vpn_user() {
    if [[ $SETUP_SSH_VPN == "yes" ]]; then
        print_header "Setting up SSH VPN User"
        
        print_info "Creating SSH VPN user: $SSH_VPN_USER"
        
        # Create user and configure
        sudo adduser --gecos "" "$SSH_VPN_USER" << EOF
$SSH_VPN_PASS
$SSH_VPN_PASS




y
EOF
        
        # Configure user for VPN only
        sudo usermod -s /usr/sbin/nologin "$SSH_VPN_USER"
        sudo mkdir -p /run/sshd
        sudo chmod 755 /run/sshd
        
        # Configure SSH for port forwarding
        if ! grep -q '^AllowTcpForwarding yes' /etc/ssh/sshd_config; then
            echo 'AllowTcpForwarding yes' | sudo tee -a /etc/ssh/sshd_config > /dev/null
        fi
        
        if ! grep -q '^X11Forwarding no' /etc/ssh/sshd_config; then
            echo 'X11Forwarding no' | sudo tee -a /etc/ssh/sshd_config > /dev/null
        fi
        
        # Remove existing Match User section if present
        sudo sed -i "/^Match User $SSH_VPN_USER/,/^$/d" /etc/ssh/sshd_config
        
        # Add restricted access for VPN user
        echo -e "\nMatch User $SSH_VPN_USER\n    ForceCommand echo 'Restricted to port forwarding only.'" | sudo tee -a /etc/ssh/sshd_config > /dev/null
        
        # Test and restart SSH
        sudo sshd -t
        sudo systemctl restart ssh
        
        print_success "SSH VPN user created and configured"
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

# Function to display final configuration
display_final_config() {
    print_header "Installation Complete! 🎉"
    
    print_colored $GREEN "🎊 All selected services have been installed successfully!"
    echo ""
    
    if [[ $INSTALL_3XUI == "yes" ]]; then
        print_colored $PURPLE "📱 3X-UI Panel Information:"
        print_colored $WHITE "   Access URL: $XUI_ACCESS_URL"
        print_colored $WHITE "   Username: $XUI_USERNAME"
        print_colored $WHITE "   Password: $XUI_PASSWORD"
        echo ""
    fi
    
    if [[ $INSTALL_OUTLINE == "yes" ]]; then
        print_colored $PURPLE "🔒 Outline VPN Information:"
        print_colored $WHITE "   Server IP: $SERVER_IP"
        print_colored $WHITE "   Port: 443"
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
        print_colored $WHITE "   Username: $SSH_VPN_USER"
        print_colored $WHITE "   Password: $SSH_VPN_PASS"
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
        print_colored $WHITE "   Use: ssh user@$SERVER_IP -p $NEW_SSH_PORT"
        echo ""
    fi
    
    if [[ $SETUP_FIREWALL == "yes" ]]; then
        print_colored $GREEN "🔥 Firewall Status: ENABLED"
        local firewall_ports="$FIREWALL_SSH_PORT (SSH), 80 (HTTP), 443 (HTTPS)"
        if [[ $INSTALL_3XUI == "yes" ]]; then
            firewall_ports="$firewall_ports, 2087 (3X-UI)"
        fi
        if [[ $SETUP_SSH_VPN == "yes" ]]; then
            firewall_ports="$firewall_ports, $SSH_VPN_UDPGW_PORT (UDPGW)"
        fi
        print_colored $WHITE "   Allowed ports: $firewall_ports"
        echo ""
    fi
    
    print_colored $CYAN "📋 Next Steps:"
    print_colored $WHITE "   1. Save this configuration information"
    print_colored $WHITE "   2. Test all connections before closing this terminal"
    print_colored $WHITE "   3. Configure your VPN clients with the provided information"
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
    
    # Execute installations based on user choices
    change_root_password
    update_system
    setup_security
    setup_firewall_rules
    install_3x_ui
    install_outline_vpn
    create_ssh_vpn_user
    install_l2tp_vpn
    
    # Display final configuration
    display_final_config
}

# Run the main function
main "$@"
