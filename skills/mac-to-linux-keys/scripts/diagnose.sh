#!/bin/bash
#
# Linux to macOS Keyboard Diagnostic Script
# Checks for common issues and configuration problems
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/../data"
REGISTRY_FILE="$DATA_DIR/registry.json"
CONFLICTS_FILE="$DATA_DIR/conflicts.json"
USER_REPORTS_FILE="$DATA_DIR/user-reports.json"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      Linux to macOS Keyboard Diagnostic                     ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

ISSUES_FOUND=0

# Check macOS version
check_macos_version() {
    echo -e "${YELLOW}System Information:${NC}"
    sw_vers
    echo ""
}

# Check Karabiner-Elements
check_karabiner() {
    echo -e "${YELLOW}Checking Karabiner-Elements...${NC}"

    # Check if installed
    if [[ -d "/Applications/Karabiner-Elements.app" ]]; then
        echo -e "${GREEN}✓ Karabiner-Elements is installed${NC}"

        # Get version
        VERSION=$(/Applications/Karabiner-Elements.app/Contents/MacOS/Karabiner-Elements --version 2>/dev/null || echo "unknown")
        echo "  Version: $VERSION"
    else
        echo -e "${RED}✗ Karabiner-Elements is NOT installed${NC}"
        echo "  Run: brew install --cask karabiner-elements"
        ((ISSUES_FOUND++))
        return
    fi

    # Check if running
    if pgrep -x "karabiner_grabber" > /dev/null; then
        echo -e "${GREEN}✓ karabiner_grabber is running${NC}"
    else
        echo -e "${RED}✗ karabiner_grabber is NOT running${NC}"
        echo "  Try restarting Karabiner-Elements"
        ((ISSUES_FOUND++))
    fi

    if pgrep -x "karabiner_console_user_server" > /dev/null; then
        echo -e "${GREEN}✓ karabiner_console_user_server is running${NC}"
    else
        echo -e "${RED}✗ karabiner_console_user_server is NOT running${NC}"
        ((ISSUES_FOUND++))
    fi

    # Check config directory
    if [[ -d "$HOME/.config/karabiner" ]]; then
        echo -e "${GREEN}✓ Karabiner config directory exists${NC}"

        # Check for our rules
        if [[ -f "$HOME/.config/karabiner/assets/complex_modifications/linux-mode.json" ]]; then
            echo -e "${GREEN}✓ linux-mode.json is installed${NC}"
        else
            echo -e "${YELLOW}⚠ linux-mode.json not found in Karabiner assets${NC}"
            echo "  Run setup.sh to install it"
            ((ISSUES_FOUND++))
        fi
    else
        echo -e "${YELLOW}⚠ Karabiner config directory not found${NC}"
        echo "  Open Karabiner-Elements to create it"
        ((ISSUES_FOUND++))
    fi

    # Check current profile
    if command -v /Library/Application\ Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli &> /dev/null; then
        PROFILE=$(/Library/Application\ Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli --show-current-profile-name 2>/dev/null || echo "unknown")
        echo "  Current profile: $PROFILE"
    fi

    echo ""
}

# Check AltTab
check_alttab() {
    echo -e "${YELLOW}Checking AltTab...${NC}"

    if [[ -d "/Applications/AltTab.app" ]]; then
        echo -e "${GREEN}✓ AltTab is installed${NC}"

        if pgrep -x "AltTab" > /dev/null; then
            echo -e "${GREEN}✓ AltTab is running${NC}"
        else
            echo -e "${YELLOW}⚠ AltTab is NOT running${NC}"
            echo "  Start it from Applications or add to Login Items"
        fi
    else
        echo -e "${YELLOW}○ AltTab is not installed (optional)${NC}"
        echo "  Install with: brew install --cask alt-tab"
    fi

    echo ""
}

# Check Rectangle
check_rectangle() {
    echo -e "${YELLOW}Checking Rectangle...${NC}"

    if [[ -d "/Applications/Rectangle.app" ]]; then
        echo -e "${GREEN}✓ Rectangle is installed${NC}"

        if pgrep -x "Rectangle" > /dev/null; then
            echo -e "${GREEN}✓ Rectangle is running${NC}"
        else
            echo -e "${YELLOW}⚠ Rectangle is NOT running${NC}"
            echo "  Start it from Applications or add to Login Items"
        fi
    else
        echo -e "${YELLOW}○ Rectangle is not installed (optional)${NC}"
        echo "  Install with: brew install --cask rectangle"
    fi

    echo ""
}

# Check for conflicting software
check_conflicts() {
    echo -e "${YELLOW}Checking for potential conflicts...${NC}"

    CONFLICTS=()

    # Check for other keyboard remapping tools
    if [[ -d "/Applications/Keyboard Maestro.app" ]]; then
        CONFLICTS+=("Keyboard Maestro")
    fi

    if [[ -d "/Applications/BetterTouchTool.app" ]]; then
        CONFLICTS+=("BetterTouchTool")
    fi

    if [[ -d "/Applications/Hammerspoon.app" ]]; then
        CONFLICTS+=("Hammerspoon")
    fi

    if [[ -d "/Applications/Skhd.app" ]] || command -v skhd &> /dev/null; then
        CONFLICTS+=("skhd")
    fi

    if [[ ${#CONFLICTS[@]} -gt 0 ]]; then
        echo -e "${YELLOW}⚠ Found other keyboard tools that may conflict:${NC}"
        for app in "${CONFLICTS[@]}"; do
            echo "  - $app"
        done
        echo "  These can coexist but may cause unexpected behavior"
    else
        echo -e "${GREEN}✓ No conflicting keyboard tools detected${NC}"
    fi

    echo ""
}

# Check System Preferences settings
check_system_settings() {
    echo -e "${YELLOW}System keyboard settings:${NC}"

    # Check keyboard repeat rate
    KEY_REPEAT=$(defaults read NSGlobalDomain KeyRepeat 2>/dev/null || echo "not set")
    INITIAL_REPEAT=$(defaults read NSGlobalDomain InitialKeyRepeat 2>/dev/null || echo "not set")

    echo "  Key repeat rate: $KEY_REPEAT (lower = faster, default: 6)"
    echo "  Initial key repeat: $INITIAL_REPEAT (lower = faster, default: 25)"

    # Check modifier key remapping
    echo ""
    echo "  Note: If using external keyboard, check modifier key settings in"
    echo "  System Preferences > Keyboard > Modifier Keys"

    echo ""
}

# Check JetBrains IDEs
check_jetbrains() {
    echo -e "${YELLOW}Checking JetBrains IDEs...${NC}"

    JETBRAINS_BASE="$HOME/Library/Application Support/JetBrains"

    if [[ -d "$JETBRAINS_BASE" ]]; then
        IDE_COUNT=0
        for IDE_DIR in "$JETBRAINS_BASE"/*; do
            if [[ -d "$IDE_DIR" ]]; then
                IDE_NAME=$(basename "$IDE_DIR")
                echo "  Found: $IDE_NAME"

                # Check for our keymap
                if [[ -f "$IDE_DIR/keymaps/Linux Style.xml" ]]; then
                    echo -e "    ${GREEN}✓ Linux Style keymap installed${NC}"
                else
                    echo -e "    ${YELLOW}○ Linux Style keymap not installed${NC}"
                fi
                ((IDE_COUNT++))
            fi
        done

        if [[ $IDE_COUNT -eq 0 ]]; then
            echo "  No JetBrains IDE configurations found"
        fi
    else
        echo "  No JetBrains IDEs detected"
    fi

    echo ""
}

check_registry_status() {
    echo -e "${YELLOW}Registry Status:${NC}"

    if [[ -f "$REGISTRY_FILE" ]]; then
        local last_sync=$(python3 -c "import json; print(json.load(open('$REGISTRY_FILE'))['last_sync'] or 'nunca')" 2>/dev/null || echo "erro ao ler")
        echo -e "${GREEN}✓ Registry exists${NC}"
        echo "  Last sync: $last_sync"
    else
        echo -e "${YELLOW}○ Registry not synced yet${NC}"
        echo "  Run: sync-registry.sh sync"
    fi

    echo ""
}

check_conflicts_status() {
    echo -e "${YELLOW}Conflicts Status:${NC}"

    if [[ -f "$CONFLICTS_FILE" ]]; then
        local manual_count=$(python3 -c "
import json
data = json.load(open('$CONFLICTS_FILE'))
count = sum(1 for c in data.get('known', []) if c.get('status') == 'manual_required')
print(count)
" 2>/dev/null || echo "0")

        local detected_count=$(python3 -c "
import json
data = json.load(open('$CONFLICTS_FILE'))
print(len(data.get('detected', [])))
" 2>/dev/null || echo "0")

        if [[ "$manual_count" -gt 0 ]]; then
            echo -e "${YELLOW}⚠ $manual_count conflict(s) require manual action${NC}"
            python3 -c "
import json
data = json.load(open('$CONFLICTS_FILE'))
for c in data.get('known', []):
    if c.get('status') == 'manual_required':
        print(f\"  - {c['id']}: {c['description']}\")
" 2>/dev/null
        else
            echo -e "${GREEN}✓ No manual conflicts pending${NC}"
        fi

        if [[ "$detected_count" -gt 0 ]]; then
            echo -e "${RED}! $detected_count auto-detected conflict(s) pending${NC}"
        fi
    else
        echo -e "${YELLOW}○ Conflicts file not found${NC}"
    fi

    echo ""
}

check_user_reports() {
    echo -e "${YELLOW}User Reports:${NC}"

    if [[ -f "$USER_REPORTS_FILE" ]]; then
        local pending_count=$(python3 -c "
import json
data = json.load(open('$USER_REPORTS_FILE'))
count = sum(1 for r in data.get('reports', []) if r.get('status') in ['investigating', 'pending'])
print(count)
" 2>/dev/null || echo "0")

        if [[ "$pending_count" -gt 0 ]]; then
            echo -e "${YELLOW}⚠ $pending_count unresolved report(s)${NC}"
            python3 -c "
import json
data = json.load(open('$USER_REPORTS_FILE'))
for r in data.get('reports', []):
    if r.get('status') in ['investigating', 'pending']:
        shortcut = r.get('shortcut', {})
        key = shortcut.get('key', '?')
        mods = '+'.join(shortcut.get('modifiers', []))
        print(f\"  - {r['id']}: {mods}+{key} in {r.get('app', '?')}\")
" 2>/dev/null
        else
            echo -e "${GREEN}✓ No pending user reports${NC}"
        fi
    else
        echo -e "${GREEN}✓ No user reports${NC}"
    fi

    echo ""
}

print_summary() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    if [[ $ISSUES_FOUND -eq 0 ]]; then
        echo -e "${GREEN}No critical issues found!${NC}"
        echo ""
        echo "If shortcuts aren't working as expected:"
        echo "1. Make sure Karabiner rules are enabled"
        echo "2. Check that apps have correct permissions"
        echo "3. Verify the app you're using isn't in the exceptions list"
        echo "4. Report the issue: sync-registry.sh report"
    else
        echo -e "${RED}Found $ISSUES_FOUND issue(s) that need attention.${NC}"
        echo ""
        echo "To fix:"
        echo "1. Run setup.sh to install missing components"
        echo "2. Grant necessary permissions in System Preferences > Security & Privacy"
        echo "3. Restart Karabiner-Elements"
        echo "4. Check conflicts: sync-registry.sh detect"
    fi
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
}

# Main
main() {
    check_macos_version
    check_registry_status
    check_karabiner
    check_alttab
    check_rectangle
    check_conflicts
    check_system_settings
    check_jetbrains
    check_conflicts_status
    check_user_reports
    print_summary
}

main "$@"
