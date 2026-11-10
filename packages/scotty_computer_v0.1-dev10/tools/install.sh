#!/usr/bin/env bash
set -euo pipefail
umask 077
src=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
target=${COMPUTER_INSTALL_ROOT:-"$HOME/.local/share/scotty-computer/v0.1-dev8"}
command_dir=${COMPUTER_BIN_DIR:-"$HOME/.local/bin"}
case "$target/" in "$src/"*) echo 'Target must not be inside source package' >&2; exit 2;; esac
if [[ -e "$target/Computer" || -e "$command_dir/Computer" ]]; then
  echo 'An installation already exists; refusing to overwrite it.' >&2
  echo 'Select an unused COMPUTER_INSTALL_ROOT and COMPUTER_BIN_DIR for a parallel install.' >&2
  exit 4
fi
mkdir -p -- "$target" "$command_dir"
for item in Computer src vendor adapters tools tests docs AGENTS.md CLAUDE.md .claude README.md; do
  cp -R -- "$src/$item" "$target/$item"
done
chmod +x "$target/Computer" "$target/src/ComputerActions.py" "$target/adapters/sshnode.sh" "$target/adapters/cloudctl.sh"
# Wrapper resolves installation path regardless of cwd and invokes native ooRexx.
{
  echo '#!/usr/bin/env bash'
  echo 'set -euo pipefail'
  printf 'exec "${REXX_BIN:-/usr/local/bin/rexx}" %q "$@"\n' "$target/Computer"
} > "$command_dir/Computer"
chmod +x "$command_dir/Computer"
printf 'Installed Computer: %s\nNative ooRexx entry: %s\n' "$command_dir/Computer" "$target/Computer"
printf 'Use: Computer help (ensure %s is in PATH)\n' "$command_dir"
printf 'To bind your current authoritative helpers, export COMPUTER_SSHNODE and COMPUTER_CLOUDCTL.\n'
