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
			echo "$_d/ft_traceroute"
			return 0
		fi
	done
	echo "$HOME/vm/ft_traceroute"
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
# vm_download <url> <output>
#
# curl with a working trust store, falling back to wget, which keeps its own
# CA configuration and often succeeds where curl does not. Never disables
# verification on its own: if both fail the user is told what to do.
# ---------------------------------------------------------------------------
vm_download()
{
	_url="$1"
	_out="$2"
	_ca=$(vm_find_ca_bundle || true)

	if [ -n "$_ca" ]; then
		echo "    (CA bundle: $_ca)"
		if curl -fL --retry 3 --cacert "$_ca" -o "$_out" "$_url"; then
			return 0
		fi
	else
		if curl -fL --retry 3 -o "$_out" "$_url"; then
			return 0
		fi
	fi

	if command -v wget >/dev/null 2>&1; then
		echo "    curl failed, retrying with wget"
		if wget -O "$_out" "$_url"; then
			return 0
		fi
	fi

	rm -f "$_out"
	cat >&2 <<MSG

Download failed: could not verify the TLS certificate of
  $_url

The image itself is fine -- this host has no usable CA bundle. Pick one:

  1. Install the trust store (best):
       Debian/Ubuntu:  sudo apt install ca-certificates && sudo update-ca-certificates
       Fedora/RHEL:    sudo dnf install ca-certificates && sudo update-ca-trust

  2. Point this script at a bundle you already have:
       CURL_CA_BUNDLE=/path/to/ca-bundle.crt sh vm/create-vm.sh

  3. Download the image by hand, with a browser or another machine, into:
       $VM_DIR/
     then re-run this script -- it skips the download when the file is there.

MSG
	return 1
}
