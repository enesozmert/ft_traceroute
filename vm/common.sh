# =============================================================================
# ft_traceroute — shared helpers for the vm/ scripts
#
# Sourced, not executed.
# =============================================================================

# ---------------------------------------------------------------------------
# Where the VM lives.
#
# The disk is ~1.3 GB plus a ~400 MB image, which does not fit in a 42 home
# directory quota. On a school machine goinfre is the scratch space meant for
# exactly this, so it wins when it exists; VM_DIR overrides everything.
# ---------------------------------------------------------------------------
vm_default_dir()
{
	_user=$(id -un 2>/dev/null || echo "${USER:-user}")
	for _d in "$HOME/goinfre" "/goinfre/$_user" \
		"$HOME/sgoinfre" "/sgoinfre/$_user"; do
		if [ -d "$_d" ] && [ -w "$_d" ]; then
			# "-vm" so the path can never land on the checkout itself: cloning
			# into goinfre/ft_traceroute would otherwise drop a 1.3 GB disk
			# image inside the git tree, and the sync would try to ship it.
			echo "$_d/ft_traceroute-vm"
			return 0
		fi
	done
	echo "$HOME/vm/ft_traceroute"
}

# ---------------------------------------------------------------------------
# vm_guard_dir <vm_dir> <repo_dir>
#
# Refuse to put the VM inside the checkout. The disk image alone is 1.3 GB and
# would end up in git status, in the sync, and in any archive of the project.
# ---------------------------------------------------------------------------
vm_guard_dir()
{
	_vm=$1
	_repo=$2
	if [ "$_vm" = "$_repo" ]; then
		echo "VM directory is the project itself: $_vm" >&2
		echo "Pick another one, e.g. VM_DIR=$_vm-vm sh vm/create-vm.sh" >&2
		return 1
	fi
	case "$_vm/" in
		"$_repo"/*)
			echo "VM directory is inside the project: $_vm" >&2
			echo "Pick one outside it, e.g. VM_DIR=$_repo-vm" >&2
			return 1
			;;
	esac
	return 0
}

# ---------------------------------------------------------------------------
# A CA bundle for curl.
#
# Distributions disagree on where the trust store lives, and a lab machine is
# often built against a path that is not there, which surfaces as:
#   curl: (60) SSL certificate ... unable to get local issuer certificate
# Verification stays on -- this only points curl at a bundle that exists.
# ---------------------------------------------------------------------------
vm_find_ca_bundle()
{
	for _c in "${CURL_CA_BUNDLE:-}" "${SSL_CERT_FILE:-}" \
		/etc/ssl/certs/ca-certificates.crt \
		/etc/pki/tls/certs/ca-bundle.crt \
		/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem \
		/etc/ssl/ca-bundle.pem \
		/etc/ssl/cert.pem \
		/usr/local/etc/openssl@3/cert.pem \
		/usr/local/etc/openssl/cert.pem; do
		if [ -n "$_c" ] && [ -f "$_c" ]; then
			echo "$_c"
			return 0
		fi
	done

	# Python's certifi ships its own bundle and is present on most 42 machines.
	if command -v python3 >/dev/null 2>&1; then
		_c=$(python3 -c 'import certifi; print(certifi.where())' 2>/dev/null || true)
		if [ -n "$_c" ] && [ -f "$_c" ]; then
			echo "$_c"
			return 0
		fi
	fi

	return 1
}

# ---------------------------------------------------------------------------
# vm_verify_sha512 <file> <expected>
# ---------------------------------------------------------------------------
vm_verify_sha512()
{
	_f="$1"
	_want="$2"
	if command -v sha512sum >/dev/null 2>&1; then
		_got=$(sha512sum "$_f" | cut -d" " -f1)
	elif command -v shasum >/dev/null 2>&1; then
		_got=$(shasum -a 512 "$_f" | cut -d" " -f1)
	else
		echo "    no sha512sum/shasum available, skipping checksum" >&2
		return 0
	fi
	[ "$_got" = "$_want" ]
}

# ---------------------------------------------------------------------------
# vm_download <url> <output>
#
# Order of attempts:
#   1. curl with a CA bundle that actually exists on this host
#   2. curl with its own defaults
#   3. wget, which keeps a separate CA configuration and often works where
#      curl does not
#   4. plain HTTP, with the download verified against the SHA512SUMS the
#      mirror publishes next to the image
#
# Step 4 is the escape hatch for a host with no usable trust store -- a
# school machine, or a network that intercepts TLS with its own root CA.
# It is weaker than TLS (an attacker who rewrites the image can rewrite the
# checksum too) but it still catches a corrupted or truncated download, which
# is more than curl -k would do. Nothing here disables TLS verification.
# ---------------------------------------------------------------------------
vm_download()
{
	_url="$1"
	_out="$2"
	_ca=$(vm_find_ca_bundle || true)

	if [ -n "$_ca" ]; then
		echo "    (CA bundle: $_ca)"
		if curl -fL --retry 3 --progress-bar --cacert "$_ca" -o "$_out" "$_url"; then
			return 0
		fi
		echo "    that bundle did not satisfy curl, trying its defaults"
	fi

	if curl -fL --retry 3 --progress-bar -o "$_out" "$_url"; then
		return 0
	fi

	if command -v wget >/dev/null 2>&1; then
		echo "    curl failed, retrying with wget"
		if wget -O "$_out" "$_url"; then
			return 0
		fi
	fi

	# --- step 4: plain HTTP + published checksum -----------------------------
	_http=$(printf %s "$_url" | sed "s|^https://|http://|")
	_base=$(printf %s "$_http" | sed "s|/[^/]*$||")
	_name=$(basename "$_url")

	echo
	echo "    TLS is not usable on this host."
	echo "    Falling back to plain HTTP with a SHA512 check against"
	echo "      $_base/SHA512SUMS"
	echo

	_sums=$(mktemp 2>/dev/null || echo /tmp/ft_tr_sha512sums)
	if curl -fsL -o "$_sums" "$_base/SHA512SUMS" 2>/dev/null \
		|| wget -qO "$_sums" "$_base/SHA512SUMS" 2>/dev/null; then
		_want=$(grep "  $_name\$" "$_sums" 2>/dev/null | cut -d" " -f1 | head -1)
	else
		_want=""
	fi
	rm -f "$_sums"

	if [ -z "$_want" ]; then
		echo "    could not fetch the checksum list either" >&2
	else
		if curl -fL --retry 3 --progress-bar -o "$_out" "$_http" \
			|| wget -O "$_out" "$_http"; then
			echo "    verifying SHA512..."
			if vm_verify_sha512 "$_out" "$_want"; then
				echo "    checksum OK"
				return 0
			fi
			echo "    CHECKSUM MISMATCH -- discarding the download" >&2
			rm -f "$_out"
		fi
	fi

	rm -f "$_out"
	cat >&2 <<MSG

Download failed for
  $_url

Every option was tried: curl with a located CA bundle, curl's own defaults,
wget, and plain HTTP verified against the mirror's SHA512SUMS.

Fix the trust store, or bring the image in by hand:

  1. Install the CA certificates (best):
       Debian/Ubuntu:  sudo apt install ca-certificates && sudo update-ca-certificates
       Fedora/RHEL:    sudo dnf install ca-certificates && sudo update-ca-trust

  2. If your network intercepts TLS with its own root CA, point curl at it:
       CURL_CA_BUNDLE=/path/to/that-root-ca.crt sh vm/create-vm.sh

  3. Download the image on any other machine and drop it here:
       $VM_DIR/$(basename "$_url")
     then re-run this script -- it skips the download when the file exists.

MSG
	return 1
}
