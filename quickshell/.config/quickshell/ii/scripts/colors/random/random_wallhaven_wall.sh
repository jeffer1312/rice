#!/usr/bin/env bash

get_pictures_dir() {
    if command -v xdg-user-dir &> /dev/null; then
        xdg-user-dir PICTURES
        return
    fi

    local config_file="${XDG_CONFIG_HOME:-$HOME/.config}/user-dirs.dirs"
    if [ -f "$config_file" ]; then
        local pictures_path
        pictures_path=$(source "$config_file" >/dev/null 2>&1; echo "$XDG_PICTURES_DIR")
        echo "${pictures_path/#\$HOME/$HOME}"
        return
    fi

    echo "$HOME/Pictures"
}

QUICKSHELL_CONFIG_NAME="ii"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
PICTURES_DIR=$(get_pictures_dir)
CONFIG_DIR="$XDG_CONFIG_HOME/quickshell/$QUICKSHELL_CONFIG_NAME"
CACHE_DIR="$XDG_CACHE_HOME/quickshell"
STATE_DIR="$XDG_STATE_HOME/quickshell"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$PICTURES_DIR/Wallpapers"

illogicalImpulseConfigPath="$HOME/.config/illogical-impulse/config.json"
userAgent=$(jq -r '.networking.userAgent // empty' "$illogicalImpulseConfigPath" 2>/dev/null)

# Menor resolucao entre os monitores, para nunca cair no aviso de upscale
minWidth=$(hyprctl monitors -j | jq '([.[].width] | min)' 2>/dev/null)
minHeight=$(hyprctl monitors -j | jq '([.[].height] | min)' 2>/dev/null)
[[ -z "$minWidth" || "$minWidth" == "null" ]] && minWidth=1920
[[ -z "$minHeight" || "$minHeight" == "null" ]] && minHeight=1080

# Tema: 1o argumento, senao o que estiver salvo na config, senao "all"
theme="$1"
if [ -z "$theme" ]; then
    theme=$(jq -r '.background.wallhavenTheme // "all"' "$illogicalImpulseConfigPath" 2>/dev/null)
fi
if [ -z "$theme" ] || [ "$theme" == "null" ]; then
    theme="all"
fi

# categories: general|anime|people -> "100" = so general, "010" = so anime, "110" = general+anime
# purity=100 -> apenas SFW, sempre
case "$theme" in
    anime)  categories="010"; query="" ;;
    marvel) categories="110"; query="marvel" ;;
    gaming) categories="110"; query="gaming" ;;
    space)  categories="100"; query="space" ;;
    nature) categories="100"; query="nature" ;;
    all|*)  categories="100"; query="" ;;
esac

apiUrl="https://wallhaven.cc/api/v1/search?categories=${categories}&purity=100&sorting=random&atleast=${minWidth}x${minHeight}"
[ -n "$query" ] && apiUrl="${apiUrl}&q=${query}"
response=$(curl -fsS -A "$userAgent" "$apiUrl")
if [ -z "$response" ]; then
    notify-send "Wallpaper switcher" "Não foi possível consultar o Wallhaven." -a "Wallpaper switcher" -c "im.error"
    exit 1
fi

link=$(echo "$response" | jq -r '.data[0].path // empty')
if [ -z "$link" ]; then
    notify-send "Wallpaper switcher" "O Wallhaven não retornou nenhuma imagem." -a "Wallpaper switcher" -c "im.error"
    exit 1
fi

ext=$(echo "$link" | awk -F. '{print $NF}')
downloadPath="$PICTURES_DIR/Wallpapers/random_wallpaper.$ext"
currentWallpaperPath=$(jq -r '.background.wallpaperPath' "$illogicalImpulseConfigPath")
if [ "$downloadPath" == "$currentWallpaperPath" ]; then
    downloadPath="$PICTURES_DIR/Wallpapers/random_wallpaper-1.$ext"
fi

if ! curl -fsS -A "$userAgent" "$link" -o "$downloadPath"; then
    notify-send "Wallpaper switcher" "Falha ao baixar a imagem do Wallhaven." -a "Wallpaper switcher" -c "im.error"
    exit 1
fi

"$SCRIPT_DIR/../switchwall.sh" --image "$downloadPath"
