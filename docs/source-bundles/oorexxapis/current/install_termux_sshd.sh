#!/data/data/com.termux/files/usr/bin/bash
#
# install_termux_sshd.sh
#
# Installs and starts OpenSSH server in Termux, then asks for one pasted
# SSH public key and installs it into ~/.ssh/authorized_keys.
#
set -euo pipefail

say()  { printf '\n==> %s\n' "$*"; }
die()  { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

: "${PREFIX:?This does not look like a Termux shell. PREFIX is not set.}"

say "Checking OpenSSH"
if ! command -v sshd >/dev/null 2>&1; then
    say "Installing openssh"
    pkg install -y openssh
fi

command -v sshd >/dev/null 2>&1 || die "sshd is still unavailable after package installation."
command -v ssh-keygen >/dev/null 2>&1 || die "ssh-keygen is unavailable."

say "Preparing SSH directory"
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
AUTH_KEYS="$HOME/.ssh/authorized_keys"
touch "$AUTH_KEYS"
chmod 600 "$AUTH_KEYS"

printf '\nPaste ONE SSH PUBLIC KEY, then press Enter.\n'
printf 'Example: ssh-ed25519 AAAAC3... workstation\n\n'
IFS= read -r KEY

[ -n "$KEY" ] || die "No key was supplied."

case "$KEY" in
    ssh-ed25519\ *|ssh-rsa\ *|ecdsa-sha2-*\ *|sk-ssh-ed25519@openssh.com\ *|sk-ecdsa-sha2-nistp256@openssh.com\ *)
        ;;
    *)
        die "That does not look like a supported OpenSSH public key."
        ;;
esac

TMPKEY="$PREFIX/tmp/termux-authorized-key.$$"
trap 'rm -f "$TMPKEY"' EXIT
printf '%s\n' "$KEY" > "$TMPKEY"

if ! ssh-keygen -l -f "$TMPKEY" >/dev/null 2>&1; then
    die "ssh-keygen rejected the pasted public key."
fi

FINGERPRINT="$(ssh-keygen -l -f "$TMPKEY" | sed -n '1p')"

if grep -Fqx -- "$KEY" "$AUTH_KEYS"; then
    say "Key is already present in authorized_keys"
else
    printf '%s\n' "$KEY" >> "$AUTH_KEYS"
    say "Key added to authorized_keys"
fi

chmod 600 "$AUTH_KEYS"

say "Starting sshd"
# Termux sshd normally listens on port 8022.
if pgrep -x sshd >/dev/null 2>&1; then
    echo "sshd is already running."
else
    sshd
fi

sleep 1

USER_NAME="$(whoami)"
PORT="8022"

say "Installed key"
echo "$FINGERPRINT"

say "SSH server status"
printf 'User : %s\n' "$USER_NAME"
printf 'Port : %s\n' "$PORT"

if command -v ss >/dev/null 2>&1; then
    ss -ltn 2>/dev/null | grep -E '(:8022[[:space:]]|:8022$)' || true
fi

PHONE_IP=""

if command -v termux-wifi-connectioninfo >/dev/null 2>&1; then
    WIFI_JSON="$(termux-wifi-connectioninfo 2>/dev/null || true)"
    PHONE_IP="$(printf '%s\n' "$WIFI_JSON" | sed -n 's/.*"ip"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
fi

if [ -z "$PHONE_IP" ] && command -v ip >/dev/null 2>&1; then
    PHONE_IP="$(ip -4 addr show wlan0 2>/dev/null | awk '/inet / {sub(/\/.*/, "", $2); print $2; exit}')"
fi

echo
if [ -n "$PHONE_IP" ]; then
    echo "Connect from another machine with:"
    echo
    printf '  ssh -p %s %s@%s\n' "$PORT" "$USER_NAME" "$PHONE_IP"
else
    echo "Connect from another machine with:"
    echo
    printf '  ssh -p %s %s@<phone-ip>\n' "$PORT" "$USER_NAME"
    echo
    echo "You can inspect the phone Wi-Fi address with:"
    echo "  termux-wifi-connectioninfo"
fi

echo
echo "To stop the server:"
echo "  pkill sshd"
echo
echo "authorized_keys:"
echo "  $AUTH_KEYS"
