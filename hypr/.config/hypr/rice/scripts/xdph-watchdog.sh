#!/usr/bin/env bash
# Watchdog do xdg-desktop-portal-hyprland (xdph).
#
# Motivo: bug aberto hyprwm/xdg-desktop-portal-hyprland#419 (25/07/2026, sem
# correcao). O protocolo hyprland_input_capture_v1 nao tem destrutor: quando a
# sessao de InputCapture fecha, o xdph limpa so a estrutura local e nunca avisa
# o Hyprland. O descritor do EIS fica cacheado em m_sessions pra sempre.
#
# Quem alimenta isso aqui e o lan-mouse: cada travessia do mouse entre as
# maquinas abre e fecha uma sessao de captura, deixando mais descritores
# presos. Quando o total de descritores "em voo" do usuario passa do teto do
# kernel, qualquer envio de descritor por socket unix falha com ETOOMANYREFS
# ("Too many references: cannot splice").
#
# Foi exatamente o que derrubou a sessao em 13/08/2026: as 15:24 o
# xdg-desktop-portal caiu com esse erro, as 15:25 o dbus-broker da sessao caiu
# junto, e sem barramento nada grafico volta a subir - barra, Chrome, kitty e
# apps Electron ficaram todos travados esperando resposta de um D-Bus morto.
# O broker recusou subir de novo ate a maquina reiniciar.
#
# O issue registra que reiniciar o xdph solta TODOS os descritores presos na
# hora: "o caminho do destrutor funciona, so nao tem quem dispare". Este script
# e o gatilho que falta.
#
# Nao usa timer cego: mede os descritores do proprio processo e so reinicia
# quando eles crescem. xdph recem-subido fica em ~19; cada sessao vazada soma
# alguns. Reiniciar custa quase nada (o servico e ativado por D-Bus e volta
# sozinho no proximo pedido), mas derruba compartilhamento de tela em
# andamento - por isso o limite fica bem acima do normal, e nao rente a ele.

set -uo pipefail

LIMIT_FDS="${1:-60}"
INTERVAL="${2:-60}"

log() { logger -t xdph-watchdog "$*"; }

# O binario e /usr/lib/xdg-desktop-portal-hyprland (caminho completo na
# cmdline). O proprio watchdog nao casa: a cmdline dele e ".../xdph-watchdog.sh".
xdph_pattern() { echo "/xdg-desktop-portal-hyprland$"; }
xdph_pid() { pgrep -f "$(xdph_pattern)" 2>/dev/null | head -1; }

# Numero de descritores abertos. Vazio = xdph fora do ar (normal: e ativado sob
# demanda pelo D-Bus, entao ficar fora do ar nao e falha e nao exige acao).
xdph_fds() {
	local pid
	pid=$(xdph_pid) || return 1
	[ -n "$pid" ] || return 1
	ls "/proc/${pid}/fd" 2>/dev/null | wc -l
}

# Mata em vez de "systemctl --user restart" de proposito: no estado em que o
# barramento ja esta degradado o systemctl pendura sem retornar (medido em
# 13/08, start ficou 25s sem responder). Matar sempre funciona, e o servico
# volta sozinho na proxima ativacao por D-Bus.
restart_xdph() {
	local pid
	pid=$(xdph_pid)
	[ -n "$pid" ] || return 0
	log "reiniciando xdph (pid ${pid})"
	kill "$pid"
	sleep 2
	kill -9 "$pid" 2>/dev/null
}

self_test() {
	local fails=0

	if [ -n "$(xdph_pid)" ]; then
		local n
		n=$(xdph_fds) || { echo "FALHA: xdph roda mas xdph_fds errou"; fails=1; }
		[[ "$n" =~ ^[0-9]+$ ]] || { echo "FALHA: contagem nao numerica: '$n'"; fails=1; }
		[ "${n:-0}" -gt 0 ] || { echo "FALHA: zero descritores com xdph vivo"; fails=1; }
		echo "ok: xdph vivo, ${n} descritores"
	else
		echo "ok: xdph fora do ar (ativado sob demanda, nada a medir)"
	fi

	# O watchdog nao pode se contar nem casar o portal generico
	# (/usr/lib/xdg-desktop-portal, sem o sufixo -hyprland), senao reiniciaria o
	# processo errado e deixaria o vazamento intacto.
	if pgrep -f "$(xdph_pattern)" | grep -qx "$$"; then
		echo "FALHA: watchdog casando a si mesmo"; fails=1
	else
		echo "ok: watchdog fora da conta"
	fi

	local tmpdir fake
	tmpdir=$(mktemp -d) || { echo "FALHA: mktemp"; return 1; }
	printf '#!/bin/bash\nsleep 5\n' >"${tmpdir}/xdg-desktop-portal"
	chmod +x "${tmpdir}/xdg-desktop-portal"
	"${tmpdir}/xdg-desktop-portal" >/dev/null 2>&1 &
	fake=$!
	sleep 1
	if kill -0 "$fake" 2>/dev/null; then
		if pgrep -f "$(xdph_pattern)" | grep -qx "$fake"; then
			echo "FALHA: casou o portal generico (reiniciaria o processo errado)"; fails=1
		else
			echo "ok: portal generico nao casa"
		fi
	else
		echo "FALHA: processo de teste nao subiu"; fails=1
	fi
	kill "$fake" 2>/dev/null
	rm -rf "${tmpdir}"

	[ "$fails" -eq 0 ] && echo "SELF-TEST OK" || echo "SELF-TEST FALHOU"
	return "$fails"
}

[ "${1:-}" = "--self-test" ] && { LIMIT_FDS=60; self_test; exit $?; }

log "iniciado (limite=${LIMIT_FDS} descritores intervalo=${INTERVAL}s)"
while true; do
	sleep "${INTERVAL}"
	n=$(xdph_fds) || continue
	if [ "${n}" -ge "${LIMIT_FDS}" ]; then
		log "xdph com ${n} descritores (limite ${LIMIT_FDS}) - reiniciando"
		restart_xdph
	fi
done
