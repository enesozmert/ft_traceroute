#!/bin/sh
# =============================================================================
# ft_traceroute — headless VirtualBox VM provisioner
#
# Builds the Linux VM the project is verified in: Debian 13 (trixie) arm64,
# kernel >= 4.0 as the subject requires, no GUI at any step. The disk is the
# official Debian cloud image converted to VDI; the user and the toolchain are
# provisioned with cloud-init from a generated seed ISO.
#
#   sh vm/create-vm.sh            build and boot the VM
#   sh vm/create-vm.sh destroy    remove the VM and its disk
#
# Then:
#   ssh -i ~/vm/ft_traceroute/id_vm -p 2222 tester@127.0.0.1
#
# Runs on macOS and on Linux. Host requirements:
#   VirtualBox >= 7.0, qemu-img, curl, ssh-keygen, and an ISO builder --
#   hdiutil on macOS, genisoimage / mkisofs / xorriso on Linux.
#     Debian/Ubuntu:  sudo apt install virtualbox qemu-utils genisoimage
#     Fedora:         sudo dnf install VirtualBox qemu-img xorriso
# The guest architecture follows the host; override with ARCH=amd64|arm64.
# =============================================================================

set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/common.sh"

VM_NAME="${VM_NAME:-ft-tr-vm}"
# goinfre when it exists (home quotas do not fit a 1.3 GB disk), else ~/vm.
VM_DIR="${VM_DIR:-$(vm_default_dir)}"
SSH_PORT="${SSH_PORT:-2222}"
MEMORY="${MEMORY:-4096}"
CPUS="${CPUS:-4}"
DISK_MB="${DISK_MB:-12288}"

case "$(uname -m)" in
	arm64|aarch64) ARCH="${ARCH:-arm64}"; VB_ARCH=arm;  OSTYPE_ID=Debian_arm64 ;;
	*)             ARCH="${ARCH:-amd64}"; VB_ARCH=x86;  OSTYPE_ID=Debian_64 ;;
esac

IMAGE_URL="https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-$ARCH.qcow2"

VBM=VBoxManage
[ -x /Applications/VirtualBox.app/Contents/MacOS/VBoxManage ] \
	&& VBM=/Applications/VirtualBox.app/Contents/MacOS/VBoxManage

# ---------------------------------------------------------------------------
destroy()
{
	"$VBM" controlvm "$VM_NAME" poweroff >/dev/null 2>&1 || true
	"$VBM" unregistervm "$VM_NAME" --delete >/dev/null 2>&1 || true
	rm -rf "$VM_DIR/vbox" "$VM_DIR/disk.vdi" "$VM_DIR/seed.iso" "$VM_DIR/seed"
	# The next VM on this port will have a different host key.
	if [ -f "$HOME/.ssh/known_hosts" ]; then
		ssh-keygen -q -f "$HOME/.ssh/known_hosts" -R "[127.0.0.1]:$SSH_PORT" \
			>/dev/null 2>&1 || true
		rm -f "$HOME/.ssh/known_hosts.old"
	fi
	echo "VM '$VM_NAME' removed."
}

if [ "${1:-}" = "destroy" ]; then
	destroy
	exit 0
fi

# ---------------------------------------------------------------------------
# 1. host tooling
# ---------------------------------------------------------------------------
for t in "$VBM" qemu-img curl ssh-keygen; do
	command -v "$t" >/dev/null 2>&1 || { echo "missing: $t" >&2; exit 1; }
done

mkdir -p "$VM_DIR"
cd "$VM_DIR"

echo "==> VM directory: $VM_DIR"
case "$VM_DIR" in
	*goinfre*) : ;;
	*) echo "    (no goinfre found; set VM_DIR=... if this partition is small)" ;;
esac

# The image plus the grown VDI need roughly 2 GB.
FREE_MB=$(df -Pm "$VM_DIR" 2>/dev/null | awk 'NR==2 {print $4}')
if [ -n "${FREE_MB:-}" ] && [ "$FREE_MB" -lt 2500 ]; then
	echo "    warning: only ${FREE_MB} MB free here; ~2500 MB recommended" >&2
fi

# ---------------------------------------------------------------------------
# 2. disk — official Debian cloud image, converted to VDI and grown
# ---------------------------------------------------------------------------
if [ ! -f "debian-13-$ARCH.qcow2" ]; then
	echo "==> downloading $IMAGE_URL"
	echo "    into $VM_DIR"
	vm_download "$IMAGE_URL" "debian-13-$ARCH.qcow2"
fi

if [ ! -f disk.vdi ]; then
	# Grow first, convert second. The cloud image is 3 GB, which the toolchain
	# does not fit into. qemu-img cannot resize a VDI -- "Image format driver
	# does not support resize" -- and VBoxManage modifymedium needs the file in
	# VirtualBox's media registry, failing with "Failed to create medium lock
	# list" when it is not. Resizing the qcow2 avoids both: the converted VDI
	# is dynamic, so it still only takes the space actually used, and
	# cloud-init grows the partition and filesystem on first boot.
	echo "==> resizing the image to ${DISK_MB} MB"
	qemu-img resize "debian-13-$ARCH.qcow2" "${DISK_MB}M" >/dev/null 2>&1 \
		|| echo "    (already that size or larger)"

	echo "==> converting to VDI"
	qemu-img convert -f qcow2 -O vdi "debian-13-$ARCH.qcow2" disk.vdi

	echo "    $(qemu-img info disk.vdi | grep 'virtual size')"
fi

# ---------------------------------------------------------------------------
# 3. ssh key + cloud-init seed ISO
# ---------------------------------------------------------------------------
[ -f id_vm ] || ssh-keygen -t ed25519 -N "" -f id_vm -C ft_traceroute_vm >/dev/null

mkdir -p seed
cat > seed/meta-data <<EOF
instance-id: ft-tr-01
local-hostname: $VM_NAME
EOF

cat > seed/user-data <<EOF
#cloud-config
hostname: $VM_NAME
users:
  - name: tester
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    ssh_authorized_keys:
      - $(cat id_vm.pub)
ssh_pwauth: false
package_update: true
packages:
  - build-essential
  - make
  - gcc
  - traceroute
  - tcpdump
  - valgrind
  - cppcheck
  - libcap2-bin
  - python3-pip
  - rsync
runcmd:
  - [ bash, -lc, "pip3 install --break-system-packages norminette || pip3 install norminette || true" ]
EOF

if [ ! -f seed.iso ]; then
	echo "==> building cloud-init seed ISO"
	if command -v hdiutil >/dev/null 2>&1; then
		hdiutil makehybrid -o seed.iso seed -iso -joliet \
			-default-volume-name CIDATA >/dev/null
	elif command -v genisoimage >/dev/null 2>&1; then
		genisoimage -output seed.iso -volid CIDATA -joliet -rock seed >/dev/null 2>&1
	elif command -v mkisofs >/dev/null 2>&1; then
		mkisofs -output seed.iso -volid CIDATA -joliet -rock seed >/dev/null 2>&1
	elif command -v xorriso >/dev/null 2>&1; then
		xorriso -as mkisofs -o seed.iso -V CIDATA -J -r seed >/dev/null 2>&1
	else
		echo "need hdiutil, genisoimage, mkisofs or xorriso to build the seed ISO" >&2
		echo "  Debian/Ubuntu: sudo apt install genisoimage" >&2
		echo "  Fedora:        sudo dnf install xorriso" >&2
		exit 1
	fi
fi

# ---------------------------------------------------------------------------
# 4. the VM itself
# ---------------------------------------------------------------------------
if ! "$VBM" showvminfo "$VM_NAME" >/dev/null 2>&1; then
	echo "==> creating VM $VM_NAME ($VB_ARCH, $OSTYPE_ID)"
	if "$VBM" createvm --help 2>&1 | grep -q -- --platform-architecture; then
		"$VBM" createvm --name "$VM_NAME" --ostype "$OSTYPE_ID" \
			--platform-architecture "$VB_ARCH" \
			--basefolder "$VM_DIR/vbox" --register
	else
		"$VBM" createvm --name "$VM_NAME" --ostype "$OSTYPE_ID" \
			--basefolder "$VM_DIR/vbox" --register
	fi

	# NAT with a forwarded SSH port. Bridged would give the guest a real LAN
	# address, which is what a multi-hop trace needs, but vmnet refuses to
	# bridge a Wi-Fi interface on macOS; set BRIDGE=<iface> on a wired host.
	if [ -n "${BRIDGE:-}" ]; then
		"$VBM" modifyvm "$VM_NAME" --nic1 bridged --bridgeadapter1 "$BRIDGE"
	else
		"$VBM" modifyvm "$VM_NAME" --nic1 nat
		"$VBM" modifyvm "$VM_NAME" --natpf1 "ssh,tcp,127.0.0.1,$SSH_PORT,,22"
	fi

	# vmsvga is explicit on purpose: the default graphics device fails to
	# construct on an ARM guest with
	#   Failed to construct device 'vga' instance #0 (VERR_PGM_RAM_CONFLICT)
	# even though nothing ever looks at the console.
	"$VBM" modifyvm "$VM_NAME" --memory "$MEMORY" --cpus "$CPUS" \
		--firmware efi --nictype1 virtio --audio-driver none --usb off \
		--graphicscontroller vmsvga --vram 16

	"$VBM" storagectl "$VM_NAME" --name virtio --add virtio --bootable on
	"$VBM" storageattach "$VM_NAME" --storagectl virtio --port 0 \
		--type hdd --medium "$VM_DIR/disk.vdi"
	"$VBM" storageattach "$VM_NAME" --storagectl virtio --port 1 \
		--type dvddrive --medium "$VM_DIR/seed.iso"
fi

# 127.0.0.1:<port> is reused by every VM that ever forwarded that port, so a
# previous VM's host key may still be pinned in known_hosts. ssh then refuses
# to connect with "REMOTE HOST IDENTIFICATION HAS CHANGED". That is a stale
# cache entry, not an attack, so drop it for this port before connecting.
if [ -f "$HOME/.ssh/known_hosts" ]; then
	ssh-keygen -q -f "$HOME/.ssh/known_hosts" -R "[127.0.0.1]:$SSH_PORT" \
		>/dev/null 2>&1 || true
	rm -f "$HOME/.ssh/known_hosts.old"
fi

# Already running (re-run of this script, or started by hand) is not an error.
if "$VBM" list runningvms | grep -q "\"$VM_NAME\""; then
	echo "==> $VM_NAME is already running"
else
	echo "==> starting headless"
	if ! "$VBM" startvm "$VM_NAME" --type headless >/dev/null 2>&1; then
		# A saved state written before the VM settings changed cannot be
		# restored: "Failed to load unit ... VERR_SSM_LOAD_CONFIG_MISMATCH".
		# The disk is untouched, so throwing the saved state away costs
		# nothing but an ordinary boot.
		echo "    saved state does not match the current config, discarding it"
		"$VBM" discardstate "$VM_NAME" >/dev/null 2>&1 || true
		"$VBM" startvm "$VM_NAME" --type headless >/dev/null
	fi
fi

# ---------------------------------------------------------------------------
# 5. wait for ssh
# ---------------------------------------------------------------------------


echo "==> waiting for ssh on port $SSH_PORT"
i=0
while [ "$i" -lt 60 ]; do
	if ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
		-o ConnectTimeout=4 -o BatchMode=yes -i id_vm -p "$SSH_PORT" \
		tester@127.0.0.1 true 2>/dev/null; then
		break
	fi
	i=$((i + 1))
done
[ "$i" -lt 60 ] || { echo "ssh never came up" >&2; exit 1; }

GUEST_KERNEL=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
	-o LogLevel=ERROR -i id_vm -p "$SSH_PORT" tester@127.0.0.1 \
	'uname -r' 2>/dev/null || echo unknown)

cat <<BANNER

===============================================================================
 VM READY  --  $VM_NAME
===============================================================================

  Guest          Debian 13 ($ARCH), kernel $GUEST_KERNEL
  Resources      $CPUS vCPU, $MEMORY MB RAM, $DISK_MB MB disk
  Network        $([ -n "${BRIDGE:-}" ] && echo "bridged via ${BRIDGE}" || echo "NAT, 127.0.0.1:$SSH_PORT -> guest 22")
  User           tester  (passwordless sudo)
  Private key    $VM_DIR/id_vm

 CONNECT
  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \\
      -o LogLevel=ERROR -i $VM_DIR/id_vm -p $SSH_PORT tester@127.0.0.1

  (those two options keep 127.0.0.1:$SSH_PORT out of known_hosts; without them
   the next VM on this port is rejected with HOST IDENTIFICATION HAS CHANGED.
   If you already hit that:
       ssh-keygen -R "[127.0.0.1]:$SSH_PORT")

 CONNECT WITHOUT THE FLAGS -- append this to ~/.ssh/config once, then 'ssh $VM_NAME':

  Host $VM_NAME
      HostName 127.0.0.1
      Port $SSH_PORT
      User tester
      IdentityFile $VM_DIR/id_vm
      StrictHostKeyChecking no
      UserKnownHostsFile /dev/null

 RUN THE SUITE IN THE VM
  sh vm/run-tests.sh           tests only
  sh vm/run-tests.sh gates     plus norminette, strict build, valgrind, diff-ref

 MANAGE
  $VBM controlvm $VM_NAME poweroff     stop it
  sh vm/create-vm.sh                   start it again
  sh vm/create-vm.sh destroy           delete the VM and its disk

===============================================================================
BANNER
