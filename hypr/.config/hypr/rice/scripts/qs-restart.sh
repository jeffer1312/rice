#!/usr/bin/env bash
# Reinicio do Quickshell para o atalho CTRL + SUPER + R.
#
# Substitui o one-liner antigo do keybind:
#
#     killall ydotool qs quickshell; qs -c $qsConfig &
#
# que tinha tres problemas:
#
#   1. Nao esperava o processo antigo morrer. O novo qs subia enquanto o velho
#      ainda segurava as superficies layer-shell, perdia a corrida e saia.
#   2. "killall qs" derrubava junto o painel do claude-pocket ("qs -n -c
#      claude-pocket"), que e outra instancia e nao tem nada com isso.
#   3. Nao olhava o barramento. Se o dbus-broker da sessao esta fora do ar o qs
#      sobe mas nao desenha nada - foi o que aconteceu em 15/08/2026, quando o
#      vazamento de descritores do xdph (issue #419) derrubou o broker e o
#      atalho passou a "nao funcionar". O atalho e justamente a unica coisa que
#      o usuario alcanca com a tela vazia, entao ele precisa consertar o
#      barramento antes de tentar desenhar.
#
# Rodar sem argumento reinicia a config "ii". --self-test confere as pecas sem
# derrubar nada.

set -uo pipefail

CONFIG="${1:-ii}"

log() { logger -t qs-restart "$*"; }

# Chamado de um keybind do Hyprland essas variaveis ja vem prontas; chamado de
# um terminal qualquer (o caso real quando a barra sumiu) nao vem.

# So diretorio: /run/user/UID/hypr guarda tambem os PNG de screenshot do
# xdg-desktop-portal-hyprland, e como o -t ordena por mtime um print recente
# ganha da pasta da sessao. Em 31/08/2026 o HIS virou "xdph_screenshot_*.png" -
# justo no caminho que existe pra quando a barra sumiu.
his_from_runtime() {
	local d
	d=$(ls -td "/run/user/$(id -u)/hypr/"*/ 2>/dev/null | head -1)
	[ -n "$d" ] || return 1
	basename "$d"
}
export HYPRLAND_INSTANCE_SIGNATURE="${HYPRLAND_INSTANCE_SIGNATURE:-$(his_from_runtime)}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-$(ls /run/user/$(id -u) 2>/dev/null | grep -E '^wayland-[0-9]+$' | head -1)}"

# Casa so a instancia desta config. O claude-pocket ("qs -n -c claude-pocket")
# nao bate no padrao, e a cmdline deste script tambem nao.
# A barra do boot, depois do quickshell reexecutar a si mesmo, aparece como
# "/usr/bin/quickshell" sem "-c ii"; sem casar essa forma o atalho matava so a
# instancia nova e deixava a velha duplicando a barra.
qs_pattern() {
	if [ "${CONFIG}" = "ii" ]; then
		echo "(^|/)(qs|quickshell)( -c ii)?$"
	else
		echo "(^|/)(qs|quickshell) -c ${CONFIG}$"
	fi
}
qs_pids() { pgrep -f "$(qs_pattern)" 2>/dev/null; }

# Um barramento vivo lista dezenas de servicos. Morto lista zero - e ai o
# busctl ainda sai com codigo 0, entao a contagem de linhas e o teste confiavel.
bus_ok() {
	local n
	n=$(timeout 5 busctl --user list --no-pager 2>/dev/null | wc -l)
	[ "${n:-0}" -gt 5 ]
}

# So mexe no broker se ele estiver realmente fora - restart a toa desconecta
# todo mundo. O timeout existe porque com o barramento degradado o systemctl
# pendura sem retornar (medido: 25s), e nesse caso seguimos assim mesmo.
fix_bus() {
	bus_ok && return 0
	log "barramento fora do ar - reiniciando dbus-broker"
	timeout 20 systemctl --user restart dbus-broker.service >/dev/null 2>&1
	for _ in $(seq 15); do
		bus_ok && { log "barramento de volta"; return 0; }
		sleep 1
	done
	log "barramento nao voltou - subindo o qs mesmo assim"
	return 1
}

stop_qs() {
	local pids
	pids=$(qs_pids) || return 0
	[ -n "$pids" ] || return 0
	log "derrubando qs -c ${CONFIG} (pids: ${pids//$'\n'/ })"
	kill $pids 2>/dev/null
	for _ in $(seq 20); do
		[ -z "$(qs_pids)" ] && return 0
		sleep 0.2
	done
	log "qs nao saiu em 4s - kill -9"
	kill -9 $(qs_pids) 2>/dev/null
	sleep 0.5
}

# setsid solta do shell do keybind: sem isso o qs morre junto quando o Hyprland
# encerra o exec.
start_qs() {
	setsid qs -c "$CONFIG" >/dev/null 2>&1 </dev/null &
	for _ in $(seq 25); do
		sleep 0.4
		[ -n "$(qs_pids)" ] && { log "qs -c ${CONFIG} subiu (pid $(qs_pids | head -1))"; return 0; }
	done
	log "qs -c ${CONFIG} NAO subiu"
	return 1
}

self_test() {
	local fails=0

	# Nao basta estar preenchido: a versao antiga aceitava o nome de um PNG de
	# screenshot. Vale so se o socket da sessao existir de verdade.
	if [ -S "/run/user/$(id -u)/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket.sock" ]; then
		echo "ok: HIS=${HYPRLAND_INSTANCE_SIGNATURE}"
	else
		echo "FALHA: HIS sem socket: '${HYPRLAND_INSTANCE_SIGNATURE}'"; fails=1
	fi
	[ -n "$WAYLAND_DISPLAY" ] && echo "ok: WAYLAND_DISPLAY=${WAYLAND_DISPLAY}" \
		|| { echo "FALHA: WAYLAND_DISPLAY vazio"; fails=1; }

	bus_ok && echo "ok: barramento respondendo" || echo "aviso: barramento fora do ar agora"

	# O padrao nao pode pegar o painel do claude-pocket nem este script.
	if qs_pids | grep -qx "$$"; then
		echo "FALHA: padrao casa o proprio script"; fails=1
	else
		echo "ok: script fora da conta"
	fi
	if qs_pids | grep -qxF "$(pgrep -f 'qs -n -c (claude-pocket|hangar)' | head -1)"; then
		echo "FALHA: padrao casa o painel do claude-pocket"; fails=1
	else
		echo "ok: claude-pocket fora da conta"
	fi

	[ -n "$(qs_pids)" ] && echo "ok: qs -c ${CONFIG} vivo (pid $(qs_pids | head -1))" \
		|| echo "aviso: qs -c ${CONFIG} fora do ar agora"

	[ "$fails" -eq 0 ] && echo "SELF-TEST OK" || echo "SELF-TEST FALHOU"
	return "$fails"
}

[ "${1:-}" = "--self-test" ] && { CONFIG=ii; self_test; exit $?; }

killall ydotool 2>/dev/null
fix_bus
stop_qs
start_qs
