#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 animated-ads-cy|bashqueue GCLOUD_COMMAND [ARGS...]" >&2
  exit 2
}

[[ $# -ge 2 ]] || usage
account_config=$1
shift

case "$account_config" in
  animated-ads-cy) expected_account=animated.ads.cy@gmail.com ;;
  bashqueue) expected_account=bashqueue@gmail.com ;;
  *) usage ;;
esac

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
export CLOUDSDK_CONFIG=${CLOUDSDK_CONFIG:-$script_dir/.gcloud}
gcloud_bin="$script_dir/google-cloud-sdk/bin/gcloud"
[[ -x "$gcloud_bin" ]] || { echo "gcloud-account: gcloud not found: $gcloud_bin" >&2; exit 127; }

configured_account=$("$gcloud_bin" --configuration="$account_config" config get-value account 2>/dev/null)
[[ "$configured_account" == "$expected_account" ]] || {
  echo "gcloud-account: configuration '$account_config' must select '$expected_account' (found '${configured_account:-unset}')" >&2
  exit 3
}

exec "$gcloud_bin" --configuration="$account_config" "$@"
