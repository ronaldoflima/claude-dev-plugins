#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/../data"
REGISTRY_FILE="$DATA_DIR/registry.json"
CONFLICTS_FILE="$DATA_DIR/conflicts.json"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

show_help() {
    echo "Usage: sync-registry.sh [command]"
    echo ""
    echo "Commands:"
    echo "  sync     Sincroniza registro com configs reais (default)"
    echo "  status   Mostra estado atual do registro"
    echo "  detect   Detecta conflitos entre apps"
    echo "  help     Mostra esta ajuda"
}

detect_karabiner() {
    local installed=false
    local config_path=""
    local profile=""

    if [[ -d "/Applications/Karabiner-Elements.app" ]]; then
        installed=true
        config_path="$HOME/.config/karabiner/karabiner.json"

        if command -v /Library/Application\ Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli &> /dev/null; then
            profile=$(/Library/Application\ Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli --show-current-profile-name 2>/dev/null || echo "unknown")
        fi
    fi

    echo "{\"installed\": $installed, \"config_path\": \"$config_path\", \"profile\": \"$profile\"}"
}

detect_jetbrains_ides() {
    local jetbrains_base="$HOME/Library/Application Support/JetBrains"
    local result="["
    local first=true

    if [[ -d "$jetbrains_base" ]]; then
        for ide_dir in "$jetbrains_base"/*; do
            if [[ -d "$ide_dir" ]]; then
                ide_name=$(basename "$ide_dir")
                keymap_dir="$ide_dir/keymaps"
                active_keymap=""

                if [[ -f "$keymap_dir/Linux Style.xml" ]]; then
                    active_keymap="Linux Style"
                fi

                if [[ "$first" != true ]]; then
                    result+=","
                fi
                first=false

                result+="{\"name\": \"$ide_name\", \"config_path\": \"$keymap_dir\", \"active_keymap\": \"$active_keymap\"}"
            fi
        done
    fi

    result+="]"
    echo "$result"
}

detect_vscode() {
    local installed=false
    local config_path=""

    if [[ -d "/Applications/Visual Studio Code.app" ]]; then
        installed=true
        config_path="$HOME/Library/Application Support/Code/User/keybindings.json"
    fi

    echo "{\"installed\": $installed, \"config_path\": \"$config_path\"}"
}

# Antigravity IDE (Google) — fork do VS Code, mesmo formato de keybindings.json.
# Está na lista de exceções do Karabiner: os atalhos Linux vêm do keybindings.json.
detect_antigravity() {
    local installed=false
    local config_path=""
    local version=""
    local binds=0

    if [[ -d "/Applications/Antigravity IDE.app" ]]; then
        installed=true
        config_path="$HOME/Library/Application Support/Antigravity IDE/User/keybindings.json"
        version=$(python3 -c "import json;print(json.load(open('/Applications/Antigravity IDE.app/Contents/Resources/app/package.json'))['version'])" 2>/dev/null || echo "")
        if [[ -f "$config_path" ]]; then
            binds=$(python3 -c "
import json,re,sys
raw=open('$config_path').read()
s='\n'.join(re.sub(r'//.*\$','',l) for l in raw.splitlines())
try: print(len(json.loads(s)))
except Exception: print(0)
" 2>/dev/null || echo 0)
        fi
    fi

    echo "{\"installed\": $installed, \"config_path\": \"$config_path\", \"version\": \"$version\", \"keybindings_count\": $binds}"
}

# Lê o estado REAL dos symbolic hotkeys do macOS (System Settings > Keyboard
# Shortcuts). Sem isso a skill chuta que os conflitos "manual_required" estão
# pendentes quando na prática já foram resolvidos — ou pior, o contrário.
#
# IMPORTANTE ao escrever nestas chaves: `defaults write -dict-add` com plist
# old-style (`{enabled = 0;}`) grava enabled como STRING '0', que o macOS
# ignora. Use um fragmento XML com <false/> e <integer> nos parameters.
# Sempre `defaults export` antes de mexer — vários hotkeys já vêm desativados
# e os `parameters` variam (ctrl vs ctrl+fn), fácil de clobbar sem perceber.
detect_macos_hotkeys() {
    python3 - <<'PYEOF'
import json, subprocess, plistlib

# id: (label, atalho, colide_com)
WATCH = {
    "60": ("Select the previous input source", "Ctrl+Space", "autocomplete (triggerSuggest)"),
    "61": ("Select next source in Input menu", "Ctrl+Opt+Space", ""),
    "32": ("Mission Control", "Ctrl+Up", "navegação no editor"),
    "33": ("Application windows", "Ctrl+Down", "navegação no editor"),
    "79": ("Move left a space", "Ctrl+Left", "navegação por palavra"),
    "80": ("Move left a space (shift)", "Ctrl+Shift+Left", "seleção por palavra"),
    "81": ("Move right a space", "Ctrl+Right", "navegação por palavra"),
    "82": ("Move right a space (shift)", "Ctrl+Shift+Right", "seleção por palavra"),
}
try:
    raw = subprocess.run(["defaults", "export", "com.apple.symbolichotkeys", "-"],
                         capture_output=True, timeout=15).stdout
    hk = plistlib.loads(raw).get("AppleSymbolicHotKeys", {})
except Exception:
    hk = {}

out = []
for hid, (label, combo, clashes) in WATCH.items():
    e = hk.get(hid)
    if e is None:
        state = "default"          # sem override: default do sistema
    else:
        state = "enabled" if e.get("enabled") in (True, 1) else "disabled"
    out.append({"id": hid, "label": label, "shortcut": combo,
                "state": state, "conflicts_with": clashes})
print(json.dumps(out))
PYEOF
}

detect_terminals() {
    local result="["
    local first=true

    declare -a terminals=(
        "iTerm.app:com.googlecode.iterm2"
        "Terminal.app:com.apple.Terminal"
        "Alacritty.app:org.alacritty"
        "kitty.app:net.kovidgoyal.kitty"
        "WezTerm.app:com.github.wez.wezterm"
    )

    for terminal in "${terminals[@]}"; do
        app_name="${terminal%%:*}"
        bundle_id="${terminal##*:}"

        if [[ -d "/Applications/$app_name" ]] || [[ -d "$HOME/Applications/$app_name" ]]; then
            if [[ "$first" != true ]]; then
                result+=","
            fi
            first=false
            result+="{\"name\": \"$app_name\", \"bundle_id\": \"$bundle_id\", \"installed\": true}"
        fi
    done

    result+="]"
    echo "$result"
}

detect_tmux() {
    # tmux é multiplexer: intercepta teclas ANTES do shell, mas DEPOIS do terminal.
    # Conflito típico: terminal (Ghostty/Cmd) consome a tecla antes de chegar ao tmux.
    local installed=false
    local version=""
    local config_path=""
    local binds_count=0

    if command -v tmux &>/dev/null; then
        installed=true
        version=$(tmux -V 2>/dev/null | awk '{print $2}')
        [[ -f "$HOME/.tmux.conf" ]] && config_path="$HOME/.tmux.conf"
        if [[ -f "$DATA_DIR/binds/tmux.txt" ]]; then
            binds_count=$(wc -l < "$DATA_DIR/binds/tmux.txt" | tr -d ' ')
        fi
    fi

    echo "{\"installed\": $installed, \"version\": \"$version\", \"config_path\": \"$config_path\", \"binds_count\": $binds_count}"
}

detect_ghostty() {
    local installed=false
    local version=""
    local config_path=""
    local binds_count=0
    local bin=""

    for p in /Applications/Ghostty.app/Contents/MacOS/ghostty "$HOME/Applications/Ghostty.app/Contents/MacOS/ghostty"; do
        [[ -x "$p" ]] && { bin="$p"; break; }
    done
    [[ -z "$bin" ]] && command -v ghostty &>/dev/null && bin="$(command -v ghostty)"

    if [[ -n "$bin" ]]; then
        installed=true
        version=$("$bin" --version 2>/dev/null | head -1 | awk '{print $2}')
        local cfg="$HOME/Library/Application Support/com.mitchellh.ghostty/config"
        [[ -f "${cfg}.ghostty" ]] && config_path="${cfg}.ghostty"
        [[ -f "$cfg" ]] && config_path="$cfg"
        [[ -f "$HOME/.config/ghostty/config" ]] && config_path="$HOME/.config/ghostty/config"
        if [[ -f "$DATA_DIR/binds/ghostty.txt" ]]; then
            binds_count=$(wc -l < "$DATA_DIR/binds/ghostty.txt" | tr -d ' ')
        fi
    fi

    echo "{\"installed\": $installed, \"version\": \"$version\", \"config_path\": \"$config_path\", \"binds_count\": $binds_count}"
}

detect_alttab() {
    # Detecta o window switcher estilo Linux (Cmd+Tab mostrando todas as janelas).
    # Suporta Contexts (contexts.co) e AltTab — o que estiver instalado.
    local installed=false
    local running=false
    local app="none"

    if [[ -d "/Applications/Contexts.app" ]]; then
        installed=true
        app="Contexts"
        if pgrep -x "Contexts" > /dev/null; then
            running=true
        fi
    elif [[ -d "/Applications/AltTab.app" ]]; then
        installed=true
        app="AltTab"
        if pgrep -x "AltTab" > /dev/null; then
            running=true
        fi
    fi

    echo "{\"installed\": $installed, \"running\": $running, \"app\": \"$app\"}"
}

build_registry() {
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Extrai binds de tmux/Ghostty antes de detectar (atualiza data/binds/ e contagens)
    if [[ -x "$SCRIPT_DIR/dump-binds.sh" ]]; then
        "$SCRIPT_DIR/dump-binds.sh" all >/dev/null 2>&1
    fi

    local karabiner=$(detect_karabiner)
    local jetbrains=$(detect_jetbrains_ides)
    local vscode=$(detect_vscode)
    local antigravity=$(detect_antigravity)
    local terminals=$(detect_terminals)
    local tmux=$(detect_tmux)
    local ghostty=$(detect_ghostty)
    local alttab=$(detect_alttab)
    local macos_hotkeys=$(detect_macos_hotkeys)

    cat > "$REGISTRY_FILE" << EOF
{
  "version": "1.0",
  "last_sync": "$timestamp",
  "applications": {
    "karabiner": {
      "name": "Karabiner-Elements",
      "type": "system",
      "installed": $(echo "$karabiner" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin)['installed']))" 2>/dev/null || echo "false"),
      "config_paths": ["$(echo "$karabiner" | python3 -c "import sys,json; print(json.load(sys.stdin)['config_path'])" 2>/dev/null || echo "")"],
      "priority": 1,
      "current_profile": "$(echo "$karabiner" | python3 -c "import sys,json; print(json.load(sys.stdin)['profile'])" 2>/dev/null || echo "")"
    },
    "jetbrains": {
      "name": "JetBrains IDEs",
      "type": "ide",
      "installed": $([ "$(echo "$jetbrains" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")" -gt 0 ] && echo "true" || echo "false"),
      "ides": $jetbrains,
      "priority": 2
    },
    "vscode": {
      "name": "VS Code",
      "type": "ide",
      "bundle_id": "com.microsoft.VSCode",
      "installed": $(echo "$vscode" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin)['installed']))" 2>/dev/null || echo "false"),
      "config_paths": ["$(echo "$vscode" | python3 -c "import sys,json; print(json.load(sys.stdin)['config_path'])" 2>/dev/null || echo "")"],
      "priority": 2
    },
    "antigravity": {
      "name": "Antigravity IDE",
      "type": "ide",
      "bundle_id": "com.google.antigravity-ide",
      "installed": $(echo "$antigravity" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin)['installed']))" 2>/dev/null || echo "false"),
      "config_paths": ["$(echo "$antigravity" | python3 -c "import sys,json; print(json.load(sys.stdin)['config_path'])" 2>/dev/null || echo "")"],
      "version": "$(echo "$antigravity" | python3 -c "import sys,json; print(json.load(sys.stdin)['version'])" 2>/dev/null || echo "")",
      "keybindings_count": $(echo "$antigravity" | python3 -c "import sys,json; print(json.load(sys.stdin)['keybindings_count'])" 2>/dev/null || echo "0"),
      "karabiner_excluded": true,
      "priority": 2
    },
    "terminals": {
      "name": "Terminals",
      "type": "terminal",
      "apps": $terminals,
      "priority": 3
    },
    "ghostty": {
      "name": "Ghostty",
      "type": "terminal",
      "bundle_id": "com.mitchellh.ghostty",
      "installed": $(echo "$ghostty" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin)['installed']))" 2>/dev/null || echo "false"),
      "version": "$(echo "$ghostty" | python3 -c "import sys,json; print(json.load(sys.stdin)['version'])" 2>/dev/null || echo "")",
      "config_paths": ["$(echo "$ghostty" | python3 -c "import sys,json; print(json.load(sys.stdin)['config_path'])" 2>/dev/null || echo "")"],
      "binds_dump": "data/binds/ghostty.txt",
      "binds_count": $(echo "$ghostty" | python3 -c "import sys,json; print(json.load(sys.stdin)['binds_count'])" 2>/dev/null || echo "0"),
      "priority": 3
    },
    "tmux": {
      "name": "tmux",
      "type": "multiplexer",
      "installed": $(echo "$tmux" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin)['installed']))" 2>/dev/null || echo "false"),
      "version": "$(echo "$tmux" | python3 -c "import sys,json; print(json.load(sys.stdin)['version'])" 2>/dev/null || echo "")",
      "config_paths": ["$(echo "$tmux" | python3 -c "import sys,json; print(json.load(sys.stdin)['config_path'])" 2>/dev/null || echo "")"],
      "binds_dump": "data/binds/tmux.txt",
      "binds_count": $(echo "$tmux" | python3 -c "import sys,json; print(json.load(sys.stdin)['binds_count'])" 2>/dev/null || echo "0"),
      "priority": 4
    },
    "alttab": {
      "name": "Window Switcher",
      "type": "utility",
      "app": "$(echo "$alttab" | python3 -c "import sys,json; print(json.load(sys.stdin)['app'])" 2>/dev/null || echo "none")",
      "installed": $(echo "$alttab" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin)['installed']))" 2>/dev/null || echo "false"),
      "running": $(echo "$alttab" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin)['running']))" 2>/dev/null || echo "false"),
      "priority": 1
    },
    "macos": {
      "name": "macOS System",
      "type": "system",
      "installed": true,
      "symbolic_hotkeys": $macos_hotkeys,
      "priority": 0
    }
  }
}
EOF
}

show_status() {
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        echo -e "${YELLOW}Registro não existe. Execute 'sync' primeiro.${NC}"
        return 1
    fi

    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║              Registro de Keybindings - Status               ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local last_sync=$(python3 -c "import json; print(json.load(open('$REGISTRY_FILE'))['last_sync'])" 2>/dev/null || echo "nunca")
    echo -e "${CYAN}Última sincronização:${NC} $last_sync"
    echo ""

    echo -e "${YELLOW}Aplicações Detectadas:${NC}"
    echo ""

    local karabiner_installed=$(python3 -c "import json; print(json.load(open('$REGISTRY_FILE'))['applications']['karabiner']['installed'])" 2>/dev/null)
    if [[ "$karabiner_installed" == "True" ]]; then
        echo -e "${GREEN}✓${NC} Karabiner-Elements"
        local profile=$(python3 -c "import json; print(json.load(open('$REGISTRY_FILE'))['applications']['karabiner']['current_profile'])" 2>/dev/null)
        echo "  Profile: $profile"
    else
        echo -e "${RED}✗${NC} Karabiner-Elements (não instalado)"
    fi

    local jetbrains_installed=$(python3 -c "import json; print(json.load(open('$REGISTRY_FILE'))['applications']['jetbrains']['installed'])" 2>/dev/null)
    if [[ "$jetbrains_installed" == "True" ]]; then
        echo -e "${GREEN}✓${NC} JetBrains IDEs"
        python3 -c "
import json
data = json.load(open('$REGISTRY_FILE'))
for ide in data['applications']['jetbrains']['ides']:
    keymap = ide.get('active_keymap', '')
    status = '(Linux Style)' if keymap == 'Linux Style' else ''
    print(f\"  - {ide['name']} {status}\")
" 2>/dev/null
    else
        echo -e "${YELLOW}○${NC} JetBrains IDEs (não detectado)"
    fi

    local vscode_installed=$(python3 -c "import json; print(json.load(open('$REGISTRY_FILE'))['applications']['vscode']['installed'])" 2>/dev/null)
    if [[ "$vscode_installed" == "True" ]]; then
        echo -e "${GREEN}✓${NC} VS Code"
    else
        echo -e "${YELLOW}○${NC} VS Code (não instalado)"
    fi

    local ag_installed=$(python3 -c "import json; print(json.load(open('$REGISTRY_FILE'))['applications'].get('antigravity',{}).get('installed'))" 2>/dev/null)
    if [[ "$ag_installed" == "True" ]]; then
        local ag_info
        ag_info=$(python3 -c "
import json
ag = json.load(open('$REGISTRY_FILE'))['applications']['antigravity']
print(f\"{ag.get('version','')} — {ag.get('keybindings_count',0)} binds (exceção no Karabiner)\")
" 2>/dev/null)
        echo -e "${GREEN}✓${NC} Antigravity IDE $ag_info"
    else
        echo -e "${YELLOW}○${NC} Antigravity IDE (não instalado)"
    fi

    echo ""
    echo -e "${YELLOW}Symbolic Hotkeys do macOS (System Settings > Keyboard Shortcuts):${NC}"
    python3 -c "
import json
GREEN='\033[0;32m'; YEL='\033[1;33m'; NC='\033[0m'
hks = json.load(open('$REGISTRY_FILE'))['applications']['macos'].get('symbolic_hotkeys', [])
if not hks:
    print('  (não coletado — rode sync)')
for h in hks:
    st = h['state']
    if st == 'disabled':
        print(f\"  {GREEN}✓{NC} {h['shortcut']:<18} livre — {h['label']}\")
    else:
        extra = f\" (colide com {h['conflicts_with']})\" if h['conflicts_with'] else ''
        tag = 'ATIVO' if st == 'enabled' else 'ATIVO (default)'
        print(f\"  {YEL}⚠{NC} {h['shortcut']:<18} {tag} — {h['label']}{extra}\")
" 2>/dev/null

    echo ""
    local alttab_installed=$(python3 -c "import json; print(json.load(open('$REGISTRY_FILE'))['applications']['alttab']['installed'])" 2>/dev/null)
    local alttab_running=$(python3 -c "import json; print(json.load(open('$REGISTRY_FILE'))['applications']['alttab']['running'])" 2>/dev/null)
    local alttab_app=$(python3 -c "import json; print(json.load(open('$REGISTRY_FILE'))['applications']['alttab'].get('app','Window Switcher'))" 2>/dev/null)
    if [[ "$alttab_installed" == "True" ]]; then
        if [[ "$alttab_running" == "True" ]]; then
            echo -e "${GREEN}✓${NC} Window Switcher: $alttab_app (rodando)"
        else
            echo -e "${YELLOW}⚠${NC} Window Switcher: $alttab_app (instalado, não rodando)"
        fi
    else
        echo -e "${YELLOW}○${NC} Window Switcher (nenhum instalado — AltTab/Contexts)"
    fi

    echo ""
    echo -e "${YELLOW}Terminais:${NC}"
    python3 -c "
import json
data = json.load(open('$REGISTRY_FILE'))
for term in data['applications']['terminals']['apps']:
    print(f\"  - {term['name']}\")
" 2>/dev/null || echo "  Nenhum detectado"

    echo ""
    echo -e "${YELLOW}Multiplexer / Terminal com binds extraídos:${NC}"
    python3 -c "
import json
data = json.load(open('$REGISTRY_FILE'))['applications']
for key in ('ghostty', 'tmux'):
    app = data.get(key)
    if not app: continue
    if app.get('installed'):
        v = app.get('version', '')
        n = app.get('binds_count', 0)
        print(f\"  ✓ {app['name']} {v} — {n} binds em {app.get('binds_dump','')}\")
    else:
        print(f\"  ○ {app['name']} (não instalado)\")
" 2>/dev/null

    echo ""
}

detect_conflicts() {
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        echo -e "${YELLOW}Registro não existe. Execute 'sync' primeiro.${NC}"
        return 1
    fi

    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║              Análise de Conflitos                           ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if [[ ! -f "$CONFLICTS_FILE" ]]; then
        echo -e "${RED}Arquivo de conflitos não encontrado.${NC}"
        return 1
    fi

    echo -e "${YELLOW}Conflitos Conhecidos (Resolvidos):${NC}"
    python3 -c "
import json
data = json.load(open('$CONFLICTS_FILE'))
for conflict in data.get('known', []):
    if conflict.get('status') == 'resolved':
        print(f\"  ✓ {conflict['id']}: {conflict['description']}\")
" 2>/dev/null

    echo ""
    echo -e "${YELLOW}Conflitos que Requerem Ação Manual:${NC}"
    # Conflitos com 'verify_hotkeys' são checados contra o estado REAL do
    # symbolichotkeys (gravado no registry pelo sync) em vez de assumidos
    # pendentes. Sem isso a skill repete "requer ação manual" pra coisa que
    # já foi resolvida meses atrás.
    python3 -c "
import json, os
data = json.load(open('$CONFLICTS_FILE'))
live = {}
if os.path.exists('$REGISTRY_FILE'):
    try:
        for h in json.load(open('$REGISTRY_FILE'))['applications']['macos'].get('symbolic_hotkeys', []):
            live[h['id']] = h['state']
    except Exception:
        pass

pending = []
for conflict in data.get('known', []):
    if conflict.get('status') != 'manual_required':
        continue
    ids = conflict.get('verify_hotkeys') or []
    if ids and live:
        still = [i for i in ids if live.get(i, 'default') != 'disabled']
        if not still:
            print(f\"  ✓ {conflict['id']}: JÁ RESOLVIDO (hotkeys {', '.join(ids)} desativados)\")
            continue
        conflict = dict(conflict, _still=still)
    pending.append(conflict)

for conflict in pending:
    print(f\"  ⚠ {conflict['id']}: {conflict['description']}\")
    if conflict.get('_still'):
        print(f\"    Ainda ativos: hotkeys {', '.join(conflict['_still'])}\")
    print(f\"    Resolução: {conflict.get('resolution', 'N/A')}\")
    for step in conflict.get('manual_steps', []):
        print(f\"      - {step}\")
    print()
if not pending:
    print('  Nenhuma ação manual pendente.')
" 2>/dev/null

    echo ""
    echo -e "${YELLOW}Conflitos Detectados Automaticamente:${NC}"
    local detected_count=$(python3 -c "import json; print(len(json.load(open('$CONFLICTS_FILE')).get('detected', [])))" 2>/dev/null || echo "0")
    if [[ "$detected_count" == "0" ]]; then
        echo -e "${GREEN}  Nenhum conflito detectado automaticamente.${NC}"
    else
        python3 -c "
import json
data = json.load(open('$CONFLICTS_FILE'))
for conflict in data.get('detected', []):
    print(f\"  ! {conflict['id']}: {conflict['description']}\")
    print(f\"    Entre: {', '.join(conflict.get('between', []))}\")
    print(f\"    Status: {conflict.get('status', 'pending')}\")
    print()
" 2>/dev/null
    fi

    echo ""
    echo -e "${YELLOW}Conflitos Irresolvíveis:${NC}"
    python3 -c "
import json
data = json.load(open('$CONFLICTS_FILE'))
for conflict in data.get('unresolvable', []):
    print(f\"  ✗ {conflict['id']}: {conflict['reason']}\")
    if conflict.get('workaround'):
        print(f\"    Workaround: {conflict['workaround']}\")
" 2>/dev/null

    echo ""
}

sync_all() {
    echo -e "${BLUE}Sincronizando registro...${NC}"
    echo ""

    mkdir -p "$DATA_DIR"

    build_registry

    echo -e "${GREEN}✓ Registro atualizado em:${NC} $REGISTRY_FILE"
    echo ""

    show_status
}

case "${1:-sync}" in
    sync)
        sync_all
        ;;
    status)
        show_status
        ;;
    detect)
        detect_conflicts
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Comando desconhecido: $1"
        show_help
        exit 1
        ;;
esac
