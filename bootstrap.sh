#!/bin/bash
# Instala o rice numa instalacao limpa do CachyOS.
# Uso: git clone https://github.com/jeffer1312/rice ~/rice && ~/rice/bootstrap.sh
set -euo pipefail

RICE="$(cd "$(dirname "$0")" && pwd)"
END4_REPO="https://github.com/end-4/dots-hyprland.git"
# Commit do end-4 em que este rice foi feito: o quickshell/ii daqui e um fork dele.
END4_COMMIT="547836f1b01a45445cfbbcd92b206d1b5ceee4d9"
PACKAGES=(hypr quickshell matugen fuzzel wlogout kitty foot fontconfig starship mpv cava nwg-drawer micro dolphin fish)

[ "$(id -u)" -eq 0 ] && { echo "Rode como usuario normal, nao root."; exit 1; }
command -v pacman >/dev/null || { echo "Precisa de Arch/CachyOS (pacman)."; exit 1; }

echo "==> Pacotes extras"
sudo pacman -S --needed --noconfirm $(grep -v '^#' "$RICE/packages.txt")

echo "==> end-4 (dependencias, servicos e arquivos padrao)"
END4="$HOME/.cache/dots-hyprland"
[ -d "$END4/.git" ] || git clone "$END4_REPO" "$END4"
git -C "$END4" fetch --quiet origin
git -C "$END4" checkout --quiet "$END4_COMMIT"
(cd "$END4" && ./setup install -f)

echo "==> Configs do rice por cima do end-4"
# Tira a copia que o end-4 acabou de instalar (ele ja fez backup do que havia antes);
# stow --adopt nao serve: aborta nos symlinks que o end-4 cria.
for pkg in "${PACKAGES[@]}"; do
    (cd "$RICE/$pkg" && find . \( -type f -o -type l \) -printf '%P\n') |
        while IFS= read -r rel; do rm -f "$HOME/$rel"; done
done
stow --no-folding -d "$RICE" -t "$HOME" "${PACKAGES[@]}"

echo "==> Wallpaper e config da barra"
wall="$HOME/.local/share/rice/wallpaper.jpg"
mkdir -p "$(dirname "$wall")"
cp "$RICE/wallpapers/default.jpg" "$wall"
videos="$(xdg-user-dir VIDEOS 2>/dev/null || echo "$HOME/Videos")"
mkdir -p "$HOME/.config/illogical-impulse"
sed -e "s|__WALLPAPER__|$wall|" -e "s|__VIDEOS__|$videos|" \
    "$RICE/templates/illogical-impulse-config.json" > "$HOME/.config/illogical-impulse/config.json"

echo
echo "Pronto. Reinicie e entre na sessao Hyprland."
echo "Na primeira vez, Ctrl+Super+T escolhe o wallpaper e gera as cores."
