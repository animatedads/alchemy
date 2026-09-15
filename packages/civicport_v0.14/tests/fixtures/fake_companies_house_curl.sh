#!/usr/bin/env bash
set -euo pipefail
all_args="$*"
[[ "$all_args" != *"fixture-secret-123"* ]] || { echo "credential secret leaked into curl argv" >&2; exit 63; }
header_path=""
body_path=""
config_path=""
url=""
while (($#)); do
  case "$1" in
    --dump-header) header_path="$2"; shift 2 ;;
    --output) body_path="$2"; shift 2 ;;
    --config) config_path="$2"; shift 2 ;;
    --max-time|--request|--header|--proto|--max-redirs) shift 2 ;;
    --disable|--silent|--show-error) shift ;;
    --*) shift ;;
    *) url="$1"; shift ;;
  esac
done
[[ -n "$header_path" && -n "$body_path" && -n "$config_path" && -n "$url" ]] || { echo "fake Companies House curl missing expected arguments" >&2; exit 64; }
[[ "$(stat -c '%a' "$config_path")" == "600" ]] || { echo "credential config mode is not 600" >&2; exit 65; }
grep -Fqx 'user = "fixture-secret-123:"' "$config_path" || { echo "credential config did not contain expected test Basic user" >&2; exit 66; }
[[ "$url" == "https://api.company-information.service.gov.uk/company/01234567" ]] || { echo "unexpected Companies House URL" >&2; exit 67; }
cat fixtures/companies_house_fixture.headers > "$header_path"
cat fixtures/companies_house_fixture.body > "$body_path"
