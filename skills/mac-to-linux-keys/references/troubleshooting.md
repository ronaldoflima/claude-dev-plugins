# Troubleshooting - Linux to macOS Keymaps

## Problemas Comuns

### 1. Karabiner-Elements

#### Karabiner não inicia / Extensão do kernel não carrega

**Sintoma**: Karabiner mostra erro sobre kernel extension ou System Extension.

**Solução**:
1. Abra System Preferences > Security & Privacy > General
2. Clique em "Allow" para a extensão do Karabiner
3. Reinicie o Mac
4. Se ainda não funcionar:
   ```bash
   sudo /Library/Application\ Support/org.pqrs/Karabiner-Elements/bin/karabiner_kextd
   ```

#### Karabiner não tem permissão de Input Monitoring

**Sintoma**: Karabiner lista mas não remapeia teclas.

**Solução**:
1. System Preferences > Security & Privacy > Privacy > Input Monitoring
2. Adicione Karabiner-Elements e karabiner_grabber
3. Marque ambos como permitidos
4. Reinicie o Karabiner

#### Remapeamento funciona em alguns apps mas não em outros

**Sintoma**: Ctrl+C funciona no browser mas não no Finder.

**Causas possíveis**:
1. **App está na lista de exceções**: Verifique `~/.config/karabiner/karabiner.json` se o app não está listado em `frontmost_application_unless`
2. **App pede acesso especial**: Alguns apps (Parallels, Remote Desktop) capturam input antes do Karabiner

**Solução**:
```bash
# Ver quais apps estão nas exceções
grep -A 20 "frontmost_application_unless" ~/.config/karabiner/karabiner.json
```

#### Configuração não carrega após editar JSON

**Sintoma**: Editou o JSON mas Karabiner não aplica mudanças.

**Solução**:
1. Verifique erros de sintaxe JSON:
   ```bash
   python3 -m json.tool ~/.config/karabiner/karabiner.json > /dev/null
   ```
2. Se o JSON estiver correto, reinicie o Karabiner:
   ```bash
   launchctl stop org.pqrs.karabiner.karabiner_console_user_server
   launchctl start org.pqrs.karabiner.karabiner_console_user_server
   ```

### 2. AltTab

#### AltTab não aparece

**Sintoma**: Alt+Tab não faz nada ou abre Cmd+Tab nativo.

**Soluções**:
1. Verifique se AltTab está rodando:
   ```bash
   pgrep -l AltTab
   ```
2. Se não estiver, inicie manualmente ou adicione aos Login Items
3. Verifique permissões em System Preferences > Privacy > Accessibility

#### AltTab mostra apps ao invés de janelas

**Sintoma**: Comportamento igual ao Cmd+Tab nativo.

**Solução**:
1. Abra preferências do AltTab
2. Em "Appearance" > "Show windows from", selecione "All visible windows"
3. Desmarque "Show apps without windows"

#### AltTab trava ou fica lento

**Sintoma**: Demora para aparecer ou não responde.

**Solução**:
1. Reduza número de janelas abertas
2. Nas preferências, aumente "Apparition delay"
3. Desabilite thumbnails se tiver muitas janelas

### 3. Rectangle (Window Tiling)

#### Atalhos não funcionam

**Sintoma**: Super+← não faz nada.

**Soluções**:
1. Verifique se Rectangle tem permissão de Accessibility
2. Alguns apps (Adobe, Microsoft Office) podem bloquear - reinicie o app
3. Verifique conflitos com atalhos do Mission Control em System Preferences > Keyboard > Shortcuts

#### Janela não encaixa corretamente

**Sintoma**: Janela não preenche metade da tela.

**Causa**: Algumas apps definem tamanho mínimo.

**Solução**: Não há - limitação do app.

### 4. JetBrains IDEs

#### Keymap não aparece na lista

**Sintoma**: Após rodar `setup-jetbrains.sh`, "Linux Style" não aparece em Preferences > Keymap.

**Solução**:
1. Verifique se o arquivo foi copiado:
   ```bash
   ls ~/Library/Application\ Support/JetBrains/*/keymaps/Linux\ Style.xml
   ```
2. Reinicie a IDE completamente (não apenas a janela)
3. Se ainda não aparecer, importe manualmente:
   - File > Manage IDE Settings > Import Settings
   - Selecione o arquivo XML

#### Atalhos conflitam com macOS

**Sintoma**: Alguns atalhos abrem funções do sistema ao invés da IDE.

**Solução**:
1. Desabilite atalhos conflitantes do sistema:
   - System Preferences > Keyboard > Shortcuts
   - Desmarque atalhos de Mission Control, Spotlight, etc.
2. Ou use a IDE em tela cheia (menos conflitos)

#### Ctrl+C não copia na IDE

**Sintoma**: IDE está na lista de exceções do Karabiner.

**Solução**: A IDE usa seu próprio keymap. Se o keymap "Linux Style" estiver ativo, Ctrl+C deve funcionar para copiar. Se não:
1. Verifique se o keymap "Linux Style" está selecionado
2. Em Preferences > Keymap, busque "Copy" e verifique o atalho

### 5. Conflitos Gerais

#### Ctrl+A seleciona tudo ao invés de ir para início da linha

**Causa**: Remapeamento prevalece sobre atalho Emacs nativo.

**Solução**: Se você usa atalhos Emacs, edite `linux-mode.json` e remova a regra de Ctrl+A, ou adicione uma condição para apps específicos.

#### Tecla Super/Windows não funciona

**Sintoma**: Pressionar Super não abre Spotlight.

**Verificações**:
1. O Karabiner mapeia Super → Cmd, não Super sozinho → Spotlight
2. Para Super → Spotlight, adicione regra específica no Karabiner

#### Teclado externo Windows tem teclas trocadas

**Sintoma**: Command e Option parecem invertidos.

**Solução**:
1. System Preferences > Keyboard > Modifier Keys
2. Selecione seu teclado externo no dropdown
3. Troque Option ↔ Command

### 6. Diagnóstico Geral

#### Script de diagnóstico completo

```bash
~/.claude/skills/mac-to-linux-keys/scripts/diagnose.sh
```

#### Verificar se Karabiner está funcionando

```bash
# Ver eventos de teclado em tempo real
/Library/Application\ Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli --show-current-profile-name
```

#### Logs do Karabiner

```bash
# Ver logs recentes
log show --predicate 'subsystem == "org.pqrs.karabiner"' --last 5m
```

#### Resetar configuração do Karabiner

**CUIDADO**: Isso remove TODAS as suas configurações.

```bash
# Backup primeiro
cp -r ~/.config/karabiner ~/.config/karabiner.backup

# Reset
rm -rf ~/.config/karabiner
# Reinicie Karabiner - ele criará config padrão
```

## Suporte

Se o problema persistir:

1. **Karabiner**: https://github.com/pqrs-org/Karabiner-Elements/issues
2. **AltTab**: https://github.com/lwouis/alt-tab-macos/issues
3. **Rectangle**: https://github.com/rxhanson/Rectangle/issues

Inclua sempre:
- Versão do macOS
- Versão da ferramenta
- Logs relevantes
- Passos para reproduzir
