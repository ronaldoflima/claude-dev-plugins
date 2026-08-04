#!/bin/bash

set -e

BACKUP_DIR=~/backups/linux-keybindings-on-mac/

usage() {
    echo "Usage: $(basename "$0") [COMMAND] [BACKUP_NAME]"
    echo ""
    echo "Backup and restore keybindings for macOS applications."
    echo ""
    echo "Commands:"
    echo "  backup              Create new backup with timestamp (default)"
    echo "  restore [name]      Restore backup (interactive selection if no name)"
    echo "  list                List available backups"
    echo "  --help, -h          Show this help"
    echo ""
    echo "Included in backup:"
    echo "  - Claude Code keybindings.json"
    echo "  - VSCode keybindings.json"
    echo "  - Antigravity IDE keybindings.json"
    echo "  - Karabiner-Elements config"
    echo "  - JetBrains IDEs keymaps"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0")                        # Create backup"
    echo "  $(basename "$0") backup                 # Create backup"
    echo "  $(basename "$0") restore                # Interactive restore"
    echo "  $(basename "$0") restore 20240115-143022"
    echo "  $(basename "$0") list"
}

list_backups() {
    echo "Available backups in $BACKUP_DIR:"
    echo ""
    if [ -d "$BACKUP_DIR" ]; then
        ls -1 "$BACKUP_DIR" 2>/dev/null || echo "  (no backups found)"
    else
        echo "  (backup directory does not exist)"
    fi
}

backup() {
    local backup_name
    backup_name=$(date +%Y%m%d-%H%M%S)
    local backup_path="$BACKUP_DIR/$backup_name"

    mkdir -p "$backup_path"
    echo "Creating backup at $backup_path"

    if [ -f ~/.claude/keybindings.json ]; then
        echo "  → Claude Code keybindings"
        cp ~/.claude/keybindings.json "$backup_path/claude-keybindings.json"
    fi

    if [ -f ~/Library/Application\ Support/Code/User/keybindings.json ]; then
        echo "  → VSCode keybindings"
        cp ~/Library/Application\ Support/Code/User/keybindings.json "$backup_path/keybindings.json"
    fi

    if [ -f ~/Library/Application\ Support/Antigravity\ IDE/User/keybindings.json ]; then
        echo "  → Antigravity IDE keybindings"
        cp ~/Library/Application\ Support/Antigravity\ IDE/User/keybindings.json "$backup_path/antigravity-keybindings.json"
    fi

    if [ -d ~/.config/karabiner ]; then
        echo "  → Karabiner configurations"
        cp -r ~/.config/karabiner "$backup_path/karabiner"
    fi

    for ide in ~/Library/Application\ Support/JetBrains/*; do
        [ -d "$ide" ] || continue
        local ide_name
        ide_name=$(basename "$ide")

        if [ -d "$ide/keymaps/" ]; then
            echo "  → JetBrains $ide_name keymaps"
            mkdir -p "$backup_path/jetbrains/$ide_name"
            cp -r "$ide/keymaps" "$backup_path/jetbrains/$ide_name/"
        fi
    done

    echo ""
    echo "Backup completed: $backup_name"
}

select_backup() {
    local backups=()
    if [ -d "$BACKUP_DIR" ]; then
        while IFS= read -r dir; do
            backups+=("$(basename "$dir")")
        done < <(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d | sort -r)
    fi

    if [ ${#backups[@]} -eq 0 ]; then
        echo "No backups found in $BACKUP_DIR" >&2
        exit 1
    fi

    echo "Select backup to restore:" >&2
    PS3="Enter number: "
    select backup in "${backups[@]}" "Cancel"; do
        if [ "$backup" = "Cancel" ]; then
            echo "Cancelled" >&2
            exit 0
        elif [ -n "$backup" ]; then
            echo "$backup"
            return
        fi
    done < /dev/tty
}

restore() {
    local backup_name="$1"
    local restored_apps=()

    if [ -z "$backup_name" ]; then
        backup_name=$(select_backup)
    fi

    local backup_path="$BACKUP_DIR/$backup_name"

    if [ ! -d "$backup_path" ]; then
        echo "Error: backup '$backup_name' not found"
        echo ""
        list_backups
        exit 1
    fi

    echo "Restoring backup: $backup_name"

    if [ -f "$backup_path/claude-keybindings.json" ]; then
        echo "  → Claude Code keybindings"
        mkdir -p ~/.claude
        cp "$backup_path/claude-keybindings.json" ~/.claude/keybindings.json
        restored_apps+=("Claude Code")
    fi

    if [ -f "$backup_path/keybindings.json" ] && [ -d ~/Library/Application\ Support/Code/User ]; then
        echo "  → VSCode keybindings"
        cp "$backup_path/keybindings.json" ~/Library/Application\ Support/Code/User/keybindings.json
        restored_apps+=("VSCode")
    fi

    if [ -f "$backup_path/antigravity-keybindings.json" ] && [ -d ~/Library/Application\ Support/Antigravity\ IDE/User ]; then
        echo "  → Antigravity IDE keybindings"
        cp "$backup_path/antigravity-keybindings.json" ~/Library/Application\ Support/Antigravity\ IDE/User/keybindings.json
        restored_apps+=("Antigravity IDE")
    fi

    if [ -d "$backup_path/karabiner" ]; then
        echo "  → Karabiner configurations"
        cp -r "$backup_path/karabiner/"* ~/.config/karabiner/
    fi

    for ide in ~/Library/Application\ Support/JetBrains/*/; do
        [ -d "$ide" ] || continue
        local ide_name
        ide_name=$(basename "$ide")

        if [ -d "$backup_path/jetbrains/$ide_name/keymaps" ]; then
            echo "  → JetBrains $ide_name keymaps"
            mkdir -p "$ide/keymaps"
            cp -r "$backup_path/jetbrains/$ide_name/keymaps/"* "$ide/keymaps/"
            restored_apps+=("$ide_name")
        fi
    done

    echo ""
    echo "Restore completed!"

    if [ ${#restored_apps[@]} -gt 0 ]; then
        echo ""
        echo "⚠ Restart required:"
        for app in "${restored_apps[@]}"; do
            echo "  - $app"
        done
    fi
}

case "${1:-}" in
    backup)
        backup
        ;;
    restore)
        restore "$2"
        ;;
    list)
        list_backups
        ;;
    --help|-h)
        usage
        ;;
    "")
        backup
        ;;
    *)
        echo "Unknown option: $1"
        echo ""
        usage
        exit 1
        ;;
esac

