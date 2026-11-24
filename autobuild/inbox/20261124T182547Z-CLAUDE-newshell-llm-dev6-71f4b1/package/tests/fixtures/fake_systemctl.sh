#!/bin/sh
# Stand-in for systemctl list-units / list-unit-files.
case "$1" in
  list-units) cat <<'U'
chrony.service loaded active running chrony, an NTP client/server
ssh.service loaded active running OpenBSD Secure Shell server
systemd-networkd.service loaded active running Network Configuration
xtpd.service loaded failed failed xtpd: the XTP network service daemon (v0.1-dev1)
U
  ;;
  list-unit-files) printf 'chrony.service enabled enabled\nssh.service enabled enabled\n' ;;
  *) echo "fake systemctl: $*" >&2; exit 1 ;;
esac
