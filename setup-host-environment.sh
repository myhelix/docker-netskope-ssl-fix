#!/bin/bash

# Setup script for configuring host machine to trust Netskope SSL certificate
# This configures Node.js (Claude Code, npm), Python (pip), Git, and other tools

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Certificate path
NETSKOPE_CERT="/Library/Application Support/Netskope/STAgent/data/nscacert_combined.pem"

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}Netskope Host Environment Setup${NC}"
echo -e "${BLUE}=====================================${NC}"
echo ""

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${YELLOW}Warning: This script is designed for macOS.${NC}"
    echo -e "${YELLOW}For Linux, see docs/HOST_MACHINE_SETUP.md${NC}"
    echo ""
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check if certificate exists
if [[ ! -f "$NETSKOPE_CERT" ]]; then
    echo -e "${RED}Error: Netskope certificate not found at:${NC}"
    echo -e "${RED}  $NETSKOPE_CERT${NC}"
    echo ""
    echo "Possible solutions:"
    echo "1. Ensure Netskope client is installed and running"
    echo "2. Check if certificate exists at a different location"
    echo "3. Export certificate from Keychain Access"
    echo ""
    echo "See docs/HOST_MACHINE_SETUP.md for details"
    exit 1
fi

echo -e "${GREEN}✓ Found Netskope certificate${NC}"
echo ""

# Display certificate info
echo "Certificate details:"
openssl x509 -in "$NETSKOPE_CERT" -noout -subject -issuer -dates 2>/dev/null || echo "  (Unable to read certificate details)"
echo ""

# Detect shell
DETECTED_SHELL=$(basename "$SHELL")
echo "Detected shell: $DETECTED_SHELL"
echo ""

# Determine config file
if [[ "$DETECTED_SHELL" == "zsh" ]]; then
    SHELL_CONFIG="$HOME/.zshrc"
elif [[ "$DETECTED_SHELL" == "bash" ]]; then
    if [[ -f "$HOME/.bash_profile" ]]; then
        SHELL_CONFIG="$HOME/.bash_profile"
    else
        SHELL_CONFIG="$HOME/.bashrc"
    fi
else
    echo -e "${YELLOW}Warning: Unknown shell ($DETECTED_SHELL)${NC}"
    SHELL_CONFIG="$HOME/.profile"
fi

echo "Will configure: $SHELL_CONFIG"
echo ""

# Check if already configured
if grep -q "NETSKOPE_CERT" "$SHELL_CONFIG" 2>/dev/null; then
    echo -e "${YELLOW}Netskope configuration already exists in $SHELL_CONFIG${NC}"
    echo ""
    read -p "Overwrite existing configuration? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled."
        exit 0
    fi

    # Backup existing config
    BACKUP_FILE="${SHELL_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$SHELL_CONFIG" "$BACKUP_FILE"
    echo -e "${GREEN}✓ Backed up to: $BACKUP_FILE${NC}"
    echo ""

    # Remove old configuration
    sed -i.tmp '/# Netskope SSL Certificate Configuration/,/# End Netskope SSL Configuration/d' "$SHELL_CONFIG"
    rm -f "${SHELL_CONFIG}.tmp"
fi

# Add configuration
echo "Adding Netskope configuration to $SHELL_CONFIG..."
echo ""

cat >> "$SHELL_CONFIG" << 'EOF'

# Netskope SSL Certificate Configuration
# Added by setup-host-environment.sh
export NETSKOPE_CERT="/Library/Application Support/Netskope/STAgent/data/nscacert_combined.pem"

# Node.js (Claude Code, npm, yarn, pnpm)
export NODE_EXTRA_CA_CERTS="$NETSKOPE_CERT"

# Python (pip, requests)
export REQUESTS_CA_BUNDLE="$NETSKOPE_CERT"
export SSL_CERT_FILE="$NETSKOPE_CERT"
export CURL_CA_BUNDLE="$NETSKOPE_CERT"

# AWS CLI
export AWS_CA_BUNDLE="$NETSKOPE_CERT"

# Git
export GIT_SSL_CAINFO="$NETSKOPE_CERT"

# End Netskope SSL Configuration
EOF

echo -e "${GREEN}✓ Configuration added successfully${NC}"
echo ""

# Optional: Configure git globally
read -p "Configure git globally to use Netskope certificate? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    git config --global http.sslCAInfo "$NETSKOPE_CERT"
    echo -e "${GREEN}✓ Git configured globally${NC}"
    echo ""
fi

# Optional: Configure npm globally
read -p "Configure npm globally to use Netskope certificate? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    npm config set cafile "$NETSKOPE_CERT"
    echo -e "${GREEN}✓ npm configured globally${NC}"
    echo ""
fi

# Optional: Configure pip globally
read -p "Configure pip globally to use Netskope certificate? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    pip config set global.cert "$NETSKOPE_CERT" 2>/dev/null || pip3 config set global.cert "$NETSKOPE_CERT" 2>/dev/null || true
    echo -e "${GREEN}✓ pip configured globally${NC}"
    echo ""
fi

# Summary
echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}Setup Complete!${NC}"
echo -e "${BLUE}=====================================${NC}"
echo ""
echo "Next steps:"
echo ""
echo "1. ${YELLOW}Reload your shell configuration:${NC}"
echo "   source $SHELL_CONFIG"
echo ""
echo "2. ${YELLOW}Restart all applications:${NC}"
echo "   - Close ALL terminal windows and open new ones"
echo "   - Quit and restart Claude Code (don't just close the window)"
echo "   - Restart VS Code if you use it"
echo "   - Restart any other development tools"
echo ""
echo "3. ${YELLOW}Verify configuration:${NC}"
echo "   echo \$NODE_EXTRA_CA_CERTS"
echo "   curl https://api.github.com"
echo ""
echo "4. ${YELLOW}Test Claude Code:${NC}"
echo "   - Open Claude Code"
echo "   - Try connecting to your Atlassian MCP server"
echo "   - It should connect without SSL errors"
echo ""
echo "For troubleshooting, see: docs/HOST_MACHINE_SETUP.md"
echo ""
echo -e "${GREEN}Configuration file: $SHELL_CONFIG${NC}"
echo -e "${GREEN}Certificate location: $NETSKOPE_CERT${NC}"
echo ""
