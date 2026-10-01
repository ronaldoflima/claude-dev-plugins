#!/bin/bash
#
# Linux to macOS Keyboard Setup Script
# Installs and configures Karabiner-Elements, AltTab, and Rectangle
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS_DIR="$(dirname "$SCRIPT_DIR")/assets"

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      Linux to macOS Keyboard Remapping Setup                ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if Homebrew is installed
check_homebrew() {
    echo -e "${YELLOW}Checking Homebrew...${NC}"
    if ! command -v brew &> /dev/null; then
        echo -e "${RED}Homebrew not found. Installing...${NC}"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Add Homebrew to PATH for this session
        if [[ -f /opt/homebrew/bin/brew ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -f /usr/local/bin/brew ]]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    else
        echo -e "${GREEN}✓ Homebrew already installed${NC}"
    fi
}

# Install Karabiner-Elements
install_karabiner() {
    echo ""
    echo -e "${YELLOW}Installing Karabiner-Elements...${NC}"

    if [[ -d "/Applications/Karabiner-Elements.app" ]]; then
        echo -e "${GREEN}✓ Karabiner-Elements already installed${NC}"
    else
        brew install --cask karabiner-elements
        echo -e "${GREEN}✓ Karabiner-Elements installed${NC}"
    fi
}

# Install AltTab
install_alttab() {
    echo ""
    echo -e "${YELLOW}Installing AltTab (optional - for Linux-style Alt+Tab)...${NC}"

    if [[ -d "/Applications/AltTab.app" ]]; then
        echo -e "${GREEN}✓ AltTab already installed${NC}"
    else
        read -p "Install AltTab? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            brew install --cask alt-tab
            echo -e "${GREEN}✓ AltTab installed${NC}"
        else
            echo -e "${YELLOW}Skipped AltTab installation${NC}"
        fi
    fi
}

# Install Rectangle
install_rectangle() {
    echo ""
    echo -e "${YELLOW}Installing Rectangle (optional - for window tiling)...${NC}"

    if [[ -d "/Applications/Rectangle.app" ]]; then
        echo -e "${GREEN}✓ Rectangle already installed${NC}"
    else
        read -p "Install Rectangle for window tiling? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            brew install --cask rectangle
            echo -e "${GREEN}✓ Rectangle installed${NC}"
        else
            echo -e "${YELLOW}Skipped Rectangle installation${NC}"
        fi
    fi
}

# Configure Karabiner
configure_karabiner() {
    echo ""
    echo -e "${YELLOW}Configuring Karabiner-Elements...${NC}"

    KARABINER_CONFIG_DIR="$HOME/.config/karabiner"
    KARABINER_ASSETS_DIR="$KARABINER_CONFIG_DIR/assets/complex_modifications"

    # Create directories if they don't exist
    mkdir -p "$KARABINER_CONFIG_DIR"
    mkdir -p "$KARABINER_ASSETS_DIR"

    # Backup existing config
    if [[ -f "$KARABINER_CONFIG_DIR/karabiner.json" ]]; then
        BACKUP_FILE="$KARABINER_CONFIG_DIR/karabiner.json.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$KARABINER_CONFIG_DIR/karabiner.json" "$BACKUP_FILE"
        echo -e "${BLUE}Backed up existing config to: $BACKUP_FILE${NC}"
    fi

    # Copy Linux mode config
    if [[ -f "$ASSETS_DIR/karabiner/linux-mode.json" ]]; then
        cp "$ASSETS_DIR/karabiner/linux-mode.json" "$KARABINER_ASSETS_DIR/"
        echo -e "${GREEN}✓ Copied linux-mode.json to Karabiner assets${NC}"
    else
        echo -e "${RED}✗ linux-mode.json not found at $ASSETS_DIR/karabiner/${NC}"
    fi

    # Copy IDE exceptions config
    if [[ -f "$ASSETS_DIR/karabiner/ide-exceptions.json" ]]; then
        cp "$ASSETS_DIR/karabiner/ide-exceptions.json" "$KARABINER_ASSETS_DIR/"
        echo -e "${GREEN}✓ Copied ide-exceptions.json to Karabiner assets${NC}"
    fi

    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}IMPORTANT: Manual steps required:${NC}"
    echo ""
    echo "1. Open Karabiner-Elements from Applications"
    echo "2. Go to 'Complex Modifications' tab"
    echo "3. Click 'Add rule'"
    echo "4. Enable the 'Linux/Ubuntu Mode' rules"
    echo ""
    echo "5. Grant Karabiner the required permissions:"
    echo "   - System Preferences > Security & Privacy > Privacy"
    echo "   - Add Karabiner-Elements to 'Input Monitoring'"
    echo "   - Add karabiner_grabber to 'Accessibility'"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
}

# Configure AltTab
configure_alttab() {
    if [[ -d "/Applications/AltTab.app" ]]; then
        echo ""
        echo -e "${YELLOW}AltTab configuration tips:${NC}"
        echo ""
        echo "1. Open AltTab from Applications"
        echo "2. In Preferences > Appearance:"
        echo "   - Set 'Show windows from' to 'All visible windows'"
        echo "   - Uncheck 'Show apps without windows'"
        echo "3. In Preferences > Shortcuts:"
        echo "   - Set your preferred Alt+Tab shortcut"
        echo ""
    fi
}

# Main installation flow
main() {
    check_homebrew
    install_karabiner
    install_alttab
    install_rectangle
    configure_karabiner
    configure_alttab

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    Setup Complete!                          ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Open Karabiner-Elements and enable the Linux mode rules"
    echo "2. Grant necessary permissions in System Preferences"
    echo "3. Open AltTab and configure as desired"
    echo "4. Test your keyboard shortcuts!"
    echo ""
    echo "Run the diagnosis script to verify everything is working:"
    echo "  $SCRIPT_DIR/diagnose.sh"
    echo ""
}

main "$@"
