-- Override do base hyprland/variables.lua (carregado logo antes, via hyprland/keybinds.lua).
-- workspaceGroupSize decide pra onde o super+<numero> vai: workspace_in_group() em
-- hyprland/lib/init.lua faz floor((atual-1)/N)*N + i.
--
-- Quem manda nisso agora e o Control Center > Tela > "Workspaces por monitor": o
-- services/WorkspaceRules.qml empurra este global via `hyprctl eval` junto com as regras
-- (eval compartilha o estado Lua do config), e reaplica a cada reload/hotplug. Valor =
-- bar.workspaces.shown * numero de monitores, pra super+<numero> ser ABSOLUTO no PC inteiro
-- (super+2 = ws 2 de qualquer tela), nao relativo a tela focada.
--
-- Os valores abaixo so valem na janela entre o Hyprland subir e o quickshell subir. Mexer
-- aqui e inutil: o Control Center sobrescreve logo em seguida.
workspaceGroupSize = 8
workspaceFirst = 1

-- Terminal sem o `-1` (single instance) do padrao. Com `-1`, todo super+T/super+Enter vira
-- um pedido "abre janela" mandado pro socket @kitty-ipc-1000 da instancia mestre; se ela
-- travar, o pedido some sem erro nenhum e o atalho simplesmente para de abrir terminal
-- (07/08/2026: mestre aceitando conexao e ignorando os pedidos). Sem `-1`, cada terminal e
-- processo proprio e nao existe ponto unico de falha. Resto da lista de fallback intacta.
terminal = "~/.config/hypr/hyprland/scripts/launch_first_available.sh 'foot' 'kitty' 'alacritty' 'wezterm' 'konsole' 'kgx' 'uxterm' 'xterm'"
