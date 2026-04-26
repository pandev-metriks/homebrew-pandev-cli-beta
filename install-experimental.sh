#!/bin/bash
set -e

VERSION="2.0.8.2"

REPO="pandev-metriks/homebrew-pandev-cli-beta"
TAP="pandev-metriks/pandev-cli-beta"
FORMULA="$TAP/pandev-cli-plugin"

STABLE_TAP="pandev-metriks/pandev-cli"
STABLE_FORMULA="$STABLE_TAP/pandev-cli-plugin"

INSTALL_DIR="$HOME/.pandev"
BIN_DIR="$HOME/.local/bin"
BIN_LINK="$BIN_DIR/pandev"

# -------------------------------------------------------
# 1. Root check
# -------------------------------------------------------
if [ "$(id -u)" -eq 0 ]; then
    echo "ERROR: Do not run this script as root."
    exit 1
fi

# -------------------------------------------------------
# 2. Detect OS and architecture
# -------------------------------------------------------
OS=$(uname -s)
ARCH=$(uname -m)

case "$ARCH" in
    x86_64) ARCH_NAME="amd64" ;;
    arm64|aarch64) ARCH_NAME="arm64" ;;
    *) echo "ERROR: Unsupported architecture: $ARCH"; exit 1 ;;
esac

case "$OS" in
    Darwin) OS_NAME="macOS" ;;
    Linux)  OS_NAME="Linux" ;;
    *) echo "ERROR: Unsupported OS: $OS"; exit 1 ;;
esac

echo "Platform detected: $OS_NAME / $ARCH_NAME"

# -------------------------------------------------------
# 3. macOS Command Line Tools check
# -------------------------------------------------------
if [[ "$OS" == "Darwin" ]]; then
    if ! xcode-select -p &>/dev/null; then
        echo "Command Line Tools not found."
        sudo xcode-select --install
        echo ""
        echo "Please complete installation and re-run this script."
        exit 0
    fi
fi

# -------------------------------------------------------
# 4. Remove any existing installation (beta + stable, brew + direct)
# -------------------------------------------------------
echo "Removing existing installation (if any)..."

if command -v brew &>/dev/null; then
    brew unlink pandev-cli-plugin 2>/dev/null || true
    brew uninstall "$STABLE_FORMULA" 2>/dev/null || true
    brew untap "$STABLE_TAP" 2>/dev/null || true
    brew uninstall "$FORMULA" 2>/dev/null || true
    brew untap "$TAP" 2>/dev/null || true
fi

rm -rf "$INSTALL_DIR"
rm -f "$BIN_LINK" "$BIN_DIR/pandev-cli-plugin"

echo "Cleanup complete."

# -------------------------------------------------------
# 5. Install (Homebrew on macOS, direct GitHub release otherwise)
# -------------------------------------------------------
if [[ "$OS" == "Darwin" ]] && command -v brew &>/dev/null; then
    echo "Homebrew detected: $(brew --version | head -1)"
    echo "Updating Homebrew..."
    brew update 2>/dev/null || true
    echo "Installing via Homebrew..."
    brew install "$FORMULA"
else
    echo "Using direct GitHub release installation."
    echo "Version: $VERSION"

    ASSET="pandev-cli-plugin_${VERSION}_${OS_NAME}_${ARCH_NAME}.tar.gz"
    DOWNLOAD_URL="https://github.com/$REPO/releases/download/v${VERSION}/$ASSET"

    TMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TMP_DIR"' EXIT

    echo "Downloading $ASSET..."
    curl -fsSL "$DOWNLOAD_URL" -o "$TMP_DIR/$ASSET"

    echo "Extracting..."
    mkdir -p "$INSTALL_DIR"
    tar -xzf "$TMP_DIR/$ASSET" -C "$INSTALL_DIR"

    chmod +x "$INSTALL_DIR/bin/pandev" "$INSTALL_DIR/bin/pandev-cli-plugin"

    mkdir -p "$BIN_DIR"

    ln -sf "$INSTALL_DIR/bin/pandev" "$BIN_LINK"
    ln -sf "$INSTALL_DIR/bin/pandev-cli-plugin" "$BIN_DIR/pandev-cli-plugin"
fi

# -------------------------------------------------------
# 6. Add ~/.local/bin to PATH permanently
# -------------------------------------------------------

detect_profile() {
    if [ -n "$ZSH_VERSION" ]; then
        echo "$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        if [[ "$OS" == "Darwin" ]]; then
            echo "$HOME/.bash_profile"
        else
            echo "$HOME/.bashrc"
        fi
    else
        echo "$HOME/.profile"
    fi
}

PROFILE_FILE=$(detect_profile)

add_path_if_missing() {
    if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$PROFILE_FILE" 2>/dev/null; then
        echo "" >> "$PROFILE_FILE"
        echo "# pandev-cli" >> "$PROFILE_FILE"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$PROFILE_FILE"
        echo "Added ~/.local/bin to PATH in $PROFILE_FILE"
    fi
}

if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    add_path_if_missing
    export PATH="$HOME/.local/bin:$PATH"
fi

# -------------------------------------------------------
# 7. Activate watchers (must run after install — important!)
# -------------------------------------------------------
echo ""
echo "Installation complete!"
echo ""

if command -v pandev &>/dev/null; then
    echo "Activating watchers via 'pandev --install'..."
    pandev --install || echo "WARNING: 'pandev --install' failed. Run it manually to activate watchers."
    echo ""
    echo "pandev is ready to use."
    echo "Try: pandev --version"
else
    echo "If command not found, restart your terminal."
fi

echo ""
