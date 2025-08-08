# CipherShark 🦈

**A powerful automated VPN server setup script for Ubuntu 22.04**

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04-orange.svg)](https://ubuntu.com/)
[![Bash](https://img.shields.io/badge/Bash-Script-green.svg)](https://www.gnu.org/software/bash/)

## 📋 Table of Contents

- [Introduction](#introduction)
- [Features](#features)
- [Supported VPN Services](#supported-vpn-services)
- [Installation & Setup](#installation-setup)
- [Configuration File Usage](#configuration-file-usage)
- [Configuration File Settings](#configuration-file-settings)
- [Sample Configuration File](#sample-configuration-file)
- [Usage Guide](#usage-guide)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

<h2 id="introduction">🚀 Introduction</h2>

CipherShark is an advanced Bash script that allows you to easily and automatically set up a complete VPN server on Ubuntu 22.04. This script supports multiple VPN protocols and includes advanced security features.

### ✨ Key Features

- **Automated Setup**: Complete VPN server installation and configuration without deep technical knowledge
- **Multi-Protocol Support**: 3X-UI, Outline VPN, SSH VPN, and L2TP/IPSec
- **Advanced Security**: Firewall configuration, SSH port change, root access disable
- **Configuration File**: Option to use configuration file for automated setup
- **Beautiful Interface**: Colorful and organized output with emojis
- **Error Handling**: Smart error management and continued installation even if issues occur
- **Speed Testing**: Automatic internet speed testing

<h2 id="features">🔧 Features</h2>

### 🔒 Security

- Root password change
- Disable SSH access for root
- Create new admin user
- Change default SSH port
- UFW firewall configuration
- VPN user access restrictions

### 🌐 VPN Services

- **3X-UI Panel**: Advanced web management panel for Xray
- **Outline VPN**: Secure and fast VPN protocol
- **SSH VPN**: Tunneling through SSH
- **L2TP/IPSec**: VPN protocol compatible with most devices

### ⚡ Performance

- Automatic system updates
- Required package installation
- Internet speed testing
- Optimized network configuration

<h2 id="supported-vpn-services">🛡️ Supported VPN Services</h2>

### 1. 3X-UI Panel 📱

- Web management panel for Xray
- Support for various protocols (VMess, VLess, Trojan)
- Beautiful and user-friendly interface
- User and traffic management

### 2. Outline VPN 🔒

- Secure and fast VPN protocol
- Management through Outline Manager app
- Support for multiple simultaneous users
- Strong encryption

### 3. SSH VPN 🌐

- Tunneling through SSH
- Support for multiple simultaneous users
- Shared UDPGW port usage
- High security

### 4. L2TP/IPSec 🔐

- Compatible with most operating systems
- Support for Windows, macOS, iOS, Android
- IPSec encryption
- Simple configuration

<h2 id="installation-setup">📦 Installation & Setup</h2>

### Prerequisites

- Ubuntu 22.04 LTS server
- Root access
- Stable internet connection

### Installation

```bash
# Download the script
wget https://raw.githubusercontent.com/kiarashAlizadeh/CipherShark/master/vpn-setup.sh
# curl -O

# Make executable
chmod +x vpn-setup.sh

# Run the script
sudo ./vpn-setup.sh
```

<h2 id="configuration-file-usage">⚙️ Configuration File Usage</h2>

### Benefits of Using Configuration File

- **Automated Setup**: No manual input required
- **Repeatability**: Reuse configurations
- **Easy Management**: Change settings without re-running the script
- **Documentation**: Record all settings in one file

### How to Use

1. Edit the `vpn-config.conf` file
2. Enter your desired settings
3. Run the script
4. If configuration file exists, the script will use it

<h2 id="configuration-file-settings">📝 Configuration File Settings</h2>

### Security Section

```bash
# Root password change
CHANGE_ROOT_PASSWORD=yes
NEW_ROOT_PASSWORD=MySecureRootPass123!

# SSH settings
DISABLE_ROOT_SSH=yes
NEW_ADMIN_USER=admin
NEW_ADMIN_PASSWORD=MySecureAdminPass123!

# SSH port change
CHANGE_SSH_PORT=yes
NEW_SSH_PORT=2222

# Enable firewall
SETUP_FIREWALL=yes
```

### VPN Services Section

```bash
# 3X-UI Panel
INSTALL_3XUI=yes
XUI_USERNAME=admin
XUI_PASSWORD=MySecureXUIPass123!
XUI_PANEL_PORT=2087

# Outline VPN
INSTALL_OUTLINE=yes

# SSH VPN
SETUP_SSH_VPN=yes
SSH_VPN_UDPGW_PORT=7301

# SSH VPN users (format: username:password)
SSH_VPN_USERS=(
    "vpnuser1:MySecureVPNPass1!"
    "vpnuser2:MySecureVPNPass2!"
    "vpnuser3:MySecureVPNPass3!"
)

# L2TP/IPSec
INSTALL_L2TP=yes
L2TP_PSK=MySecureL2TPPSK123!
L2TP_USERNAME=l2tpuser
L2TP_PASSWORD=MySecureL2TPPass123!
```

### Performance Section

```bash
# Speed test
RUN_SPEED_TEST=yes

# Server reboot
REBOOT_SERVER=no
```

<h2 id="sample-configuration-file">📄 Sample Configuration File</h2>

The `vpn-config.conf` file includes all necessary settings:

```bash
# CipherShark VPN Server Configuration File
# This file contains all settings for automated VPN server setup
# Save this file in the same directory as vpn-setup.sh
# The script will automatically detect and use this configuration

# ========================================
# SECURITY SETTINGS
# ========================================

# Root password change
CHANGE_ROOT_PASSWORD=yes
NEW_ROOT_PASSWORD=MySecureRootPass123!

# SSH Security
DISABLE_ROOT_SSH=yes
NEW_ADMIN_USER=admin
NEW_ADMIN_PASSWORD=MySecureAdminPass123!

# SSH Port change
CHANGE_SSH_PORT=yes
NEW_SSH_PORT=2222

# Firewall setup
SETUP_FIREWALL=yes

# ========================================
# VPN SERVICES CONFIGURATION
# ========================================

# 3X-UI Panel
INSTALL_3XUI=yes
XUI_USERNAME=admin
XUI_PASSWORD=MySecureXUIPass123!
XUI_PANEL_PORT=2087

# Outline VPN
INSTALL_OUTLINE=yes

# SSH VPN Users
SETUP_SSH_VPN=yes
SSH_VPN_UDPGW_PORT=7301

# SSH VPN Users List (format: username:password)
SSH_VPN_USERS=(
    "vpnuser1:MySecureVPNPass1!"
    "vpnuser2:MySecureVPNPass2!"
    "vpnuser3:MySecureVPNPass3!"
)

# L2TP/IPSec VPN
INSTALL_L2TP=yes
L2TP_PSK=MySecureL2TPPSK123!
L2TP_USERNAME=l2tpuser
L2TP_PASSWORD=MySecureL2TPPass123!

# ========================================
# PERFORMANCE & SYSTEM SETTINGS
# ========================================

# Speed test after installation
RUN_SPEED_TEST=yes

# Reboot server after installation
REBOOT_SERVER=no

# ========================================
# ADVANCED SETTINGS (Optional)
# ========================================

# Server IP (leave empty for auto-detection)
SERVER_IP=

# Custom ports (optional - will use defaults if not specified)
# XUI_PANEL_PORT=2087
# OUTLINE_MANAGEMENT_PORT=
# OUTLINE_ACCESS_PORT=

# ========================================
# NOTES:
# ========================================
# 1. All passwords should be strong (at least 12 characters with mixed case, numbers, and symbols)
# 2. SSH VPN users will share the same UDPGW port for efficiency
# 3. The script will automatically detect your server's public IP address
# 4. All services will be configured with the specified credentials
# 5. Firewall will be configured to allow necessary ports
# 6. The script will create a detailed summary after installation
```

<h2 id="usage-guide">🚀 Usage Guide</h2>

### Method 1: Using Configuration File (Recommended)

```bash
# 1. Edit the configuration file
nano vpn-config.conf

# 2. Run the script
sudo ./vpn-setup.sh

# 3. If configuration file exists, the script will use it
```

### Method 2: Interactive Usage

```bash
# Run the script without configuration file
sudo ./vpn-setup.sh

# Answer the script questions
```

### Execution Steps

1. **Prerequisites Check**: Verify root access and internet connection
2. **Server IP Detection**: Automatic detection of server's public IP
3. **Configuration Loading**: Load configuration file (if exists)
4. **Service Installation**: Install and configure selected services
5. **Security Setup**: Apply security settings
6. **Summary Display**: Show final information and instructions

<h2 id="troubleshooting">🔧 Troubleshooting</h2>
### Issue: Script won't execute

```bash
# Solution: Make executable
chmod +x vpn-setup.sh
```

### Issue: Root access error

```bash
# Solution: Run with sudo
sudo ./vpn-setup.sh
```

### Issue: Configuration file not found

```bash
# Solution: Check file path
ls -la vpn-config.conf
```

### Issue: Package installation error

```bash
# Solution: Update system
sudo apt update && sudo apt upgrade
```

## 📊 Sample Output

After successful script execution, you'll see output similar to:

```
=================================================
🚀 Installation Complete! 🎉
=================================================

🎊 All selected services have been installed successfully!

📱 3X-UI Panel Information:
   Access URL: http://YOUR_SERVER_IP:2087
   Username: admin
   Password: MySecureXUIPass123!

🔒 Outline VPN Information:
   Server IP: YOUR_SERVER_IP
   Management Port: 12345 (TCP)
   Access Key Port: 54321 (TCP & UDP)
   API Config: {"apiUrl":"https://YOUR_SERVER_IP:12345/...","certSha256":"..."}

🌐 SSH VPN Information:
   Server IP: YOUR_SERVER_IP
   SSH Port: 2222
   UDPGW Port: 7301
   Total Users Created: 3

   📋 SSH VPN USER 1:
      Username: vpnuser1
      Password: MySecureVPNPass1!

   📋 SSH VPN USER 2:
      Username: vpnuser2
      Password: MySecureVPNPass2!

   📋 SSH VPN USER 3:
      Username: vpnuser3
      Password: MySecureVPNPass3!

🔐 L2TP/IPSec VPN Information:
   Server IP: YOUR_SERVER_IP
   PSK: MySecureL2TPPSK123!
   Username: l2tpuser
   Password: MySecureL2TPPass123!

🚀 Server Speed Test Results:
   Download: 100 Mbps | Upload: 50 Mbps | Ping: 20 ms | Server: Test Server

🔒 Security Notice:
   Root SSH access has been disabled
   New admin user: admin
   Use this account for future SSH connections

🚪 SSH Port Changed:
   New SSH port: 2222
   Use: ssh admin@YOUR_SERVER_IP -p 2222

🔥 Firewall Status: ENABLED
   Allowed ports: 2222 (SSH), 80 (HTTP), 443 (HTTPS), 2087 (3X-UI), 12345 (Outline Mgmt), 54321 (Outline Access), 7301 (UDPGW), 500/4500/1701 (L2TP)

📋 Next Steps:
   1. Save this configuration information
   2. Test all connections before closing this terminal
   3. Configure your VPN clients with the provided information
   4. Multiple SSH VPN users can connect simultaneously using the same ports
   5. Each SSH VPN user will have their own isolated session
   6. Use Outline Manager app to import the API config and create access keys

✨ Enjoy your new VPN server! ✨
```

<h2 id="contributing">🤝 Contributing</h2>

Your contributions to improve this project are highly valued!

### How to Contribute

1. Fork the project
2. Create a new branch for your feature (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Reporting Issues

Please report issues in the Issues section and include the following information:

- Ubuntu version
- Complete error output
- Steps to reproduce the issue

<h2 id="license">📄 License</h2>

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for more details.

## 👨‍💻 Author

**Kiarash Alizadeh**

- GitHub: [@kiarashAlizadeh](https://github.com/kiarashAlizadeh)
- Project: [CipherShark](https://github.com/kiarashAlizadeh/CipherShark)

## 🙏 Acknowledgments

Thank you to everyone who has contributed to the development and improvement of this project.

---

⭐ If this project was helpful to you, please star it!
