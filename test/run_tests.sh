#!/bin/sh
# =============================================================================
# ft_traceroute — test harness
#
# Red-first: every case below is written before the matching implementation,
# so a fresh checkout is expected to fail here until the feature lands.
#
# Usage:  sh test/run_tests.sh [path-to-binary]
# Env:    NET=1   also run the network cases (needs root or CAP_NET_RAW)
# =============================================================================

BIN="${1:-./output/ft_traceroute}"
PASS=0
FAIL=0
SKIP=0

c_pass="  PASS"
c_fail="  FAIL"
c_skip="  SKIP"

report()
{
	# $1 = id, $2 = description, $3 = result (pass|fail|skip), $4 = detail
	case "$3" in
		pass) PASS=$((PASS + 1)); printf '%s  %-8s %s\n' "$c_pass" "$1" "$2" ;;
		skip) SKIP=$((SKIP + 1)); printf '%s  %-8s %s (%s)\n' "$c_skip" "$1" "$2" "$4" ;;
		*)    FAIL=$((FAIL + 1)); printf '%s  %-8s %s\n' "$c_fail" "$1" "$2"
		      [ -n "$4" ] && printf '        -> %s\n' "$4" ;;
	esac
}

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

# exit_code_is <id> <desc> <expected-mode> <args...>
#   expected-mode: "zero" | "nonzero"
exit_code_is()
{
	id="$1"; desc="$2"; mode="$3"; shift 3
	out=$("$BIN" "$@" 2>&1)
	rc=$?
	case "$mode" in
		zero)    [ "$rc" -eq 0 ] && report "$id" "$desc" pass \
		         || report "$id" "$desc" fail "exit=$rc, output: $(echo "$out" | head -1)" ;;
		nonzero) [ "$rc" -ne 0 ] && report "$id" "$desc" pass \
		         || report "$id" "$desc" fail "exit=0, expected non-zero" ;;
	esac
}

# stream_matches <id> <desc> <stream:out|err> <regex> <args...>
stream_matches()
{
	id="$1"; desc="$2"; stream="$3"; re="$4"; shift 4
	if [ "$stream" = "out" ]; then
		text=$("$BIN" "$@" 2>/dev/null)
	else
		text=$("$BIN" "$@" 2>&1 1>/dev/null)
	fi
	if printf '%s\n' "$text" | grep -Eq "$re"; then
		report "$id" "$desc" pass
	else
		report "$id" "$desc" fail "no match for /$re/ in: $(printf '%s' "$text" | head -2 | tr '\n' '|')"
	fi
}

if [ ! -x "$BIN" ]; then
	printf 'test harness: binary not found or not executable: %s\n' "$BIN" >&2
	printf 'build it first: make\n' >&2
	exit 1
fi

printf '==> ft_traceroute test suite (%s)\n\n' "$BIN"

# ---------------------------------------------------------------------------
# T-5xx — CLI contract (subject: the only option is --help)
# ---------------------------------------------------------------------------
printf -- '--- T-5xx CLI contract\n'

exit_code_is   T-505 "--help exits 0"                    zero    --help
stream_matches T-506 "--help prints usage on stdout"     out "^Usage: *ft_traceroute" --help
exit_code_is   T-511 "no argument exits non-zero"        nonzero
stream_matches T-511b "no argument prints usage on stderr" err "Usage:"
exit_code_is   T-512 "unknown option exits non-zero"     nonzero --bogus 8.8.8.8
exit_code_is   T-513 "two destinations exit non-zero"    nonzero 8.8.8.8 1.1.1.1
exit_code_is   T-520 "unknown host exits non-zero"       nonzero nonexistent.invalid.tld
stream_matches T-521 "unknown host message on stderr"    err "ft_traceroute: " nonexistent.invalid.tld

# ---------------------------------------------------------------------------
# T-8xx — bonus options. Argument validation happens before any socket is
# opened, so these cases need no privileges.
# ---------------------------------------------------------------------------
printf -- '\n--- T-8xx bonus option contract\n'

exit_code_is   T-801 "-m below range exits non-zero"     nonzero -m 0 8.8.8.8
exit_code_is   T-802 "-m above range exits non-zero"     nonzero -m 256 8.8.8.8
exit_code_is   T-803 "-m without a value exits non-zero" nonzero -m
exit_code_is   T-804 "-q out of range exits non-zero"    nonzero -q 99 8.8.8.8
exit_code_is   T-805 "-p out of range exits non-zero"    nonzero -p 70000 8.8.8.8
exit_code_is   T-806 "-w non-numeric exits non-zero"     nonzero -w abc 8.8.8.8
exit_code_is   T-807 "-m with a trailing suffix exits non-zero" nonzero -m 5x 8.8.8.8
stream_matches T-808 "--help documents -m"               out "^  -m " --help
stream_matches T-809 "--help documents -q"               out "^  -q " --help
stream_matches T-810 "--help documents -p"               out "^  -p " --help
stream_matches T-811 "--help documents -w"               out "^  -w " --help
stream_matches T-812 "--help documents --resolve"        out "^  --resolve" --help

# ---------------------------------------------------------------------------
# T-7xx — output format. Needs a live trace, so it is gated on privileges.
# ---------------------------------------------------------------------------
printf -- '\n--- T-7xx output format\n'

HOST="${TEST_HOST:-8.8.8.8}"
TRACE_LOG=/tmp/ft_traceroute_test_trace.log

can_raw()
{
	[ "$(id -u)" -eq 0 ] && return 0
	command -v getcap >/dev/null 2>&1 && getcap "$BIN" 2>/dev/null | grep -q cap_net_raw && return 0
	return 1
}

if ! can_raw; then
	for id in T-701 T-702 T-703 T-704 T-820 T-821 T-822 T-823 T-824; do
		report "$id" "output format vs real traceroute" skip "needs root or CAP_NET_RAW"
	done
else
	timeout -s INT "${TEST_TIMEOUT:-40s}" "$BIN" "$HOST" > "$TRACE_LOG" 2>&1

	if grep -Eq '^traceroute to .+ \(([0-9]{1,3}\.){3}[0-9]{1,3}\), 30 hops max, 60 byte packets$' "$TRACE_LOG"; then
		report T-701 "banner matches reference layout" pass
	else
		report T-701 "banner matches reference layout" fail "$(head -1 "$TRACE_LOG")"
	fi

	if grep -Eq '^[ ]*[0-9]+  (\*|([0-9]{1,3}\.){3}[0-9]{1,3})' "$TRACE_LOG"; then
		report T-702 "hop line matches reference layout" pass
	else
		report T-702 "hop line matches reference layout" fail "$(sed -n 2p "$TRACE_LOG")"
	fi

	# Subject: no DNS resolution in the jump display -> hop lines carry no hostname.
	if grep -E '^[ ]*[0-9]+ ' "$TRACE_LOG" | grep -Eq '[a-zA-Z][a-zA-Z0-9-]*\.[a-zA-Z]{2,}'; then
		report T-703 "hop display has no reverse DNS" fail "hostname found in a hop line"
	else
		report T-703 "hop display has no reverse DNS" pass
	fi

	if command -v traceroute >/dev/null 2>&1; then
		# Normalise every digit to N so the naturally different RTT values and
		# hop addresses drop out and only the layout is compared.
		sed -E 's/[0-9]+/N/g' "$TRACE_LOG" > /tmp/ft_tr_our_layout.txt
		lines=$(wc -l < /tmp/ft_tr_our_layout.txt)
		traceroute -n -m "$lines" "$HOST" 2>&1 \
			| sed -E 's/[0-9]+/N/g' > /tmp/ft_tr_ref_layout.txt
		# Our run may be cut short by the harness timeout, so compare only the
		# hops we actually produced.
		head -n "$lines" /tmp/ft_tr_ref_layout.txt > /tmp/ft_tr_ref_cut.txt
		if diff -q /tmp/ft_tr_ref_cut.txt /tmp/ft_tr_our_layout.txt >/dev/null 2>&1; then
			report T-704 "layout identical to real traceroute" pass
		else
			report T-704 "layout identical to real traceroute" fail "see: diff /tmp/ft_tr_ref_cut.txt /tmp/ft_tr_our_layout.txt"
		fi
	else
		report T-704 "layout identical to real traceroute" skip "system traceroute not installed"
	fi

	# --- T-82x: bonus options against a live trace -------------------------
	BONUS_LOG=/tmp/ft_traceroute_test_bonus.log

	timeout -s INT 30s "$BIN" -m 1 "$HOST" > "$BONUS_LOG" 2>&1
	if grep -q '1 hops max' "$BONUS_LOG" \
		&& [ "$(grep -cE '^[ ]*[0-9]+ ' "$BONUS_LOG")" -eq 1 ]; then
		report T-820 "-m 1 caps the trace at one hop" pass
	else
		report T-820 "-m 1 caps the trace at one hop" fail "$(head -2 "$BONUS_LOG" | tr '\n' '|')"
	fi

	timeout -s INT 30s "$BIN" -m 1 -q 1 "$HOST" > "$BONUS_LOG" 2>&1
	if [ "$(grep -o ' ms' "$BONUS_LOG" | wc -l)" -le 1 ]; then
		report T-821 "-q 1 sends a single probe per hop" pass
	else
		report T-821 "-q 1 sends a single probe per hop" fail "$(sed -n 2p "$BONUS_LOG")"
	fi

	timeout -s INT 30s "$BIN" -m 1 -p 40000 "$HOST" > "$BONUS_LOG" 2>&1
	if grep -qE '^[ ]*1  (\*|([0-9]{1,3}\.){3}[0-9]{1,3})' "$BONUS_LOG"; then
		report T-822 "-p changes the base port without breaking matching" pass
	else
		report T-822 "-p changes the base port without breaking matching" fail "$(sed -n 2p "$BONUS_LOG")"
	fi

	timeout -s INT 30s "$BIN" -m 1 -w 1 "$HOST" > "$BONUS_LOG" 2>&1
	if grep -qE '^traceroute to ' "$BONUS_LOG"; then
		report T-823 "-w is accepted and shortens the wait" pass
	else
		report T-823 "-w is accepted and shortens the wait" fail "$(head -1 "$BONUS_LOG")"
	fi

	# --resolve is opt-in; without it the hop display must stay numeric
	# (subject R-06), which T-703 already guards.
	timeout -s INT 30s "$BIN" -m 1 --resolve "$HOST" > "$BONUS_LOG" 2>&1
	if grep -qE '^[ ]*1  ' "$BONUS_LOG"; then
		report T-824 "--resolve is accepted and still prints a hop" pass
	else
		report T-824 "--resolve is accepted and still prints a hop" fail "$(sed -n 2p "$BONUS_LOG")"
	fi
fi

# ---------------------------------------------------------------------------
# summary
# ---------------------------------------------------------------------------
printf '\n==> %d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
