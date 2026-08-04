---
name: mac-to-linux-keys
description: Migra atalhos de teclado do Ubuntu/Linux para macOS usando Karabiner-Elements, hidutil e ferramentas complementares. Usar quando o usuário mencionar "remapear teclas", "atalhos do Linux no Mac", "Alt+Tab como Ubuntu", "Ctrl ao invés de Cmd", ou similares.
---

# Linux to macOS Keyboard Remapping

Este skill guia a migração de atalhos de teclado do Ubuntu/Linux para macOS, garantindo uma experiência familiar para quem vem do Linux.

## Subcomandos

| Comando | Descrição |
|---------|-----------|
| `/mac-to-linux-keys` | Workflow completo (sync + análise + interação) |
| `/mac-to-linux-keys status` | Mostra estado atual sem modificar |
| `/mac-to-linux-keys report` | Registra problema reportado pelo usuário |
| `/mac-to-linux-keys resolve <id>` | Tenta resolver conflito/report específico |

## Workflow

### Fase 0: Sincronização e Estado Atual

**Antes de qualquer ação**, sincronize o registro e verifique o estado atual:

```bash
~/.claude/skills/mac-to-linux-keys/scripts/sync-registry.sh sync
```

Isso irá:
1. Detectar apps instaladas (Karabiner, JetBrains, VSCode, terminais)
2. Ler configurações reais de cada app
3. Atualizar `data/registry.json`
4. Mostrar status das aplicações

Para ver apenas o status sem sincronizar:
```bash
~/.claude/skills/mac-to-linux-keys/scripts/sync-registry.sh status
```

### Fase 0.5: Backup

**Antes de qualquer modificação**, faça backup das configurações atuais:

```bash
~/.claude/skills/mac-to-linux-keys/scripts/backup-keybindings.sh backup
```

Isso salvará VSCode, Karabiner e JetBrains keymaps em `~/backups/linux-keybindings-on-mac/`.

### Fase 1: Diagnóstico

Antes de configurar, faça estas perguntas ao usuário:

1. **Quais atalhos você mais usa?**
   - Copy/Paste (Ctrl+C/V/X)
   - Navegação de texto (Home/End, Ctrl+←/→)
   - Gerenciamento de janelas (Alt+Tab, Alt+F4)
   - Terminal (Ctrl+C para SIGINT)

2. **Quais aplicativos você usa diariamente?**
   - IDEs JetBrains (PhpStorm, IntelliJ, PyCharm)?
   - VS Code?
   - Terminal/iTerm2?
   - Máquinas virtuais (VirtualBox, Parallels)?

3. **Quer Alt+Tab estilo Linux?** (mostra todas as janelas, não apenas apps)

### Fase 2: Instalação de Ferramentas

Execute o script de diagnóstico primeiro:

```bash
~/.claude/skills/mac-to-linux-keys/scripts/diagnose.sh
```

Depois instale as ferramentas necessárias:

```bash
~/.claude/skills/mac-to-linux-keys/scripts/setup.sh
```

#### Ferramentas Instaladas

| Ferramenta | Obrigatória | Função |
|------------|-------------|--------|
| Karabiner-Elements | ✅ | Remapeamento principal de teclas |
| AltTab | Recomendada | Alt+Tab mostrando todas as janelas |
| Rectangle | Opcional | Window tiling estilo Linux |

### Fase 3: Configuração Karabiner

O arquivo `assets/karabiner/linux-mode.json` contém os remapeamentos principais:

#### Remapeamentos Incluídos

| Categoria | Atalho Linux | → macOS | Notas |
|-----------|--------------|---------|-------|
| **Copy/Paste** | Ctrl+C/V/X | Cmd+C/V/X | Exceto terminal |
| **Texto** | Ctrl+A | Cmd+A | Select all |
| **Texto** | Ctrl+Z/Y | Cmd+Z/Shift+Cmd+Z | Undo/Redo |
| **Navegação** | Home/End | Cmd+←/→ | Início/fim da linha |
| **Navegação** | Ctrl+Home/End | Cmd+↑/↓ (editores)<br>Home/End (browsers) | Início/fim do documento/página |
| **Palavras** | Ctrl+←/→ | Option+←/→ | Navegar por palavras |
| **Seleção** | Ctrl+Shift+←/→ | Option+Shift+←/→ | Selecionar palavras |
| **Janelas** | Alt+F4 | Cmd+Q | Fechar app |
| **Janelas** | Alt+Tab | Cmd+Tab | Via AltTab app |
| **Browser** | F5 | Cmd+R | Refresh |
| **Browser** | Ctrl+T/W | Cmd+T/W | Nova aba/fechar |
| **Sistema** | Super/Win | Cmd+Space | Spotlight |

#### Apps com Exceções (input direto, sem remapeamento)

- **Terminais**: iTerm2, Terminal.app, Alacritty, Kitty, WezTerm
- **IDEs**: IntelliJ IDEA, PhpStorm, WebStorm, PyCharm, CLion, GoLand, RubyMine, DataGrip, Rider, VS Code, Sublime Text, **Antigravity IDE** (keymap próprio — ver Fase 4.4)
- **VMs**: VirtualBox, Parallels, VMware Fusion, UTM
- **Remote**: Microsoft Remote Desktop, Citrix Workspace

### Fase 4: Configuração JetBrains (Opcional)

Se o usuário usa IDEs JetBrains, copie o keymap "Linux Style":

```bash
for ide in ~/Library/Application\ Support/JetBrains/*/; do
  mkdir -p "$ide/keymaps"
  cp ~/.claude/skills/mac-to-linux-keys/assets/jetbrains/Linux\ Style.xml "$ide/keymaps/"
done
```

Depois ative no IDE: Settings → Keymap → selecione "Linux Style"

#### Keymap "Linux Style" - Atalhos

| Atalho | Ação |
|--------|------|
| **F12** | Go to Definition |
| **Shift+F12** | Find Usages |
| **Ctrl+Click** | Go to Definition |
| **F3** | Find Next |
| **Shift+F3** | Find Previous |
| **Alt+←/→** | Navegar histórico (usa Command se Alt/Cmd trocados) |
| **Alt+1-9** | Trocar tabs (usa Command se Alt/Cmd trocados) |

**Nota**: Se o usuário trocou Alt↔Command no Karabiner, os atalhos Alt+setas e Alt+1-9 usam `meta` (Command) no keymap.

### Fase 4.4: Antigravity IDE (e outros forks do VS Code)

**Antigravity IDE** (`com.google.antigravity-ide`, Google, linhagem Windsurf) é um fork do VS Code — usa o mesmo formato de `keybindings.json`.

Estratégia (a mesma de VS Code e JetBrains): **excluir do Karabiner + keymap completo no app**.

Por que não deixar o Karabiner traduzir:
1. As 11 regras Ctrl→Cmd cobrem só ~30% dos atalhos de IDE — `Ctrl+B`, `Ctrl+/`, `Ctrl+D`, `Ctrl+Shift+K`, `Ctrl+G`, chords `Ctrl+K …` ficam mortos.
2. **Decisivo:** o Karabiner não distingue o terminal integrado do editor dentro do app. Com a tradução ativa, `Ctrl+C` no terminal vira `Cmd+C` (copia) e **nunca manda SIGINT**. Só o `keybindings.json` enxerga o contexto `terminalFocus`.

Aplicar:
```bash
# 1) excluir do Karabiner (adiciona o bundle id às 11 regras frontmost_application_unless)
python3 - <<'EOF'
import json, os, shutil
p = os.path.expanduser("~/.config/karabiner/karabiner.json")
shutil.copy2(p, p + ".bak")
d = json.load(open(p))
BID, ANCHOR = r"^com\.google\.antigravity-ide$", r"^com\.microsoft\.VSCode$"
for prof in d["profiles"]:
    for r in prof.get("complex_modifications", {}).get("rules", []):
        for m in r.get("manipulators", []):
            for c in m.get("conditions", []) or []:
                bids = c.get("bundle_identifiers", [])
                if c.get("type") == "frontmost_application_unless" and ANCHOR in bids and BID not in bids:
                    bids.insert(bids.index(ANCHOR) + 1, BID)
json.dump(d, open(p, "w"), indent=4, ensure_ascii=False)
EOF

# 2) instalar o keymap
cp ~/.claude/skills/mac-to-linux-keys/assets/antigravity/keybindings.json \
   ~/Library/Application\ Support/Antigravity\ IDE/User/keybindings.json
```

O keymap é **aditivo**: os defaults macOS (`Cmd+C`, `Cmd+P`, `Cmd+Shift+P`) continuam valendo, e os atalhos próprios do Antigravity (agent panel, Cascade — todos em Cmd) ficam intactos.

**Regra de ouro do terminal integrado** — estas teclas NÃO são bindadas, vão direto pro shell:
`Ctrl+C` (SIGINT), `Ctrl+D` (EOF), `Ctrl+Z` (SIGTSTP), `Ctrl+R` (history search), `Ctrl+U`, `Ctrl+W`, `Ctrl+L`, `Ctrl+P/N`, `Ctrl+A/E`, `Ctrl+T`. Copiar/colar no terminal usa `Ctrl+Shift+C/V` (convenção gnome-terminal). Isso é feito com `when: editorTextFocus` ou `when: !terminalFocus` em cada bind.

Ao portar para outro fork do VS Code (Cursor, Windsurf, VSCodium): valide os command IDs contra o bundle antes de mapear —
```bash
grep -qF '"editor.action.commentLine"' "/Applications/<App>.app/Contents/Resources/app/out/vs/workbench/workbench.desktop.main.js"
```
IDs que mudaram de nome ou vieram de extensão dão falso negativo (ex.: `references-view.findReferences` → use `editor.action.goToReferences`; `editor.action.startFindAction` → `actions.find`).

#### Desativar atalhos conflitantes do macOS

System Settings → Keyboard → Keyboard Shortcuts:
- **Mission Control**: Desativar Ctrl+↑, Ctrl+↓, Ctrl+←, Ctrl+→
- **Input Sources**: Desativar Ctrl+Space

### Fase 5: Verificação

Após configurar, teste estes atalhos:

- [ ] Ctrl+C/V funciona em apps normais
- [ ] Ctrl+C envia SIGINT no terminal
- [ ] Home/End vão para início/fim da linha
- [ ] Alt+Tab mostra todas as janelas (se AltTab instalado)
- [ ] Alt+F4 fecha apps
- [ ] IDEs JetBrains respondem corretamente

### Fase 6: Análise de Conflitos

Após a verificação, analise potenciais conflitos:

```bash
~/.claude/skills/mac-to-linux-keys/scripts/sync-registry.sh detect
```

#### Tipos de Conflitos

| Tipo | Descrição | Ação |
|------|-----------|------|
| `resolved` | Já resolvido pelo Karabiner/keymap | Nenhuma |
| `manual_required` | Precisa configurar System Settings | Seguir passos |
| `optional` | Hábito do Windows/Linux sem equivalente direto | Decidir se quer mapear |
| `detected` | Detectado automaticamente | Investigar |

#### Conflitos Comuns que Requerem Ação Manual

1. **Ctrl+Space (Input Source)**
   - System Settings > Keyboard > Keyboard Shortcuts > Input Sources
   - Desmarcar "Select the previous input source"

2. **Ctrl+Arrows (Mission Control)**
   - System Settings > Keyboard > Keyboard Shortcuts > Mission Control
   - Desmarcar atalhos Ctrl+Arrow

### Fase 7: Reportar Problemas

Se um atalho não funciona como esperado, registre o problema:

```bash
# O Claude irá perguntar os detalhes e registrar em data/user-reports.json
/mac-to-linux-keys report
```

Informações necessárias:
- Qual atalho não funciona (ex: Ctrl+Shift+K)
- Em qual app (ex: VSCode)
- O que você esperava que acontecesse
- O que acontece de fato

## Extração de binds: tmux e Ghostty

Estes dois interceptam teclas em camadas próprias e são fontes frequentes de conflito:
- **Ghostty** (terminal): consome a tecla **antes** de tudo. No macOS as abas trocam com `super+1..9` (Cmd) e splits com `super+d`/`super+shift+d` — ver `data/binds/ghostty.txt`. Se o Karabiner converte Alt→Cmd, o "Alt" físico vira esses atalhos do Ghostty e nunca chega ao tmux.
- **tmux** (multiplexer): roda dentro do terminal; só recebe o que o Ghostty não capturou. Binds em `data/binds/tmux.txt` (tabelas `prefix`, `root`, `copy-mode-vi`, `copy-mode`).

**Ordem de precedência das teclas:** Karabiner → Ghostty → tmux → shell/app. Quem está mais à esquerda ganha. Para o tmux receber um atalho, ele não pode colidir com Ghostty (nem com o remap do Karabiner).

### Extrair todas as binds

```bash
~/.claude/skills/mac-to-linux-keys/scripts/dump-binds.sh all      # tmux + ghostty
~/.claude/skills/mac-to-linux-keys/scripts/dump-binds.sh tmux     # só tmux
~/.claude/skills/mac-to-linux-keys/scripts/dump-binds.sh ghostty  # só ghostty
```

Gera em `data/binds/`:
| Arquivo | Conteúdo | Fonte |
|---------|----------|-------|
| `tmux.txt` | todas as binds (todas as tabelas) | `tmux list-keys` |
| `ghostty.txt` | todas as binds (defaults + custom) | `ghostty +list-keybinds` |
| `ghostty-config.txt` | config efetivo | `ghostty +show-config` |

O `sync-registry.sh sync` chama o dump automaticamente e registra versão + contagem de binds de cada um no `registry.json`.

### Detectar colisões Ghostty × tmux

```bash
# compara modificadores do Ghostty com o que o tmux espera SEM prefixo (tabela root)
comm -12 \
  <(grep -oE '(super|alt|ctrl)\+\S+' ~/.claude/skills/mac-to-linux-keys/data/binds/ghostty.txt | sort -u) \
  <(awk '$3=="root"{print $4}' ~/.claude/skills/mac-to-linux-keys/data/binds/tmux.txt | sort -u)
```

Resolução típica quando o Ghostty vence: mover o bind no tmux para `prefix + tecla` (não colide, pois exige o prefixo) ou para um modificador livre.

## Troubleshooting

Consulte `references/troubleshooting.md` para problemas comuns:

- Karabiner não recebe permissões
- Conflitos com atalhos do sistema
- Teclas modificadoras não funcionam em certos apps
- AltTab não aparece

## Referências

- `references/shortcuts-comparison.md` - Tabela completa de equivalências
- `references/troubleshooting.md` - FAQ e soluções de problemas

## Customizações Pessoais

Você pode adicionar regras customizadas diretamente no Karabiner-Elements. Edite o arquivo `~/.config/karabiner/karabiner.json` ou use o GUI do Karabiner para adicionar "Complex Modifications".

### Exemplo: Right Command + teclas para caracteres especiais

Para criar atalhos como `Right Cmd + Q → /`, `Right Cmd + W → ?`, `Right Cmd + Z → \`:

```json
{
  "description": "Right Command + Q/W/Z → /, ?, \\",
  "manipulators": [
    {
      "type": "basic",
      "from": { "key_code": "q", "modifiers": { "mandatory": ["right_command"] } },
      "to": [{ "key_code": "slash" }]
    },
    {
      "type": "basic",
      "from": { "key_code": "w", "modifiers": { "mandatory": ["right_command"] } },
      "to": [{ "key_code": "slash", "modifiers": ["shift"] }]
    },
    {
      "type": "basic",
      "from": { "key_code": "z", "modifiers": { "mandatory": ["right_command"] } },
      "to": [{ "key_code": "backslash" }]
    }
  ]
}
```

Regras customizadas podem ser salvas em `~/.config/karabiner/assets/complex_modifications/` como arquivos JSON separados.

## Backup e Restore

Use o script `backup-keybindings.sh` para fazer backup e restaurar todas as configurações de atalhos:

```bash
~/.claude/skills/mac-to-linux-keys/scripts/backup-keybindings.sh
```

### Comandos Disponíveis

| Comando | Descrição |
|---------|-----------|
| `backup-keybindings.sh` | Cria backup com timestamp |
| `backup-keybindings.sh backup` | Mesmo que acima |
| `backup-keybindings.sh restore` | Seleção interativa de backup |
| `backup-keybindings.sh restore <nome>` | Restaura backup específico |
| `backup-keybindings.sh list` | Lista backups disponíveis |

### O que é incluído no backup

- **Claude Code**: `~/.claude/keybindings.json`
- **VSCode**: `keybindings.json`
- **Antigravity IDE**: `keybindings.json` (salvo como `antigravity-keybindings.json`)
- **Karabiner-Elements**: toda a pasta `~/.config/karabiner/`
- **JetBrains IDEs**: keymaps de todos os IDEs instalados (PhpStorm, IntelliJ, etc.)

### Workflow Recomendado

1. **Antes de modificar**: Faça backup das configurações atuais
   ```bash
   ~/.claude/skills/mac-to-linux-keys/scripts/backup-keybindings.sh backup
   ```

2. **Configure** usando esta skill (Karabiner, JetBrains, etc.)

3. **Se algo der errado**: Restaure o backup anterior
   ```bash
   ~/.claude/skills/mac-to-linux-keys/scripts/backup-keybindings.sh restore
   ```

4. **Após configurar com sucesso**: Faça novo backup para preservar as configs funcionais

**Local dos backups**: `~/backups/linux-keybindings-on-mac/`

## Arquivos de Dados

O registro de keybindings é armazenado em `~/.claude/skills/mac-to-linux-keys/data/`:

| Arquivo | Descrição |
|---------|-----------|
| `registry.json` | Registro principal de apps e keybindings detectados |
| `conflicts.json` | Conflitos conhecidos, detectados e irresolvíveis |
| `user-reports.json` | Problemas reportados pelo usuário |
| `system-shortcuts.json` | Atalhos macOS irremovíveis (referência) |
| `binds/tmux.txt` | Dump de todas as binds do tmux (`dump-binds.sh`) |
| `binds/ghostty.txt` | Dump de todas as binds do Ghostty (`dump-binds.sh`) |

Assets versionados (reaplicáveis nos 3 hosts):

| Arquivo | Descrição |
|---------|-----------|
| `assets/karabiner/linux-mode.json` | Remapeamentos principais do Karabiner |
| `assets/jetbrains/Linux Style.xml` | Keymap "Linux Style" dos IDEs JetBrains |
| `assets/antigravity/keybindings.json` | Keymap Linux do Antigravity IDE (119 binds) |

### Estrutura do Registry

```json
{
  "version": "1.0",
  "last_sync": "2026-02-03T10:00:00Z",
  "applications": {
    "karabiner": { "installed": true, "current_profile": "..." },
    "jetbrains": { "installed": true, "ides": [...] },
    "vscode": { "installed": true },
    "terminals": { "apps": [...] },
    "alttab": { "installed": true, "running": true },
    "macos": { "installed": true }
  }
}
```

## Notas Importantes

1. **Conflitos Emacs**: macOS usa Ctrl+A/E/K nativamente (atalhos Emacs). O Karabiner os remapeia, mas podem haver conflitos em alguns apps.

2. **Teclados externos**: Se usar teclado Windows externo, pode precisar ajustar mapeamento de Command/Option no System Preferences > Keyboard > Modifier Keys.

3. **Sincronização automática**: O registro é sincronizado automaticamente ao invocar `/mac-to-linux-keys`. Use `/mac-to-linux-keys status` para ver o estado atual sem modificar.
