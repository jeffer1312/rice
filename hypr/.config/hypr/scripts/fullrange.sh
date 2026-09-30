#!/usr/bin/env bash
# Gera ~/.config/hypr/fullrange.lua com uma regra hl.monitor() por monitor que deve
# usar RGB full range (0-255).
#
# Por que arquivo gerado em vez de `hyprctl eval`: uma vez que existe regra de config
# para um output, o Hyprland ignora hl.monitor() aplicado em runtime. Entao o unico
# caminho que gruda e escrever config + `hyprctl reload`.
#
# Como funciona o fix: o i915 com "Broadcast RGB = Automatic" escolhe limited (16-235)
# quando o modo e CEA. Um modeline CVT-RB (nao-CEA) da mesma resolucao/refresh força
# o driver a mandar full range. O modeline e calculado por `cvt -r` a partir da
# resolucao nativa de CADA monitor - nao ha 1080p hardcoded.
#
# Uso:
#   fullrange.sh <output> [<output> ...]   # esses ficam full range, o resto padrao
#   fullrange.sh                           # nenhum: limpa (todos voltam ao padrao)

set -uo pipefail

OUT_LUA="$HOME/.config/hypr/fullrange.lua"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

{
    echo "-- GERADO por scripts/fullrange.sh. Nao editar a mao."
    echo "-- Toggle por monitor no Control Center > Display."
} > "$TMP"

if [ "$#" -eq 0 ]; then
    echo "-- (nenhum monitor em full range)" >> "$TMP"
else
    # hyprctl monitors -j: pega resolucao/refresh NATIVOS de cada output conectado
    MONS="$(hyprctl monitors -j 2>/dev/null)"
    [ -z "$MONS" ] && { echo "erro: hyprctl monitors falhou (Hyprland rodando?)" >&2; exit 1; }

    for out in "$@"; do
        # width/height preferidos + refresh atual do output
        read -r W H R < <(printf '%s' "$MONS" | python3 -c "
import sys, json
out = '$out'
for m in json.load(sys.stdin):
    if m['name'] == out:
        # usa o modo preferido (nativo), nao o atual - o atual pode ja ser o modeline
        modes = m.get('availableModes') or []
        w, h = m['width'], m['height']
        for mode in modes:
            try:
                res, rate = mode.split('@')
                mw, mh = (int(x) for x in res.split('x'))
                if mw * mh > w * h:
                    w, h = mw, mh
            except Exception:
                pass
        print(w, h, round(float(m.get('refreshRate') or 60)))
        break
" 2>/dev/null)

        if [ -z "${W:-}" ]; then
            echo "aviso: output '$out' nao encontrado/conectado, pulando" >&2
            continue
        fi

        # cvt -r = CVT reduced blanking, o modo nao-CEA que destrava full range
        ML="$(cvt -r "$W" "$H" "$R" 2>/dev/null | tail -1 | sed 's/^Modeline "[^"]*"[[:space:]]*//')"
        if [ -z "$ML" ]; then
            echo "aviso: cvt falhou para $out ${W}x${H}@${R}, pulando" >&2
            continue
        fi

        echo "hl.monitor({ output = \"$out\", mode = \"modeline $ML\", position = \"auto-right\", scale = 1 })" >> "$TMP"
        echo "gerado: $out ${W}x${H}@${R} -> modeline $ML" >&2
    done
fi

mv "$TMP" "$OUT_LUA"
trap - EXIT
echo "escrito: $OUT_LUA"
