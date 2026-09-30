#!/usr/bin/env bash
# Watchdog da barra (quickshell).
#
# Substitui o antigo cap de cgroup (systemd-run --scope -p MemoryMax=2G).
# Motivo da troca: o cap valia pro cgroup inteiro, e app aberto pela barra nasce
# como filho do qs -> herda o cgroup -> contava no limite. Em 2026-07-20 onze
# xfreerdp3 pendurados (957MB) estouraram os 2G, o OOM killer matou o slack e o
# systemd derrubou o scope inteiro (OOMPolicy=stop), levando a barra junto.
#
# Este watchdog mede o RSS DO PROCESSO qs, nao do grupo. App aberto pela barra
# nao entra na conta. Soma todos os qs -c $CONFIG porque o modo de falha
# conhecido e a barra DUPLICAR (crash do PipeWire ao cair o fone BT) - dois
# processos de 1.5G cada passariam despercebidos se olhasse so o primeiro.

set -uo pipefail

CONFIG="${1:-ii}"
LIMIT_MB="${2:-2500}"
INTERVAL="${3:-60}"

log() { logger -t qs-watchdog "$*"; }

# PIDs da barra. -f casa a cmdline inteira.
# A alternancia (qs|quickshell) e OBRIGATORIA: /usr/bin/qs e symlink pra
# /usr/bin/quickshell, e a barra do boot aparece como "/usr/bin/quickshell -c ii".
# O padrao "qs -c ii" NAO casa essa forma (verificado: "quickshell -c ii" nao
# contem a substring "qs -c ii") - o watchdog ficaria cego justamente pra barra
# que ele existe pra vigiar. Coberto pelo self-test.
# O proprio watchdog nao casa: a cmdline dele e ".../qs-watchdog.sh ii" (sem " -c ").
# Depois de um crash o quickshell reexecuta a si mesmo e a cmdline vira so
# "/usr/bin/quickshell", sem "-c ii". O padrao aceita essa forma quando a
# config e a padrao "ii"; "qs -n -c hangar" continua fora.
qs_pattern() {
	if [ "${CONFIG}" = "ii" ]; then
		echo "(^|/)(qs|quickshell)( -c ii)?$"
	else
		echo "(^|/)(qs|quickshell) -c ${CONFIG}$"
	fi
}
qs_pids() { pgrep -f "$(qs_pattern)" 2>/dev/null; }

# Soma VmRSS de todos os processos da barra, em MB. Vazio = barra fora do ar.
qs_rss_mb() {
	local pid rss total=0 found=0
	for pid in $(qs_pids); do
		rss=$(awk '/^VmRSS:/{print $2}' "/proc/${pid}/status" 2>/dev/null) || continue
		[ -n "$rss" ] || continue
		total=$((total + rss))
		found=1
	done
	[ "$found" -eq 1 ] || return 1
	echo $((total / 1024))
}

restart_bar() {
	log "reiniciando barra"
	pkill -f "$(qs_pattern)"
	sleep 2
	pkill -9 -f "$(qs_pattern)" 2>/dev/null
	setsid qs -c "${CONFIG}" >/dev/null 2>&1 &
}

self_test() {
	local fails=0
	# qs_rss_mb devolve numero quando a barra roda, e falha quando nao ha match.
	if qs_pids >/dev/null; then
		local mb
		mb=$(qs_rss_mb) || { echo "FALHA: qs roda mas qs_rss_mb errou"; fails=1; }
		[[ "$mb" =~ ^[0-9]+$ ]] || { echo "FALHA: RSS nao numerico: '$mb'"; fails=1; }
		[ "${mb:-0}" -gt 0 ] || { echo "FALHA: RSS zero com barra viva"; fails=1; }
		echo "ok: barra viva, RSS=${mb}MB"
	else
		echo "ok: barra fora do ar (nada a medir)"
	fi
	# Um CONFIG inexistente nao pode casar nada nem retornar sucesso.
	if CONFIG="__nao_existe__" qs_rss_mb >/dev/null 2>&1; then
		echo "FALHA: casou config inexistente"; fails=1
	else
		echo "ok: config inexistente nao casa"
	fi
	# App qualquer nao pode entrar na conta da barra.
	if qs_pids | grep -q "^$$\$"; then
		echo "FALHA: watchdog contando a si mesmo"; fails=1
	else
		echo "ok: watchdog fora da conta"
	fi
	# REGRESSAO: a barra do boot aparece como "quickshell -c ii" (qs e symlink
	# pra quickshell). O padrao TEM que casar as duas formas, senao o watchdog
	# fica cego pra barra do boot - que e o caso que mais importa.
	local tmpdir fake
	tmpdir=$(mktemp -d) || { echo "FALHA: mktemp"; return 1; }
	printf '#!/bin/bash\nsleep 5\n' >"${tmpdir}/quickshell"
	chmod +x "${tmpdir}/quickshell"
	"${tmpdir}/quickshell" -c "${CONFIG}" >/dev/null 2>&1 &
	fake=$!
	sleep 1
	if kill -0 "$fake" 2>/dev/null; then
		if qs_pids | grep -qx "$fake"; then
			echo "ok: forma 'quickshell -c ${CONFIG}' e detectada"
		else
			echo "FALHA: forma 'quickshell -c ${CONFIG}' NAO detectada"; fails=1
		fi
	else
		echo "FALHA: processo de teste nao subiu"; fails=1
	fi
	kill "$fake" 2>/dev/null
	rm -rf "${tmpdir}"
	[ "$fails" -eq 0 ] && echo "SELF-TEST OK" || echo "SELF-TEST FALHOU"
	return "$fails"
}

[ "${1:-}" = "--self-test" ] && { CONFIG=ii; self_test; exit $?; }

log "iniciado (config=${CONFIG} limite=${LIMIT_MB}MB intervalo=${INTERVAL}s)"
misses=0
while true; do
	sleep "${INTERVAL}"
	if ! mb=$(qs_rss_mb); then
		# Barra fora do ar. 3 ciclos seguidos (3min) sem processo = morreu de
		# verdade (crash-handler do qs desistiu, ex: 5 segfaults no boot de
		# 22/07). Espera 3 ciclos pra nao brigar com restart manual do usuario.
		misses=$((misses + 1))
		if [ "${misses}" -ge 3 ]; then
			log "barra fora do ar ha ${misses} ciclos - relancando"
			restart_bar
			misses=0
		fi
		continue
	fi
	misses=0
	if [ "${mb}" -ge "${LIMIT_MB}" ]; then
		log "barra em ${mb}MB (limite ${LIMIT_MB}MB) - reiniciando"
		restart_bar
	fi
done
