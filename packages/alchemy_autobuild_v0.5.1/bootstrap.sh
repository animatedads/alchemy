#!/bin/sh
# Alchemy Autobuild v0.5.1 service installer. Author: Claude (Opus 5.5), 2026-10-23. Architecture: Tom Dyer.
# Writes the user unit only. It does not start, stop or restart anything, and never overwrites config.json.
set -eu
ROOT="${ALCHEMY_AUTOBUILD_ROOT:-$HOME/alchemy-autobuild}"
REPO="$ROOT/repo"
ENTRY="$REPO/packages/alchemy_autobuild_v0.5.1/alchemy_autobuild.py"

[ -d "$REPO/.git" ] || { echo "autobuild repo checkout not found at $REPO" >&2; exit 2; }
[ -f "$ENTRY" ] || { echo "v0.5.1 not present in $REPO (pull main first)" >&2; exit 2; }
[ -f "$REPO/packages/alchemy_autobuild_v0.5/alchemy_autobuild.py" ] || { echo "v0.5 dependency missing" >&2; exit 2; }
[ -f "$REPO/packages/alchemy_autobuild_v0.4.2/git_sync.py" ] || { echo "v0.4.2 dependency missing" >&2; exit 2; }

if [ ! -f "$ROOT/config.json" ]; then
  cp "$REPO/packages/alchemy_autobuild_v0.3/config.example.json" "$ROOT/config.json"
  echo "Created $ROOT/config.json from the v0.3 example"
fi

# Prove the entry point starts before installing it (the check v0.5 never had).
/usr/bin/python3 "$ENTRY" --config "$ROOT/config.json" --print-config > /dev/null

mkdir -p "$HOME/.config/systemd/user"
cat > "$HOME/.config/systemd/user/alchemy-autobuild.service" <<UNIT
[Unit]
Description=Alchemy deterministic autobuild relay (v0.5.1)
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=0

[Service]
Type=simple
ExecStart=/usr/bin/python3 $ENTRY --config $ROOT/config.json
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
UNIT
echo "Installed Alchemy Autobuild v0.5.1 service definition (not started)"
