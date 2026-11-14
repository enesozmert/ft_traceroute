#!/bin/sh
# =============================================================================
# ft_traceroute — sync the working tree into the VM and run the full suite
# there, as root, so nothing is skipped for want of CAP_NET_RAW.
#
#   sh vm/run-tests.sh            run the test suite
#   sh vm/run-tests.sh gates      also run norminette, strict build, valgrind
# =============================================================================

set -eu

VM_DIR="${VM_DIR:-$HOME/vm/ft_traceroute}"
SSH_PORT="${SSH_PORT:-2222}"
REPO="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

SSH="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
	-o LogLevel=ERROR -i $VM_DIR/id_vm -p $SSH_PORT tester@127.0.0.1"

echo "==> syncing $REPO -> VM:~/ft_traceroute"
rsync -a --delete \
	--exclude obj --exclude output --exclude build --exclude .git \
	-e "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
		-o LogLevel=ERROR -i $VM_DIR/id_vm -p $SSH_PORT" \
	"$REPO/" tester@127.0.0.1:~/ft_traceroute/

echo "==> building and testing in the VM"
$SSH 'cd ~/ft_traceroute && make re >/dev/null && sudo TEST_TIMEOUT=90s sh test/run_tests.sh output/ft_traceroute'

if [ "${1:-}" = "gates" ]; then
	echo "==> quality gates in the VM"
	$SSH 'cd ~/ft_traceroute && \
		echo "--- norminette"; norminette src hdr | grep -c ": OK!" | sed "s/^/files OK: /"; \
		norminette src hdr | grep -c "^Error" | sed "s/^/errors: /"; \
		echo "--- strict"; make re CFLAGS="-Wall -Wextra -Werror -std=c11 -g -Ihdr -Wpedantic -Wshadow -Wconversion -Wcast-align -Wstrict-prototypes" >/dev/null 2>/tmp/s.txt; \
		echo "rc=$? warnings=$(grep -cE "warning:|error:" /tmp/s.txt)"; \
		echo "--- valgrind"; make re >/dev/null 2>&1; \
		for a in "--help" "nonexistent.invalid.tld" "" "-m 0 1.1.1.1"; do \
			printf "%-26s " "[$a]"; \
			valgrind --leak-check=full --error-exitcode=1 ./output/ft_traceroute $a >/dev/null 2>/tmp/v.txt; \
			grep -oE "ERROR SUMMARY: [0-9]+ errors" /tmp/v.txt; \
		done; \
		echo "--- diff-ref"; sudo make diff-ref DIFF_HOST=127.0.0.1 2>&1 | tail -1'
fi
