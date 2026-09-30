-- put former exec-once commands inside the func and former exec commands outside
hl.on("hyprland.start", function ()

    -- Bar, wallpaper
    hl.exec_cmd("$HOME/.config/hypr/hyprland/scripts/start_geoclue_agent.sh")
    -- Barra sem cap de cgroup, protegida por watchdog (qs-watchdog.sh).
    -- O cap antigo (systemd-run --scope -p MemoryMax=2G) valia pro cgroup
    -- inteiro, e app aberto pela barra nasce filho do qs -> herdava o limite.
    -- Em 2026-07-20 isso derrubou a barra: 11 xfreerdp3 pendurados somaram
    -- 957MB, estouraram os 2G, o OOM killer matou o slack e o systemd derrubou
    -- o scope junto (OOMPolicy=stop). O watchdog mede o RSS do processo qs, nao
    -- do grupo: app aberto pela barra nao conta, e a barra reinicia sozinha se
    -- vazar/duplicar. systemd-oomd cobre o resto do sistema.
    hl.exec_cmd("qs -c $qsConfig")
    hl.exec_cmd("$HOME/.config/hypr/rice/scripts/qs-watchdog.sh $qsConfig 2500 60")
    -- Vazamento de descritores do EIS no xdg-desktop-portal-hyprland
    -- (hyprwm/xdg-desktop-portal-hyprland#419, sem correcao). Cada travessia do
    -- lan-mouse deixa um descritor preso; quando estoura o teto do kernel o
    -- D-Bus da sessao morre e leva a barra e todo app grafico junto - foi o que
    -- aconteceu em 2026-08-13. Reiniciar o xdph solta tudo.
    hl.exec_cmd("$HOME/.config/hypr/rice/scripts/xdph-watchdog.sh 60 60")
    hl.exec_cmd("$HOME/.config/hypr/custom/scripts/__restore_video_wallpaper.sh")

    -- Core components (authentication, lock screen, notification daemon)
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("dbus-update-activation-environment --all")
    hl.exec_cmd("sleep 1 && dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP") -- Some fix idk

    -- Audio
    hl.exec_cmd("easyeffects --hide-window --service-mode")

    -- Clipboard: history
    --hl.exec_cmd("wl-paste --watch cliphist store")
    hl.exec_cmd("wl-paste --type text --watch bash -c 'cliphist store && qs -c $qsConfig ipc call cliphistService update'")
    hl.exec_cmd("wl-paste --type image --watch bash -c 'cliphist store && qs -c $qsConfig ipc call cliphistService update'")

    -- Cursor
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Classic 24")
end)
