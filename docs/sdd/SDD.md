# SDD — ft_traceroute Software Design Document

> Subject: [`docs/main/en.subject.pdf`](../main/en.subject.pdf) (Ecole 42, ft_traceroute v5.0)
> Reference behaviour: Debian `traceroute(8)` (LBL / Dmitry Butskoy implementation)
> Status: v1.0 — written before the first line of implementation (design-first, test-first)

---

## 1. Scope

### 1.1 Mandatory requirements (subject, Chapter V)

| ID | Requirement | Design response |
|----|-------------|-----------------|
| R-01 | Executable named `ft_traceroute` | `Makefile` builds `output/ft_traceroute`, binary name exact |
| R-02 | C + Makefile with the usual rules | `all clean fclean re` present, plus quality targets |
| R-03 | Only option to manage: `--help` | `parse_args` accepts `--help` and nothing else |
| R-04 | One IPv4 address **or** hostname parameter | exactly one positional argument, more is an error |
| R-05 | Manage FQDN, but **no DNS resolution in the hop display** | forward resolution once at startup; hop lines print the raw IP, never `getnameinfo` |
| R-06 | ±30 ms tolerance per hop | RTT measured with `gettimeofday` around each probe |
| R-07 | Sockets must **not** be `O_NONBLOCK` | both sockets stay blocking; waiting is done with `select(2)` |
| R-08 | libC only | no third-party dependency; `-lm` only for the standard math library |
| R-09 | Never call the real `traceroute` | no `system`, `exec*` or `popen` anywhere |
| R-10 | No unexpected exit (segfault, bus error, double free) | every allocation checked, single owner per buffer, no handler-side `printf` |
| R-11 | Same indentation as the real traceroute | `make diff-ref` diffs a digit-normalised copy of both outputs |

### 1.2 Out of scope for the mandatory part

IPv6, reverse DNS of hops, and the option flags. These are bonus material, and the subject
gates the bonus behind a perfect mandatory part, so they were implemented only after every
mandatory gate was green — see §9.

---

## 2. Protocol decision

The subject never names a probe protocol. Two lines in it pin the answer:

1. *"The result will have the same indentation as the real traceroute"* plus the `man traceroute`
   reference in Chapter III. The default mode of `traceroute(8)` on Linux is **UDP probes**.
2. The bonus list offers `-p` (destination port) but never `-I`. A port only exists for a UDP
   probe, and ICMP mode is listed nowhere — so ICMP mode cannot be the mandatory default.

**Decision: UDP probes, raw ICMP listener.**

```
send path   socket(AF_INET, SOCK_DGRAM, 0)        -> sendto(dest, port 33434 + n)
            setsockopt(IPPROTO_IP, IP_TTL, ttl)      TTL incremented per hop
recv path   socket(AF_INET, SOCK_RAW, IPPROTO_ICMP) -> recvfrom
```

Replies that matter:

| ICMP type | code | meaning | loop action |
|-----------|------|---------|-------------|
| 11 (Time Exceeded) | 0 | an intermediate router dropped the probe | record hop, continue |
| 3 (Destination Unreachable) | 3 (Port Unreachable) | the destination itself answered | record hop, **stop** |
| 3 | 0,1,2,9,10,13 | administratively filtered / unreachable | record hop with an annotation, continue |

A raw ICMP socket receives *every* ICMP packet on the host, so each datagram must be matched
to one of our own probes. The ICMP error payload carries the first 8 bytes of the offending
datagram — i.e. the original IP header plus the original UDP header. `match_probe` reads the
destination port out of that embedded UDP header and compares it to the port of the probe we
are waiting for. Nothing else is a reliable key.

```
  recv_buf: [ outer IP ][ ICMP 8B ][ inner IP ][ inner UDP 8B ]
                                                      ^
                                           dest port == 33434 + probe_index
```

---

## 3. Module decomposition

One public function per source file (norm rule), no module reaching into another's internals.

```
main.c                 argv -> parse_args -> trace_init -> trace_loop -> trace_cleanup
parse_args.c           --help only, one positional destination, exit codes
print_usage.c          usage text on stdout (--help) or stderr (misuse)
resolve_hostname.c     getaddrinfo, AF_INET, first result wins

trace_init.c           owns the whole t_traceroute lifecycle entry
create_sockets.c       UDP send socket + raw ICMP recv socket
create_payload.c       32-byte UDP payload (60 - 20 IP - 8 UDP)
create_target.c        sockaddr_in for the resolved address

trace_loop.c           for ttl in 1..max: for probe in 1..3: send, wait, receive
send_probe.c           IP_TTL setsockopt + sendto, stamps sent_at
wait_reply.c           select() on the raw socket with the remaining deadline
recv_reply.c           recvfrom, classify the ICMP type/code, fill t_probe
match_probe.c          inner IP + UDP parse, port comparison

print_banner.c         "traceroute to HOST (IP), N hops max, M byte packets"
print_hop.c            one line per hop, "*" per lost probe, no reverse DNS

checksum.c             RFC 1071 (kept for the bonus ICMP probe mode)
compute_elapsed_ms.c   timeval helpers: elapsed, deadline add, remaining
interrupt_handler.c    sets g_interrupted only — async-signal-safe
trace_cleanup.c        closes both sockets, frees the payload
```

### 3.1 Why not the ft_ping layering

`ft_ping` puts `ping_loop()` inside `create_socket()`, so the function that opens a socket also
runs the program and never returns — `free_ping()` in `main` is dead code. ft_traceroute keeps
the three phases separate and returns through all of them:

```
trace_init(&tr, dest)  ->  trace_loop(&tr)  ->  trace_cleanup(&tr)  ->  return status
```

`ft_ping` also calls `printf` and `exit` from inside the `SIGINT` handler, which is not
async-signal-safe. Here the handler writes `g_interrupted` (a `volatile sig_atomic_t`) and
nothing else; `trace_loop` checks it between probes and returns normally.

---

## 4. Data model

```c
t_probe       state (TIMEOUT|TRANSIT|FINAL), sent_at, rtt, from_addr, from_str
t_options     max_hops=30, nprobes=3, base_port=33434, packet_len=60, probe_timeout=5
t_traceroute  send_fd, recv_fd, dest_arg, dest_ip, target, opt, probes[3],
              payload, payload_len, ident, reached
```

`t_traceroute` is a single stack object in `main`. There is no global state apart from
`g_interrupted`, so there is no ownership question and nothing to leak on an early return.

Wire structs (`t_iphdr`, `t_icmphdr`, `t_udphdr`) are declared locally rather than taken from
`<netinet/ip.h>`, because Linux (`struct iphdr`) and BSD/macOS (`struct ip`) disagree on names
and bitfield order. The local structs follow RFC 791 / 792 / 768 byte-for-byte, so the same
parsing code is correct on both.

---

## 5. Output contract

```
traceroute to google.com (142.250.187.78), 30 hops max, 60 byte packets
 1  192.168.1.1  0.431 ms  0.389 ms  0.364 ms
 2  * * *
 3  10.0.0.1  8.112 ms  8.044 ms  8.230 ms
```

Rules taken from the reference implementation:

- Banner prints the host **as the user typed it**, then the resolved IP in parentheses.
- Hop number is `%2d`, followed by two spaces.
- Within one hop, an address is printed only when it differs from the previous probe's address.
- Each RTT is `%.3f ms`, separated from the previous field by two spaces.
- A probe with no reply prints `*`, separated by a single space.
- The hop display never performs reverse DNS (subject R-05), so it matches `traceroute -n`.

Byte-exact confirmation is not assumed — `make diff-ref` normalises every digit to `N` in both
our output and the real `traceroute` output and diffs the result, so any layout drift shows up
as a diff hunk while the naturally different RTT values do not.

---

## 6. Error handling

| Condition | Channel | Exit |
|-----------|---------|------|
| `--help` | stdout | 0 |
| no argument | stderr, usage | 1 |
| unknown option | stderr, usage | 1 |
| more than one destination | stderr, usage | 1 |
| unresolvable host | stderr `ft_traceroute: unknown host` | 1 |
| raw socket denied (no CAP_NET_RAW) | stderr with `strerror(errno)` | 1 |
| `sendto` fails mid-run | probe counted as lost, loop continues | — |
| SIGINT | loop returns, sockets closed, memory freed | 0 |

No code path calls `exit()` from inside a helper: every function returns a status and `main`
owns the single exit point. That keeps valgrind's leak report meaningful on every path.

---

## 7. Test strategy — red first

No implementation file is written before a test for it fails. Test IDs:

| ID | Layer | Assertion |
|----|-------|-----------|
| T-505 | CLI | `--help` prints usage, exit 0 |
| T-511 | CLI | no argument → usage on stderr, exit ≠ 0 |
| T-512 | CLI | unknown option → exit ≠ 0 |
| T-513 | CLI | two destinations → exit ≠ 0 |
| T-520 | CLI | unknown host → error on stderr, exit ≠ 0 |
| T-601 | protocol | UDP probe leaves the host on port 33434 (tcpdump) |
| T-602 | protocol | TTL 1 reply is ICMP type 11 |
| T-603 | protocol | destination reply is ICMP type 3 code 3 and stops the loop |
| T-701 | format | banner matches `^traceroute to .* \(.*\), 30 hops max, 60 byte packets$` |
| T-702 | format | hop line matches `^[ ]*[0-9]+  (\*|[0-9.]+)` |
| T-703 | format | no hop line contains a hostname (no reverse DNS) |
| T-704 | format | digit-normalised layout equals the real `traceroute` layout |

`test/cli.sh` and `test/format.sh` run from `make test`; the network-dependent cases run from
`make test-net` inside the Docker container, where CAP_NET_RAW is available.

---

## 9. Bonus design (implemented after the mandatory gates were green)

Five bonus items, which is the subject's maximum: `-m`, `-q`, `-p`, `-w` and `--resolve`.

### 9.1 Option parsing

`options_init` fills the mandatory defaults, `parse_option` then moves individual values.
With no flag the program is byte-for-byte the mandatory program, which is what keeps R-04
intact: an unrecognised `-` argument is still an error.

Values are converted with `strtol` and the whole string must be consumed, so `-m 5x` is
rejected rather than silently read as 5. Each flag carries its own range (`-m` 1–255,
`-q` 1–`TR_MAX_PROBES`, `-p` 1–65535, `-w` 1–60), and `-q`'s ceiling is the size of the
probe array, so a large `-q` cannot overrun it.

### 9.2 Reverse DNS — why `--resolve` and not `-n`

The real traceroute resolves by default and turns it off with `-n`. The subject forbids DNS
resolution in the jump display, so the default here is the opposite: numeric always, and the
lookup sits behind a flag that has to be asked for. `resolve_hops` returns immediately when
the flag is absent, so `getnameinfo` is never reached on the mandatory path — T-703 guards
that behaviourally rather than by grepping for the symbol.

A failed lookup leaves `host_str` empty and `print_hop` falls back to the raw address, so an
address with no PTR record degrades to the mandatory rendering instead of printing nothing.
`NI_NAMEREQD` is passed so a lookup that would otherwise hand back the address as a string
is reported as a failure.

---

## 8. AI usage transparency (subject Chapter IV)

The architecture above, the protocol decision in §2 and the test matrix in §7 were produced by
the author working with an AI assistant. Every design decision in this document is defended by
the author at the evaluation; the AI's first proposals were reviewed and changed where they
were wrong — the probe-matching key in §2 and the layering fix in §3.1 are both corrections
made against an earlier draft.
