#!/bin/sh
# =============================================================================
# ft_traceroute — sync the working tree into the VM and run the full suite
# there, as root, so nothing is skipped for want of CAP_NET_RAW.
#
#   sh vm/run-tests.sh            sync the tree into the VM and run the suite
#   sh vm/run-tests.sh gates      also run norminette, strict build, valgrind
#   sh vm/run-tests.sh sync       only copy the tree in, run nothing
# =============================================================================

set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/common.sh"

VM_DIR="${VM_DIR:-$(vm_default_dir)}"
SSH_PORT="${SSH_PORT:-2222}"
REPO="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

[ -f "$VM_DIR/id_vm" ] || {
	echo "no VM key at $VM_DIR/id_vm -- run 'sh vm/create-vm.sh' first" >&2
	exit 1
}

SSH="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
	-o LogLevel=ERROR -i $VM_DIR/id_vm -p $SSH_PORT tester@127.0.0.1"

echo "==> syncing $REPO -> VM:~/ft_traceroute"
rsync -a --delete \
	--exclude obj --exclude output --exclude build --exclude .git \
	-e "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
		-o LogLevel=ERROR -i $VM_DIR/id_vm -p $SSH_PORT" \
	"$REPO/" tester@127.0.0.1:~/ft_traceroute/

if [ "${1:-}" = "sync" ]; then
	echo "==> synced. The project is at ~/ft_traceroute inside the VM:"
	echo "     ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \\"
	echo "         -o LogLevel=ERROR -i $VM_DIR/id_vm -p $SSH_PORT tester@127.0.0.1"
	echo "     cd ~/ft_traceroute && make && sudo ./output/ft_traceroute 8.8.8.8"
	exit 0
fi

echo "==> building and testing in the VM"
# A previous `sudo make` leaves obj/ and output/ owned by root, and the next
# ordinary `make fclean` then dies with "Permission denied". Take the tree back
# before building; sudo is passwordless in this VM.
$SSH 'sudo chown -R "$(id -un)":"$(id -gn)" ~/ft_traceroute 2>/dev/null; true'
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
