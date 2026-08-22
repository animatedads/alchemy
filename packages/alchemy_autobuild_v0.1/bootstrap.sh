#!/bin/sh
set -eu
ROOT="${ALCHEMY_AUTOBUILD_ROOT:-$HOME/alchemy-autobuild}"
REPO="$ROOT/repo"
URL="git@github-alchemy:animatedads/alchemy.git"
BRANCH="main"

mkdir -p "$ROOT"
if [ ! -d "$REPO/.git" ]; then
  git clone --branch "$BRANCH" "$URL" "$REPO"
else
  git -C "$REPO" fetch origin
  git -C "$REPO" checkout "$BRANCH"
  git -C "$REPO" pull --ff-only origin "$BRANCH"
fi

if [ ! -f "$ROOT/config.json" ]; then
  cp "$REPO/packages/alchemy_autobuild_v0.1/config.example.json" "$ROOT/config.json"
fi

mkdir -p "$HOME/.config/systemd/user"
cat > "$HOME/.config/systemd/user/alchemy-autobuild.service" <<EOF
[Unit]
Description=Alchemy deterministic autobuild relay
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 $REPO/packages/alchemy_autobuild_v0.1/alchemy_autobuild.py --config $ROOT/config.json
Restart=on-failure
RestartSec=2

[Install]
WantedBy=default.target
EOF

printf '%s\n' "Installed files under $ROOT"
printf '%s\n' "Config: $ROOT/config.json"
printf '%s\n' "Service: $HOME/.config/systemd/user/alchemy-autobuild.service"
printf '%s\n' "Enable with: systemctl --user daemon-reload && systemctl --user enable --now alchemy-autobuild.service"
