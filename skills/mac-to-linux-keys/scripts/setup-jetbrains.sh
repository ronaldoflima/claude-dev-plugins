#!/bin/bash
#
# JetBrains IDEs Linux Mode Keymap Setup
# Installs Linux-style keymap for all detected JetBrains IDEs
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
KEYMAP_FILE="$ASSETS_DIR/jetbrains/Linux Style.xml"

JETBRAINS_BASE="$HOME/Library/Application Support/JetBrains"

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      JetBrains Linux Mode Keymap Setup                      ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if keymap file exists
if [[ ! -f "$KEYMAP_FILE" ]]; then
    echo -e "${RED}Error: Linux Style.xml not found at $KEYMAP_FILE${NC}"
    exit 1
fi

# Check for JetBrains installations
if [[ ! -d "$JETBRAINS_BASE" ]]; then
    echo -e "${YELLOW}No JetBrains IDE configurations found.${NC}"
    echo "Install a JetBrains IDE and run it at least once, then run this script again."
    exit 0
fi

# Find all IDE installations
IDES_FOUND=()
for IDE_DIR in "$JETBRAINS_BASE"/*; do
    if [[ -d "$IDE_DIR" ]]; then
        IDE_NAME=$(basename "$IDE_DIR")
        # Skip backup directories
        if [[ "$IDE_NAME" != *".backup"* ]]; then
            IDES_FOUND+=("$IDE_DIR")
        fi
    fi
done

if [[ ${#IDES_FOUND[@]} -eq 0 ]]; then
    echo -e "${YELLOW}No JetBrains IDE configurations found.${NC}"
    exit 0
fi

echo -e "${YELLOW}Found ${#IDES_FOUND[@]} JetBrains IDE(s):${NC}"
for IDE_DIR in "${IDES_FOUND[@]}"; do
    echo "  - $(basename "$IDE_DIR")"
done
echo ""

# Ask for confirmation
read -p "Install Linux Style keymap to all IDEs? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""

# Install keymap to each IDE
INSTALLED=0
for IDE_DIR in "${IDES_FOUND[@]}"; do
    IDE_NAME=$(basename "$IDE_DIR")
    KEYMAPS_DIR="$IDE_DIR/keymaps"

    echo -e "${YELLOW}Processing $IDE_NAME...${NC}"

    # Create keymaps directory if it doesn't exist
    mkdir -p "$KEYMAPS_DIR"

    # Backup existing keymap if present
    if [[ -f "$KEYMAPS_DIR/Linux Style.xml" ]]; then
        BACKUP_FILE="$KEYMAPS_DIR/Linux Style.xml.backup.$(date +%Y%m%d_%H%M%S)"
        mv "$KEYMAPS_DIR/Linux Style.xml" "$BACKUP_FILE"
        echo "  Backed up existing keymap to: $(basename "$BACKUP_FILE")"
    fi

    # Copy the keymap
    cp "$KEYMAP_FILE" "$KEYMAPS_DIR/"
    echo -e "  ${GREEN}✓ Installed Linux Style.xml${NC}"

    ((INSTALLED++))
done

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    Installation Complete!                   ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Installed Linux Style keymap to $INSTALLED IDE(s)."
echo ""
echo -e "${YELLOW}To activate the keymap:${NC}"
echo ""
echo "1. Open your JetBrains IDE"
echo "2. Go to Settings/Preferences (Ctrl+Alt+S or Cmd+,)"
echo "3. Navigate to Keymap"
echo "4. Select 'Linux Mode' from the dropdown"
echo "5. Click Apply and OK"
echo ""
echo "Or use the quick switcher:"
echo "  - Press Ctrl+\` (or Cmd+\`) for the quick switch menu"
echo "  - Select 'Keymap' and choose 'Linux Mode'"
echo ""
echo -e "${BLUE}Key shortcuts in Linux Mode:${NC}"
echo "  Alt+← / Alt+→     : Navigate back/forward"
echo "  Ctrl+G            : Go to line"
echo "  F3                : Go to declaration / Find next"
echo "  Shift+F10         : Run"
echo "  Shift+F9          : Debug"
echo "  Alt+1-9           : Tool windows"
echo "  Ctrl+C/V/X/Z      : Standard edit operations"
echo ""
