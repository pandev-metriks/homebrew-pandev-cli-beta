#!/bin/bash
set -e

REPO="pandev-metriks/homebrew-pandev-cli-beta"
TAP="pandev-metriks/pandev-cli-beta"
FORMULA="$TAP/pandev-cli-plugin"
INSTALL_DIR="$HOME/.pandev"
BIN_LINK="$HOME/.local/bin/pandev"

# -------------------------------------------------------
# 1. Root check
# -------------------------------------------------------
if [ "$(id -u)" -eq 0 ]; then
    echo "ERROR: Do not run this script as root."
    exit 1
fi

# -------------------------------------------------------
# 2. Detect OS and arch
# -------------------------------------------------------
OS=$(uname -s)
ARCH=$(uname -m)

case "$ARCH" in
    x86_64)          ARCH_NAME="amd64" ;;
    arm64|aarch64)   ARCH_NAME="arm64" ;;
    *) echo "ERROR: Unsupported architecture: $ARCH"; exit 1 ;;
esac

case "$OS" in
    Darwin) OS_NAME="macOS" ;;
    Linux)  OS_NAME="Linux" ;;
    *) echo "ERROR: Unsupported OS: $OS"; exit 1 ;;
esac

echo "Platform: $OS_NAME / $ARCH_NAME"

# -------------------------------------------------------
# 3. Command Line Tools check (macOS only)
# -------------------------------------------------------
if [[ "$OS" == "Darwin" ]]; then
    fix_clt() {
        echo "Fixing Command Line Tools..."
        sudo rm -rf /Library/Developer/CommandLineTools
        sudo xcode-select --install
        echo ""
        echo "============================================================"
        echo "  Complete the Command Line Tools installation,"
        echo "  then re-run this script."
        echo "============================================================"
        exit 0
    }

    if ! xcode-select -p &>/dev/null; then
        echo "Command Line Tools not found."
        fix_clt
    fi
fi

# -------------------------------------------------------
# 4. Branch: Homebrew installed vs direct install
# -------------------------------------------------------
if [[ "$OS" == "Darwin" ]] && command -v brew &>/dev/null; then
    echo "Homebrew detected: $(brew --version | head -1)"
    echo "Using Homebrew installation path."

    # Remove if already installed via brew
    if brew list pandev-cli-plugin &>/dev/null 2>&1; then
        echo "Removing existing pandev-cli-plugin (brew)..."
        brew uninstall pandev-cli-plugin
    fi

    # Remove any direct install if present (cleanup)
    if [ -d "$INSTALL_DIR" ]; then
        echo "Removing leftover direct install at $INSTALL_DIR..."
        rm -rf "$INSTALL_DIR"
    fi
    if [ -L "$BIN_LINK" ] || [ -f "$BIN_LINK" ]; then
        rm -f "$BIN_LINK"
    fi

    echo "Installing via Homebrew..."
    if ! brew install "$FORMULA" 2>&1 | tee /tmp/pandev_brew_install.log; then
        if grep -q "Command Line Tools are too outdated\|CommandLineTools" /tmp/pandev_brew_install.log; then
            echo "Detected outdated Command Line Tools. Fixing..."
            sudo rm -rf /Library/Developer/CommandLineTools
            sudo xcode-select --install
            echo ""
            echo "============================================================"
            echo "  Complete the Command Line Tools installation,"
            echo "  then re-run this script."
            echo "============================================================"
            exit 0
        fi
        echo "Installation failed. See output above."
        exit 1
    fi

else
    echo "Homebrew not found. Using direct install from GitHub release."

    # -------------------------------------------------------
    # Remove existing direct install
    # -------------------------------------------------------
    EXISTING=$(command -v pandev 2>/dev/null || true)
    if [ -n "$EXISTING" ]; then
        echo "Found existing pandev at: $EXISTING — removing..."
        rm -f "$EXISTING"
        # Also remove pandev-cli-plugin symlink if present
        rm -f "$(dirname "$EXISTING")/pandev-cli-plugin"
    fi
    if [ -d "$INSTALL_DIR" ]; then
        echo "Removing old install directory $INSTALL_DIR..."
        rm -rf "$INSTALL_DIR"
    fi

    # -------------------------------------------------------
    # Fetch latest release version
    # -------------------------------------------------------
    echo "Fetching latest release info..."
    RELEASE_JSON=$(curl -fsSL "https://api.github.com/repos/$REPO/releases" \
        -H "Accept: application/vnd.github+json")
    VERSION=$(echo "$RELEASE_JSON" | grep '"tag_name"' | head -1 \
        | sed 's/.*"tag_name": *"v\?\([^"]*\)".*/\1/')

    if [ -z "$VERSION" ]; then
        echo "ERROR: Could not determine latest release version."
        exit 1
    fi
    echo "Latest version: $VERSION"

    # -------------------------------------------------------
    # Download and extract tar.gz
    # -------------------------------------------------------
    ASSET="pandev-cli-plugin_${VERSION}_${OS_NAME}_${ARCH_NAME}.tar.gz"
    DOWNLOAD_URL="https://github.com/$REPO/releases/download/v${VERSION}/$ASSET"

    echo "Downloading $ASSET..."
    TMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TMP_DIR"' EXIT

    curl -fsSL "$DOWNLOAD_URL" -o "$TMP_DIR/$ASSET"

    echo "Extracting to $INSTALL_DIR..."
    mkdir -p "$INSTALL_DIR"
    tar -xzf "$TMP_DIR/$ASSET" -C "$INSTALL_DIR"
    chmod +x "$INSTALL_DIR/bin/pandev" "$INSTALL_DIR/bin/pandev-cli-plugin"

    # -------------------------------------------------------
    # Symlink to ~/.local/bin
    # -------------------------------------------------------
    mkdir -p "$HOME/.local/bin"
    ln -sf "$INSTALL_DIR/bin/pandev" "$BIN_LINK"
    ln -sf "$INSTALL_DIR/bin/pandev-cli-plugin" "$(dirname "$BIN_LINK")/pandev-cli-plugin"
    echo "Symlink created: $BIN_LINK"

    # -------------------------------------------------------
    # Add ~/.local/bin to PATH if missing
    # -------------------------------------------------------
    add_to_path() {
        local RC_FILE="$1"
        if [ -f "$RC_FILE" ] && ! grep -q '\.local/bin' "$RC_FILE"; then
            echo '' >> "$RC_FILE"
            echo '# pandev-cli' >> "$RC_FILE"
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$RC_FILE"
            echo "Added ~/.local/bin to PATH in $RC_FILE"
        fi
    }

    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        add_to_path "$HOME/.bashrc"
        add_to_path "$HOME/.zshrc"
        export PATH="$HOME/.local/bin:$PATH"
    fi
fi

# -------------------------------------------------------
# Done
# -------------------------------------------------------
echo ""
echo "Installation complete!"
echo "Close and reopen your terminal, or run: source ~/.bashrc"