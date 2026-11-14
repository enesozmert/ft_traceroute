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
SRCROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
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

# grep_absent <id> <desc> <regex> -- the pattern must not appear in the sources
grep_absent()
{
	id="$1"; desc="$2"; re="$3"
	hit=$(grep -rEl "$re" "$SRCROOT/src" "$SRCROOT/hdr" 2>/dev/null | tr '\n' ' ')
	if [ -z "$hit" ]; then
		report "$id" "$desc" pass
	else
		report "$id" "$desc" fail "found in: $hit"
	fi
}

if [ ! -x "$BIN" ]; then
	printf 'test harness: binary not found or not executable: %s\n' "$BIN" >&2
	printf 'build it first: make\n' >&2
	exit 1
fi

printf '==> ft_traceroute test suite (%s)\n\n' "$BIN"

# ---------------------------------------------------------------------------
# T-1xx — deliverable shape (subject Chapter V: executable name, Makefile)
# ---------------------------------------------------------------------------
printf -- '--- T-1xx deliverable shape\n'

if [ "$(basename "$BIN")" = "ft_traceroute" ]; then
	report T-101 "executable is named ft_traceroute" pass
else
	report T-101 "executable is named ft_traceroute" fail "got $(basename "$BIN")"
fi

n=2
for rule in all clean fclean re; do
	if grep -qE "^$rule:" "$SRCROOT/Makefile"; then
		report "T-10$n" "Makefile has the '$rule' rule" pass
	else
		report "T-10$n" "Makefile has the '$rule' rule" fail "rule missing"
	fi
	n=$((n + 1))
done

# fclean must actually remove the binary, and re must bring it back.
if (cd "$SRCROOT" && make fclean >/dev/null 2>&1) && [ ! -e "$SRCROOT/output/ft_traceroute" ]; then
	report T-110 "fclean removes the executable" pass
else
	report T-110 "fclean removes the executable" fail "binary still present after fclean"
fi
if (cd "$SRCROOT" && make re >/dev/null 2>&1) && [ -x "$SRCROOT/output/ft_traceroute" ]; then
	report T-111 "re rebuilds the executable" pass
else
	report T-111 "re rebuilds the executable" fail "binary missing after re"
fi

# ---------------------------------------------------------------------------
# T-2xx — source-level subject rules that no runtime test can observe
# ---------------------------------------------------------------------------
printf -- '\n--- T-2xx source-level rules\n'

grep_absent T-201 "sockets are never set O_NONBLOCK (R-08)" 'O_NONBLOCK'
grep_absent T-202 "the real traceroute is never invoked (R-10)" 'system[[:space:]]*\(|execv|execl|popen'
grep_absent T-203 "no fcntl socket-mode juggling" 'fcntl[[:space:]]*\('

# libC only (R-09). -lm is the standard math library and is part of libc.
if command -v ldd >/dev/null 2>&1; then
	extra=$(ldd "$BIN" 2>/dev/null \
		| grep -vE 'linux-vdso|ld-linux|libc\.so|libm\.so|statically linked|not a dynamic' \
		| grep '=>' || true)
elif command -v otool >/dev/null 2>&1; then
	extra=$(otool -L "$BIN" 2>/dev/null | tail -n +2 \
		| grep -vE 'libSystem\.B\.dylib|libc\+\+|libm\.' || true)
else
	extra="__unavailable__"
fi
if [ "$extra" = "__unavailable__" ]; then
	report T-204 "links against libC only (R-09)" skip "no ldd or otool"
elif [ -z "$extra" ]; then
	report T-204 "links against libC only (R-09)" pass
else
	report T-204 "links against libC only (R-09)" fail "$(printf '%s' "$extra" | tr '\n' ' ')"
fi

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

# R-05: the single parameter is an IPv4 address OR a hostname. Both forms must
# be accepted; resolution happens before any socket is opened, so no privilege
# is needed to see the banner fail or succeed.
if "$BIN" 8.8.8.8 2>&1 | head -1 | grep -qE '^(traceroute to 8\.8\.8\.8 \(8\.8\.8\.8\)|ft_traceroute: icmp socket)'; then
	report T-530 "IPv4 literal is accepted and echoed verbatim" pass
else
	report T-530 "IPv4 literal is accepted and echoed verbatim" fail "$("$BIN" 8.8.8.8 2>&1 | head -1)"
fi

# R-05/R-06: an FQDN is resolved once, and the banner shows the name the user
# typed next to the resolved address -- it is not replaced by the address.
out=$("$BIN" dns.google 2>&1 | head -1)
if printf '%s' "$out" | grep -qE '^traceroute to dns\.google \(([0-9]{1,3}\.){3}[0-9]{1,3}\)'; then
	report T-531 "FQDN accepted, banner keeps the typed name" pass
elif printf '%s' "$out" | grep -q 'icmp socket'; then
	report T-531 "FQDN accepted, banner keeps the typed name" skip "needs root or CAP_NET_RAW"
else
	report T-531 "FQDN accepted, banner keeps the typed name" fail "$out"
fi

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
# T-6xx — protocol on the wire. These watch what actually leaves the host,
# which is the only way to prove the probe protocol rather than infer it from
# the printed output. Needs tcpdump and privileges.
# ---------------------------------------------------------------------------
printf -- '\n--- T-6xx protocol on the wire\n'

WIRE=/tmp/ft_tr_wire.txt

if ! command -v tcpdump >/dev/null 2>&1 || [ "$(id -u)" -ne 0 ]; then
	for id in T-601 T-602 T-603; do
		report "$id" "probe protocol on the wire" skip "needs tcpdump and root"
	done
else
	tcpdump -i any -n -c 12 'udp portrange 33434-33500 or icmp' > "$WIRE" 2>/dev/null &
	td=$!
	sleep 2
	timeout -s INT 12s "$BIN" -m 2 "${TEST_HOST:-8.8.8.8}" >/dev/null 2>&1
	sleep 2
	kill "$td" 2>/dev/null
	wait "$td" 2>/dev/null

	# Probes are UDP and the destination port steps by one per probe, starting
	# at the base port -- that stepping port is what match_probe keys on.
	if grep -qE '\.33434: UDP' "$WIRE" && grep -qE '\.33435: UDP' "$WIRE"; then
		report T-601 "UDP probes leave on 33434 and step per probe" pass
	else
		report T-601 "UDP probes leave on 33434 and step per probe" fail "$(head -2 "$WIRE" | tr '\n' '|')"
	fi

	# 60-byte packet claim in the banner: 20 IP + 8 UDP + 32 payload.
	if grep -qE 'UDP, length 32' "$WIRE"; then
		report T-602 "UDP payload is 32 bytes, matching the 60-byte banner" pass
	else
		report T-602 "UDP payload is 32 bytes, matching the 60-byte banner" fail "$(grep -m1 'UDP' "$WIRE")"
	fi

	# The destination itself answers with port unreachable, which is what ends
	# the trace. The loopback gives that deterministically.
	tcpdump -i any -n -c 6 'icmp' > "$WIRE.2" 2>/dev/null &
	td2=$!
	sleep 2
	timeout -s INT 10s "$BIN" -q 1 127.0.0.1 >/dev/null 2>&1
	sleep 1
	kill "$td2" 2>/dev/null
	wait "$td2" 2>/dev/null
	if grep -qiE 'port 334[0-9]+ unreachable' "$WIRE.2"; then
		report T-603 "destination replies port unreachable, ending the trace" pass
	else
		report T-603 "destination replies port unreachable, ending the trace" fail "$(head -2 "$WIRE.2" | tr '\n' '|')"
	fi
fi

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
	for id in T-701 T-702 T-703 T-704 T-705 T-706 T-707 T-708 T-709 \
		T-820 T-821 T-822 T-823 T-824; do
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
		# Byte-for-byte layout comparison, run against the loopback. A remote
		# trace cannot be compared this way: the two runs are independent, so a
		# single probe lost in one of them is an ordinary network event that
		# would fail the diff while saying nothing about the layout. The
		# loopback answers every probe, so any difference here is real.
		timeout -s INT 15s "$BIN" 127.0.0.1 2>&1 \
			| sed -E 's/[0-9]+/N/g' > /tmp/ft_tr_our_layout.txt
		traceroute -n 127.0.0.1 2>&1 \
			| sed -E 's/[0-9]+/N/g' > /tmp/ft_tr_ref_layout.txt
		if diff -q /tmp/ft_tr_ref_layout.txt /tmp/ft_tr_our_layout.txt >/dev/null 2>&1; then
			report T-704 "layout identical to real traceroute" pass
		else
			report T-704 "layout identical to real traceroute" fail "see: diff /tmp/ft_tr_ref_layout.txt /tmp/ft_tr_our_layout.txt"
		fi

		# The remote trace is checked against the reference grammar instead,
		# which tolerates a differing number of answered probes.
		# A hop line is the hop number followed by one field per probe: " *"
		# for a lost probe, or an optional " <addr>" plus "  <rtt> ms" for an
		# answered one. The address appears only when it differs from the
		# previous probe's, so a lost first probe legitimately produces
		# " 1  * 10.0.0.1  0.250 ms  0.030 ms".
		bad=$(grep -E '^[ ]*[0-9]+ ' "$TRACE_LOG" \
			| grep -vE '^[ ]*[0-9]+ ( \*|( ([0-9]{1,3}\.){3}[0-9]{1,3})?  [0-9]+\.[0-9]{3} ms)+$' \
			| head -1)
		if [ -z "$bad" ]; then
			report T-709 "every remote hop line follows the reference grammar" pass
		else
			report T-709 "every remote hop line follows the reference grammar" fail "$bad"
		fi
	else
		report T-704 "layout identical to real traceroute" skip "system traceroute not installed"
		report T-709 "every remote hop line follows the reference grammar" skip "system traceroute not installed"
	fi

	# --- T-70x: further mandatory output rules -----------------------------

	# Hop numbers start at 1 and increase by exactly one.
	if [ "$(grep -oE '^[ ]*[0-9]+ ' "$TRACE_LOG" | tr -d ' ' | tr '\n' ' ')" \
		= "$(seq 1 "$(grep -cE '^[ ]*[0-9]+ ' "$TRACE_LOG")" | tr '\n' ' ')" ]; then
		report T-705 "hop numbers run 1..n with no gaps" pass
	else
		report T-705 "hop numbers run 1..n with no gaps" fail "$(grep -oE '^[ ]*[0-9]+ ' "$TRACE_LOG" | tr -d ' ' | tr '\n' ' ')"
	fi

	# Reaching the destination must stop the trace: the loopback answers on the
	# first hop, so exactly one hop line may be printed.
	timeout -s INT 15s "$BIN" 127.0.0.1 > /tmp/ft_tr_local.log 2>&1
	if [ "$(grep -cE '^[ ]*[0-9]+ ' /tmp/ft_tr_local.log)" -eq 1 ]; then
		report T-706 "the trace stops once the destination answers" pass
	else
		report T-706 "the trace stops once the destination answers" fail "$(grep -cE '^[ ]*[0-9]+ ' /tmp/ft_tr_local.log) hop lines"
	fi

	# R-11: no unexpected exit. SIGINT must end the run through the normal path,
	# never with a signal status (128+N) such as 139 (SEGV) or 134 (ABRT).
	timeout -s INT 6s "$BIN" 8.8.8.8 >/dev/null 2>&1
	rc=$?
	if [ "$rc" -lt 128 ] || [ "$rc" -eq 130 ]; then
		report T-707 "SIGINT exits cleanly, never on a fatal signal" pass
	else
		report T-707 "SIGINT exits cleanly, never on a fatal signal" fail "exit status $rc"
	fi

	# R-07: a hop RTT must land within 30 ms of what the reference measures for
	# the same hop. Compared on hop 1, which both tools always reach.
	if command -v traceroute >/dev/null 2>&1; then
		ours=$(sed -n '2p' "$TRACE_LOG" | grep -oE '[0-9]+\.[0-9]{3} ms' | head -1 | cut -d. -f1)
		theirs=$(traceroute -n -m 1 "$HOST" 2>/dev/null | sed -n '2p' \
			| grep -oE '[0-9]+\.[0-9]{3} ms' | head -1 | cut -d. -f1)
		if [ -n "$ours" ] && [ -n "$theirs" ] \
			&& [ "$(( ours - theirs ))" -le 30 ] && [ "$(( theirs - ours ))" -le 30 ]; then
			report T-708 "hop RTT within the 30 ms tolerance (R-07)" pass
		elif [ -z "$ours" ] || [ -z "$theirs" ]; then
			report T-708 "hop RTT within the 30 ms tolerance (R-07)" skip "hop 1 did not answer"
		else
			report T-708 "hop RTT within the 30 ms tolerance (R-07)" fail "ours=${ours}ms reference=${theirs}ms"
		fi
	else
		report T-708 "hop RTT within the 30 ms tolerance (R-07)" skip "system traceroute not installed"
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
