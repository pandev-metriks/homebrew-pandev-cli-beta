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
# 2. Command Line Tools check (macOS only)
# -------------------------------------------------------
if [[ "$(uname)" == "Darwin" ]]; then
    fix_clt() {
        echo "Fixing Command Line Tools..."
        sudo rm -rf /Library/Developer/CommandLineTools
        echo "Starting Command Line Tools installation (a dialog will appear)..."
        sudo xcode-select --install
        echo ""
        echo "============================================================"
        echo "  Please complete the Command Line Tools installation,"
        echo "  then re-run this script."
        echo "============================================================"
        exit 0
    }

    if ! xcode-select -p &>/dev/null; then
        echo "Command Line Tools not found."
        fix_clt
    else
        CLT_VERSION=$(pkgutil --pkg-info=com.apple.pkg.CLTools_Executables 2>/dev/null | awk '/version:/{print $2}')
        if [ -z "$CLT_VERSION" ]; then
            echo "WARNING: Could not determine Command Line Tools version, proceeding..."
        else
            echo "Command Line Tools version: $CLT_VERSION"
        fi
    fi
fi

# -------------------------------------------------------
# 3. gcc check (Linux only)
# -------------------------------------------------------
if [[ "$(uname)" == "Linux" ]]; then
    if ! command -v gcc &>/dev/null; then
        echo "gcc not found. Installing..."
        if command -v apt-get &>/dev/null; then
            sudo apt-get update -qq && sudo apt-get install -y gcc
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y gcc
        elif command -v yum &>/dev/null; then
            sudo yum install -y gcc
        elif command -v pacman &>/dev/null; then
            sudo pacman -Sy --noconfirm gcc
        elif command -v brew &>/dev/null; then
            brew install gcc
        else
            echo "ERROR: Could not detect package manager. Install gcc manually and re-run."
            exit 1
        fi
        echo "gcc installed."
    else
        echo "gcc: $(gcc --version | head -1)"
    fi
fi

# -------------------------------------------------------
# 4. Homebrew check / install
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
# 5. Uninstall if already installed
# -------------------------------------------------------
if brew list pandev-cli-plugin &>/dev/null 2>&1; then
    echo "pandev-cli-plugin is already installed. Reinstalling..."
    brew uninstall pandev-cli-plugin
else
    echo "pandev-cli-plugin is not installed. Proceeding with fresh install."
fi

# -------------------------------------------------------
# 6. Install beta
# -------------------------------------------------------
echo "Installing pandev-cli-plugin (beta)..."
if ! brew install "$FORMULA" 2>&1 | tee /tmp/pandev_brew_install.log; then
    if grep -q "Command Line Tools are too outdated\|CommandLineTools" /tmp/pandev_brew_install.log; then
        echo ""
        echo "Detected outdated Command Line Tools. Fixing..."
        sudo rm -rf /Library/Developer/CommandLineTools
        echo "Starting Command Line Tools installation (a dialog will appear)..."
        sudo xcode-select --install
        echo ""
        echo "============================================================"
        echo "  Please complete the Command Line Tools installation,"
        echo "  then re-run this script."
        echo "============================================================"
        exit 0
    fi
    echo "Installation failed. See output above."
    exit 1
fi

echo ""
echo "Installation complete!"
echo "Close and reopen your terminal"
