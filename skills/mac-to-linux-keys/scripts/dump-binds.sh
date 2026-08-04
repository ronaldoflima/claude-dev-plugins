#!/bin/bash
# Extrai TODAS as keybinds de tmux e Ghostty para data/binds/.
# tmux:    via `tmux list-keys` (todas as tabelas: prefix, root, copy-mode-vi, ...)
# ghostty: via `ghostty +list-keybinds` (defaults + customizadas do config)
#
# Uso: dump-binds.sh [tmux|ghostty|all]   (default: all)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/../data"
BINDS_DIR="$DATA_DIR/binds"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

mkdir -p "$BINDS_DIR"

find_ghostty() {
    if command -v ghostty &>/dev/null; then command -v ghostty; return; fi
    for p in /Applications/Ghostty.app/Contents/MacOS/ghostty \
             "$HOME/Applications/Ghostty.app/Contents/MacOS/ghostty"; do
        [[ -x "$p" ]] && { echo "$p"; return; }
    done
    echo ""
}

dump_tmux() {
    if ! command -v tmux &>/dev/null; then
        echo -e "${YELLOW}○ tmux não instalado — pulando${NC}"; return 1
    fi
    # list-keys precisa de um server; sobe um efêmero se não houver sessão ativa.
    tmux list-keys &>/dev/null || tmux start-server &>/dev/null
    local out="$BINDS_DIR/tmux.txt"
    if tmux list-keys > "$out" 2>/dev/null && [[ -s "$out" ]]; then
        local n; n=$(wc -l < "$out" | tr -d ' ')
        echo -e "${GREEN}✓ tmux:${NC} $n binds → $out"
        echo -e "  ${CYAN}tabelas:${NC} $(awk '{print $3}' "$out" | sort -u | tr '\n' ' ')"
    else
        echo -e "${RED}✗ tmux: falha ao listar binds${NC}"; return 1
    fi
}

dump_ghostty() {
    local g; g="$(find_ghostty)"
    if [[ -z "$g" ]]; then
        echo -e "${YELLOW}○ Ghostty não encontrado — pulando${NC}"; return 1
    fi
    local out="$BINDS_DIR/ghostty.txt"
    if "$g" +list-keybinds > "$out" 2>/dev/null && [[ -s "$out" ]]; then
        local n; n=$(wc -l < "$out" | tr -d ' ')
        echo -e "${GREEN}✓ Ghostty:${NC} $n binds → $out"
        # config efetivo (útil pra ver o que foi customizado vs default)
        "$g" +show-config > "$BINDS_DIR/ghostty-config.txt" 2>/dev/null \
            && echo -e "  ${CYAN}config efetivo:${NC} $BINDS_DIR/ghostty-config.txt"
    else
        echo -e "${RED}✗ Ghostty: falha ao listar binds${NC}"; return 1
    fi
}

case "${1:-all}" in
    tmux)    dump_tmux ;;
    ghostty) dump_ghostty ;;
    all)     dump_tmux; dump_ghostty ;;
    *)       echo "Uso: dump-binds.sh [tmux|ghostty|all]"; exit 1 ;;
esac
