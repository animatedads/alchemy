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
  git -C "$REPO" fetch origin "$BRANCH"
  git -C "$REPO" checkout "$BRANCH"
  git -C "$REPO" merge --ff-only FETCH_HEAD
fi
if [ ! -f "$ROOT/config.json" ]; then
  cp "$REPO/packages/alchemy_autobuild_v0.3/config.example.json" "$ROOT/config.json"
fi
mkdir -p "$HOME/.config/systemd/user"
cat > "$HOME/.config/systemd/user/alchemy-autobuild.service" <<EOF
[Unit]
Description=Alchemy deterministic autobuild relay
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 $REPO/packages/alchemy_autobuild_v0.4.1/alchemy_autobuild.py --config $ROOT/config.json
Restart=on-failure
RestartSec=2

[Install]
WantedBy=default.target
EOF
printf '%s\n' "Installed Alchemy Autobuild v0.4.1 service definition"
