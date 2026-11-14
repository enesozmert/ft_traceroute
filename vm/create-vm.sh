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

VM_NAME="${VM_NAME:-ft-tr-vm}"
VM_DIR="${VM_DIR:-$HOME/vm/ft_traceroute}"
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

# ---------------------------------------------------------------------------
# 2. disk — official Debian cloud image, converted to VDI and grown
# ---------------------------------------------------------------------------
if [ ! -f "debian-13-$ARCH.qcow2" ]; then
	echo "==> downloading $IMAGE_URL"
	curl -fL --retry 3 -o "debian-13-$ARCH.qcow2" "$IMAGE_URL"
fi

if [ ! -f disk.vdi ]; then
	echo "==> converting to VDI"
	qemu-img convert -f qcow2 -O vdi "debian-13-$ARCH.qcow2" disk.vdi
	"$VBM" modifymedium disk disk.vdi --resize "$DISK_MB"
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

	"$VBM" modifyvm "$VM_NAME" --memory "$MEMORY" --cpus "$CPUS" \
		--firmware efi --nictype1 virtio --audio-driver none --usb off

	"$VBM" storagectl "$VM_NAME" --name virtio --add virtio --bootable on
	"$VBM" storageattach "$VM_NAME" --storagectl virtio --port 0 \
		--type hdd --medium "$VM_DIR/disk.vdi"
	"$VBM" storageattach "$VM_NAME" --storagectl virtio --port 1 \
		--type dvddrive --medium "$VM_DIR/seed.iso"
fi

# Already running (re-run of this script, or started by hand) is not an error.
if "$VBM" list runningvms | grep -q "\"$VM_NAME\""; then
	echo "==> $VM_NAME is already running"
else
	echo "==> starting headless"
	"$VBM" startvm "$VM_NAME" --type headless >/dev/null
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
  ssh -i $VM_DIR/id_vm -p $SSH_PORT tester@127.0.0.1

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
