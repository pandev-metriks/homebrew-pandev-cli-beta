#!/bin/bash
set -e

TAP="pandev-metriks/pandev-cli-beta"
FORMULA="$TAP/pandev-cli-plugin"

# -------------------------------------------------------
# 1. Root check
# -------------------------------------------------------
if [ "$(id -u)" -eq 0 ]; then
    echo "ERROR: Do not run this script as root."
    echo "       Run as a regular user — sudo will be requested when needed."
    exit 1
fi

# -------------------------------------------------------
# 2. Homebrew check / install
# -------------------------------------------------------
if ! command -v brew &>/dev/null; then
    echo "Homebrew not found. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    if [ -f "/opt/homebrew/bin/brew" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    elif [ -f "/usr/local/bin/brew" ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
    echo "Homebrew installed."
else
    echo "Homebrew: $(brew --version | head -1)"
fi

# -------------------------------------------------------
# 3. Uninstall if already installed
# -------------------------------------------------------
if brew list pandev-cli-plugin &>/dev/null 2>&1; then
    echo "pandev-cli-plugin is already installed. Reinstalling..."
    brew uninstall pandev-cli-plugin
else
    echo "pandev-cli-plugin is not installed. Proceeding with fresh install."
fi

# -------------------------------------------------------
# 4. Install beta
# -------------------------------------------------------
echo "Installing pandev-cli-plugin (beta)..."
brew install "$FORMULA"

echo ""
echo "Installation complete!"
echo "Close and reopen your terminal, then run: sudo pandev auth"
