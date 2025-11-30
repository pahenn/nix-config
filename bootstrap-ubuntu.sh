#!/bin/bash
# Bootstrap script for Ubuntu systems after home-manager installation
# Run this after your first `home-manager switch`

set -e

echo "==> Ubuntu Bootstrap Script"
echo ""

# Install OpenSSH Server
echo "==> Installing OpenSSH Server..."
if ! systemctl is-active --quiet ssh; then
    sudo apt update
    sudo apt install -y openssh-server
    sudo systemctl enable --now ssh
    echo "✓ OpenSSH server installed and enabled"
else
    echo "✓ OpenSSH server already running"
fi
echo ""

# Install Tailscale
echo "==> Installing Tailscale..."
if ! command -v tailscale &> /dev/null; then
    sudo snap install tailscale
    echo "✓ Tailscale installed"
    echo "  Run 'sudo tailscale up' to connect"
else
    echo "✓ Tailscale already installed"
fi
echo ""

# Add Nix zsh to /etc/shells
echo "==> Configuring Zsh as default shell..."
ZSH_PATH=$(which zsh)
if ! grep -q "^${ZSH_PATH}$" /etc/shells; then
    echo "${ZSH_PATH}" | sudo tee -a /etc/shells > /dev/null
    echo "✓ Added ${ZSH_PATH} to /etc/shells"
else
    echo "✓ Zsh already in /etc/shells"
fi

# Change default shell
CURRENT_SHELL=$(getent passwd $USER | cut -d: -f7)
if [ "$CURRENT_SHELL" != "$ZSH_PATH" ]; then
    chsh -s "$ZSH_PATH"
    echo "✓ Changed default shell to zsh"
    echo "  Log out and back in for the change to take effect"
else
    echo "✓ Default shell already set to zsh"
fi
echo ""

echo "==> Bootstrap complete!"
echo ""
echo "Next steps:"
echo "  1. Run 'sudo tailscale up' to connect to your Tailscale network"
echo "  2. Log out and back in to use zsh as your default shell"
