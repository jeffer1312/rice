#!/usr/bin/env bash
# Gera ~/.config/hypr/monitors.lua com a disposicao dos monitores.
#
# Resolve tres problemas de uma vez:
#
# 1. ORDEM. `position = auto-right` encadeia numa ordem interna do Hyprland que nao
#    corresponde a disposicao fisica da mesa - e com dois monitores de modelo IDENTICO
#    (mesma description no hyprctl) nao ha como o automatico adivinhar qual esta onde.
#    Entao a ordem e um dado explicito, mas a POSICAO e calculada: cada monitor comeca
#    onde o anterior terminou, ja considerando o scale de cada um.
#
# 2. FULL RANGE (monitor lavado). O i915 com "Broadcast RGB = Automatic" manda limited
#    (16-235) quando o modo e CEA. Um modeline CVT-RB (nao-CEA) da MESMA resolucao força
#    full range (0-255). O modeline e calculado por `cvt -r` da resolucao nativa de CADA
#    monitor - nada de 1080p hardcoded, funciona em 1440p/4K.
#
# 3. VERTICAL. Sufixo ":above" poe o monitor ACIMA do painel interno (eDP-1) em vez de na
#    fila horizontal - o caso "monitor em cima do notebook". Bordas de baixo alinhadas ao
#    topo da fila; coordenadas normalizadas pra nunca ficarem negativas.
#
# Por que arquivo gerado e nao `hyprctl eval`: existindo regra de config para um output,
# o Hyprland ignora hl.monitor() aplicado em runtime. Só config + `hyprctl reload` gruda.
#
# 4. POSICAO LIVRE. Sufixo ":pos=XxY" crava a coordenada em vez de derivar da fila - e o
#    caminho pra arrastar os monitores no nwg-displays E manter o full range: o nwg da a
#    coordenada, este script continua dono do modeline. Sem esse sufixo nada muda.
#
# Uso:
#   displaylayout.sh <output>[:full][:above][:sat=X][:pos=XxY] [<output>[...] ...]
#     A ordem dos argumentos = ordem da esquerda para a direita (dos que NAO sao :above).
#     Sufixo ":full"     liga o RGB full range naquele monitor.
#     Sufixo ":above"    poe o monitor acima do painel interno.
#     Sufixo ":sat=X"    saturacao SDR do color management (1.0 neutro, ex: sat=1.25).
#     Sufixo ":pos=XxY"  posicao literal em pixels; ignora fila/above pra esse monitor.
#
#   Ex: displaylayout.sh eDP-1 DP-3:full:above
#       -> DP-3 (full range) em cima do eDP-1.
#   Ex: displaylayout.sh eDP-1 DP-1:full DP-2:full
#       -> eDP-1, depois os dois monitores a direita, ambos full range.
#   Ex: displaylayout.sh eDP-1:pos=1001x1080 DP-1:full:pos=0x0 HDMI-A-1:full:pos=1920x0
#       -> disposicao arrastada no nwg-displays, com full range preservado.
#
#   Sem argumentos: limpa o arquivo (volta tudo ao padrao do Hyprland).

set -uo pipefail

# Escreve monitors.lua, nao um arquivo proprio: hyprland.lua carrega monitors.lua POR
# ULTIMO e, na pratica, a ultima regra para um output vence. Uma fonte só evita a briga.
OUT_LUA="$HOME/.config/hypr/monitors.lua"
INTERNAL="eDP-1"

if [ "$#" -eq 0 ]; then
    {
        echo "-- GERADO por scripts/displaylayout.sh. Nao editar a mao."
        echo "-- (layout padrao, nenhuma regra)"
    } > "$OUT_LUA"
    echo "escrito: $OUT_LUA (limpo)"
    exit 0
fi

command -v hyprctl >/dev/null || { echo "erro: hyprctl nao encontrado" >&2; exit 1; }

# Todo o calculo (resolucao nativa, modeline, posicao 2D) em um python so - mais claro que
# arrays de bash e reaproveita hyprctl/cvt.
python3 - "$OUT_LUA" "$INTERNAL" "$@" <<'PY'
import sys, json, subprocess, re

out_lua, internal = sys.argv[1], sys.argv[2]
raw_args = sys.argv[3:]

try:
    mons = {m["name"]: m for m in json.loads(
        subprocess.run(["hyprctl", "monitors", "-j"], capture_output=True, text=True).stdout)}
except Exception as e:
    sys.stderr.write(f"erro: hyprctl monitors falhou ({e})\n")
    sys.exit(1)

def native(m):
    # maior modo disponivel (resolucao nativa), refresh e scale atuais
    w, h = m["width"], m["height"]
    for mode in (m.get("availableModes") or []):
        try:
            res, _ = mode.split("@")
            mw, mh = (int(x) for x in res.split("x"))
            if mw * mh > w * h:
                w, h = mw, mh
        except Exception:
            pass
    return w, h, round(float(m.get("refreshRate") or 60)), float(m.get("scale") or 1)

def modeline(w, h, r):
    # tr -s: cvt alinha em colunas com espacos multiplos e o parser do Hyprland rejeita
    # silenciosamente (cai no modo CEA = lavado).
    out = subprocess.run(["cvt", "-r", str(w), str(h), str(r)], capture_output=True, text=True).stdout
    line = out.strip().splitlines()
    if not line:
        return None
    ml = re.sub(r'^Modeline\s+"[^"]*"\s*', '', line[-1])
    return re.sub(r"\s+", " ", ml).strip()

entries = []
for arg in raw_args:
    parts = arg.split(":")
    name = parts[0]
    flags = parts[1:]
    m = mons.get(name)
    if not m:
        sys.stderr.write(f"aviso: '{name}' nao conectado, pulando\n")
        continue
    w, h, r, sc = native(m)
    above = "above" in flags and name != internal  # interno nunca sobe em si mesmo
    # pos=XxY crava a coordenada (arrastada no nwg-displays); malformado = ignora e cai na fila.
    pos = None
    raw_pos = next((f.split("=", 1)[1] for f in flags if f.startswith("pos=")), None)
    if raw_pos:
        mo = re.fullmatch(r"(-?\d+)x(-?\d+)", raw_pos)
        if mo:
            pos = (int(mo.group(1)), int(mo.group(2)))
        else:
            sys.stderr.write(f"aviso: pos invalido em '{arg}', usando a fila\n")
    entries.append({
        "name": name,
        "full": "full" in flags,
        "above": above,
        "pos": pos,
        "sat": next((f.split("=", 1)[1] for f in flags if f.startswith("sat=")), None),
        "lw": round(w / sc), "lh": round(h / sc),
        "w": w, "h": h, "r": r, "sc": sc,
    })

# Quem tem :pos= sai do calculo por completo - a coordenada e o dado, nao a ordem.
fixed = [e for e in entries if e["pos"]]
flow = [e for e in entries if not e["pos"]]
for e in fixed:
    e["x"], e["y"] = e["pos"]

# Fila horizontal (os que NAO sao :above), esquerda->direita, y=0.
x = 0
for e in flow:
    if e["above"]:
        continue
    e["x"], e["y"] = x, 0
    x += e["lw"]

# Ancora dos :above = onde o interno caiu na fila; sem interno, comeca em 0.
anchor_x = next((e["x"] for e in flow if e["name"] == internal and not e["above"]), 0)

# :above sobem acima do interno, base alinhada ao topo da fila (y = -altura logica).
x = anchor_x
for e in flow:
    if not e["above"]:
        continue
    e["x"], e["y"] = x, -e["lh"]
    x += e["lw"]

# Normaliza pra nao ter coordenada negativa - so na fila calculada. Coordenada arrastada e
# literal: deslocar o conjunto inteiro moveria o monitor pra onde o usuario nao pos.
if flow and not fixed:
    minx = min(e["x"] for e in flow)
    miny = min(e["y"] for e in flow)
    for e in flow:
        e["x"] -= minx
        e["y"] -= miny

lines = [
    "-- GERADO por scripts/displaylayout.sh. Nao editar a mao.",
    "-- Ordem, full range e 'acima': Control Center > Display.",
]
for e in entries:
    if e["full"]:
        ml = modeline(e["w"], e["h"], e["r"])
        if ml:
            mode = f"modeline {ml}"
        else:
            sys.stderr.write(f"aviso: cvt falhou para {e['name']}, usando modo preferido\n")
            mode = "preferred"
    else:
        mode = "preferred"
    sat = f', sdrsaturation = {e["sat"]}' if e["sat"] else ""
    lines.append(
        f'hl.monitor({{ output = "{e["name"]}", mode = "{mode}", '
        f'position = "{e["x"]}x{e["y"]}", scale = {e["sc"]}{sat} }})')
    sys.stderr.write(
        f"  {e['name']}  {e['w']}x{e['h']}@{e['r']}  scale={e['sc']}  "
        f"pos={e['x']}x{e['y']}  full={e['full']}  above={e['above']}  sat={e['sat'] or '-'}\n")

open(out_lua, "w").write("\n".join(lines) + "\n")
sys.stderr.write(f"escrito: {out_lua}\n")
PY
