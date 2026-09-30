-- Carregado DEPOIS de hyprland/keybinds.lua, então sobrescreve/adiciona.

-- Editar config da shell / editar estes keybinds
hl.bind("CTRL + SUPER + Slash", hl.dsp.exec_cmd("xdg-open ~/.config/illogical-impulse/config.json"), { description = "Edit shell config" })
hl.bind("CTRL + SUPER + ALT + Slash", hl.dsp.exec_cmd("xdg-open ~/.config/hypr/custom/keybinds.lua"), { description = "Edit user keybinds" })

-- ##! Window Management
hl.bind("SUPER + SHIFT + H", hl.dsp.workspace.toggle_special("minimize"), { description = "Show all minimized windows" })

-- ##! Launchers
hl.bind("ALT + A", hl.dsp.exec_cmd("nwg-drawer"), { description = "App drawer (grid)" })

-- ##! Shell
hl.bind("SUPER + U", hl.dsp.global("quickshell:controlCenterToggle"), { description = "Shell: Toggle control center" })

-- ##! Workspace Navigation
-- Super+Ctrl+N: mover janela E seguir para o workspace N (move & follow)
-- Usa keycodes crus pra funcionar independente do layout (br/abnt2), fila principal + keypad.
for i = 1, 10 do
    local numberkey = { 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 }
    hl.bind("SUPER + CTRL + code:" .. numberkey[i], function()
        hl.dispatch(hl.dsp.window.move({ workspace = workspace_in_group(i), follow = true }))
    end, { description = "Window: Move and follow to workspace " .. i })
end
for i = 1, 10 do
    local numpadkey = { 87, 88, 89, 83, 84, 85, 79, 80, 81, 90 }
    hl.bind("SUPER + CTRL + code:" .. numpadkey[i], function()
        hl.dispatch(hl.dsp.window.move({ workspace = workspace_in_group(i), follow = true }))
    end)
end

-- Super+Shift+N: workspace 10+N (11, 12, ...). Teclado so tem 10 digitos e bind dispara no
-- primeiro toque — "digitar 11" nao existe; shift e a dezena.
-- GOTCHA: hl.bind com "code:NN" registra bind SEM tecla neste fork (key="", keycode=0,
-- confirmado via hyprctl binds -j) — nunca dispara. Por isso keysym, nas DUAS formas:
-- o numero e o simbolo shiftado do ABNT2 (shift+1="!", shift+2="@", ...).
-- Guard: nao passa do total de workspaces do PC (workspaceGroupSize, ex: 12 = shift+1 e
-- shift+2 validos, shift+3.. mortos).
for i = 1, 10 do
    local shifted = { "exclam", "at", "numbersign", "dollar", "percent",
        "dead_diaeresis", "ampersand", "asterisk", "parenleft", "parenright" }
    -- Numpad: shift INVERTE o NumLock no XKB — com NumLock ligado, shift+KP2 sai KP_Down;
    -- desligado, sai KP_2. Binda as duas formas pra cobrir os dois estados.
    local kp_digit = { "KP_1", "KP_2", "KP_3", "KP_4", "KP_5", "KP_6", "KP_7", "KP_8", "KP_9", "KP_0" }
    local kp_nav = { "KP_End", "KP_Down", "KP_Next", "KP_Left", "KP_Begin",
        "KP_Right", "KP_Home", "KP_Up", "KP_Prior", "KP_Insert" }
    local function go()
        if 10 + i > (workspaceGroupSize or 30) then return end
        hl.dispatch(hl.dsp.focus({ workspace = workspace_in_group(10 + i) }))
    end
    hl.bind("SUPER + SHIFT + " .. (i % 10), go, { description = "Workspace: Focus " .. (10 + i) })
    hl.bind("SUPER + SHIFT + " .. shifted[i], go)
    hl.bind("SUPER + SHIFT + " .. kp_digit[i], go)
    hl.bind("SUPER + SHIFT + " .. kp_nav[i], go)
end

-- Super+numpad: foca workspace 1..10, igual super+numero da fileira de cima. Os binds de
-- numpad do base usam code: (mortos neste fork); aqui por keysym, nas duas formas do
-- NumLock (ligado = KP_1.., desligado = KP_End/Down/...). Essencial pro lan-mouse: o PC
-- host precisa NAO ter super+numpad bindado pra tecla ser encaminhada pra ca.
for i = 1, 10 do
    local kp_digit = { "KP_1", "KP_2", "KP_3", "KP_4", "KP_5", "KP_6", "KP_7", "KP_8", "KP_9", "KP_0" }
    local kp_nav = { "KP_End", "KP_Down", "KP_Next", "KP_Left", "KP_Begin",
        "KP_Right", "KP_Home", "KP_Up", "KP_Prior", "KP_Insert" }
    local function go()
        if i > (workspaceGroupSize or 10) then return end
        hl.dispatch(hl.dsp.focus({ workspace = workspace_in_group(i) }))
    end
    hl.bind("SUPER + " .. kp_digit[i], go, { description = "Workspace: Focus " .. i .. " (numpad)" })
    hl.bind("SUPER + " .. kp_nav[i], go)
end

-- ##! Limite de workspaces
-- Workspace no Hyprland e infinito (scroll/setas criam o proximo sem parar). ws_step
-- substitui toda navegacao relativa: anda delta e para nas bordas da faixa DESTE PC
-- ([workspaceFirst, workspaceFirst+workspaceGroupSize-1], setados pelo Control Center).
-- Clamp ABSOLUTO de proposito: se o foco escapou pra fora da faixa (ws 22 etc), qualquer
-- passo traz de volta pra borda — clampar no "grupo atual" deixava o usuario preso la fora.
-- Global de proposito: o scroll do bar (quickshell Workspaces.qml) dispatcha ws_step tambem.
function ws_step(delta)
    local G = workspaceGroupSize or 10
    local first = workspaceFirst or 1
    local curr = hl.get_active_workspace().id
    local target = math.max(first, math.min(curr + delta, first + G - 1))
    hl.dispatch(hl.dsp.focus({ workspace = target }))
end

-- Redefine o workspace_in_group do base (hyprland/lib/init.lua): a versao original deriva
-- do workspace FOCADO (floor((atual-1)/G)*G+i) — com o foco fora da faixa, super+1 ia parar
-- em ws 17+ em vez do 1. Com workspaceFirst por PC, o mapa e fixo: super+N = first-1+N,
-- de qualquer lugar. PC2 do par lan-mouse seta first=9 e super+1..8 vira 9-16, como antes.
function workspace_in_group(i)
    return (workspaceFirst or 1) - 1 + i
end

-- Tira os binds relativos do base (sem limite) e repoe clampados, mesmas teclas.
local relative_binds = {
    { "SUPER + mouse_up", 1 },
    { "SUPER + mouse_down", -1 },
    { "CTRL + SUPER + mouse_up", 1 },
    { "CTRL + SUPER + mouse_down", -1 },
    { "SUPER + Page_Down", 1 },
    { "SUPER + Page_Up", -1 },
    { "CTRL + SUPER + Page_Down", 1 },
    { "CTRL + SUPER + Page_Up", -1 },
    { "CTRL + SUPER + Right", 1 },
    { "CTRL + SUPER + Left", -1 },
    { "CTRL + SUPER + BracketRight", 1 },
    { "CTRL + SUPER + BracketLeft", -1 },
    { "CTRL + SUPER + Down", 5 },
    { "CTRL + SUPER + Up", -5 },
}
for _, b in ipairs(relative_binds) do
    hl.unbind(b[1])
    hl.bind(b[1], function() ws_step(b[2]) end,
        { description = "Workspace: Focus " .. (b[2] > 0 and "+" or "") .. b[2] .. " (limitado)", dont_inhibit = true })
end

-- ##! Atalhos que furam a captura de teclado (VM por RDP com +grab-keyboard)
-- Com a VM em foco todo atalho vai pro Windows; estes ficam no Linux pra dar pra sair dela.
hl.unbind("SUPER + Q")
hl.bind("SUPER + Q", hl.dsp.window.close(), { description = "Window: Close", dont_inhibit = true })
hl.unbind("SUPER + Tab")
hl.bind("SUPER + Tab", hl.dsp.global("quickshell:overviewWorkspacesToggle"),
    { description = "Shell: Toggle overview", dont_inhibit = true })
for i = 1, 10 do
    hl.unbind("SUPER + " .. (i % 10))
    hl.bind("SUPER + " .. (i % 10), function()
        hl.dispatch(hl.dsp.focus({ workspace = workspace_in_group(i) }))
    end, { description = "Workspace: Focus " .. i, dont_inhibit = true })
end

