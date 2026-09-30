#!/usr/bin/env bash
# Abre o nwg-displays e, ao fechar, reinjeta o modeline full-range nos monitores EXTERNOS.
# nwg reescreve monitors.lua com mode="WxH@Hz" (CEA) e o i915 manda RGB limited => monitor lavado.
# Aqui troca so o mode de cada output != eDP-1 por um modeline CVT-RB (nao-CEA) da MESMA resolucao,
# que força full range. Preserva a posicao/escala que o nwg gravou.
# Generico: funciona com qualquer monitor externo (casa=DP-3, trabalho=outro) e qualquer resolucao.
# ponytail: assume laptop = eDP-1; se o painel interno tiver outro nome, ajustar INTERNAL.
set -uo pipefail
LUA="$HOME/.config/hypr/monitors.lua"
INTERNAL="eDP-1"

nwg-displays "$@"

[ -f "$LUA" ] || exit 0

# Reescreve cada bloco: output externo com mode "WxH@R" -> mode "modeline <cvt -r>".
python3 - "$LUA" "$INTERNAL" <<'PY'
import re, subprocess, sys
path, internal = sys.argv[1], sys.argv[2]
src = open(path).read()

def modeline(w, h, r):
    out = subprocess.run(["cvt", "-r", w, h, r], capture_output=True, text=True).stdout
    ml = out.strip().splitlines()[-1]
    ml = re.sub(r'^Modeline\s+"[^"]*"\s*', '', ml)
    return re.sub(r'\s+', ' ', ml).strip()

changed = False
def fix(block):
    global changed
    out = re.search(r'output\s*=\s*"([^"]+)"', block)
    mode = re.search(r'mode\s*=\s*"(\d+)x(\d+)@([\d.]+)"', block)
    if not out or not mode or out.group(1) == internal:
        return block
    w, h, r = mode.group(1), mode.group(2), str(round(float(mode.group(3))))
    changed = True
    return block[:mode.start()] + f'mode = "modeline {modeline(w, h, r)}"' + block[mode.end():]

new = re.sub(r'hl\.monitor\(\{.*?\}\)', lambda m: fix(m.group(0)), src, flags=re.S)
if changed:
    open(path, "w").write(new)
    print("CHANGED")
PY

if [ $? -eq 0 ] && grep -q modeline "$LUA"; then
    hyprctl reload >/dev/null && echo "full-range reinjetado nos externos"
fi
