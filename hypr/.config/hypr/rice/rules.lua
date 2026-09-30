hl.window_rule({ match = { class = "kitty" }, opacity = "0.95 override 0.95 override" })
hl.window_rule({ match = { class = "com.mitchellh.ghostty" }, opacity = "0.95 override 0.95 override" })

-- Workspaces presos por monitor: moram no Control Center > Tela > "Workspaces por
-- monitor" (services/WorkspaceRules.qml do quickshell/ii aplica via `hyprctl eval`).
-- Nao remontar o bloco estatico aqui: o nome do output muda conforme o ambiente
-- (eDP-1/HDMI-A-1/DP-1 vs DP-3) e a regra fixa morre calada quando nao casa.
