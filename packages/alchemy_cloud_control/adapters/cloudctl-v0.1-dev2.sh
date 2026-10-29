#!/usr/bin/env bash
set -euo pipefail

# Unified local cloud control front-end.  Provider credentials remain in the
# provider CLIs/environment; this command only normalises the operation shape.

die() { echo "cloudctl: $*" >&2; exit 2; }
need() { command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"; }

usage() {
  cat >&2 <<'EOF'
Usage:
  cloudctl PROVIDER restart ...
  cloudctl PROVIDER firewall list ...

Restart examples:
  cloudctl gcp   restart --account animated-ads-cy --project PROJECT --zone ZONE INSTANCE
  cloudctl gcp   restart --account bashqueue --project PROJECT --zone ZONE INSTANCE
  cloudctl aws   restart --region REGION INSTANCE_ID
  cloudctl azure restart --resource-group GROUP VM_NAME
  cloudctl oci   restart --region REGION --compartment-id OCID INSTANCE_OCID
  cloudctl vultr restart INSTANCE_ID

Firewall list examples:
  cloudctl gcp   firewall list --account animated-ads-cy --project PROJECT --filter FILTER
  cloudctl gcp   firewall list --account bashqueue --project PROJECT --filter FILTER
  cloudctl aws   firewall list --region REGION --group-id SG_ID
  cloudctl azure firewall list --resource-group GROUP --nsg NAME
  cloudctl oci   firewall list --compartment-id OCID
  cloudctl vultr firewall list [GROUP_ID]

Vultr authentication:
  VULTR_API_KEY=... cloudctl vultr ...
  or VULTR_API_KEY_FILE=/path/to/key cloudctl vultr ...
EOF
  exit 2
}

[[ $# -ge 2 ]] || usage
provider=$1; operation=$2; shift 2

gcp() {
  local account='' project='' zone='' instance='' filter=''
  local -a gcloud_cmd=() args=()
  case "$operation" in
    restart)
      while [[ $# -gt 0 ]]; do case "$1" in
        --account) [[ $# -ge 2 ]] || die 'gcp restart --account requires a value'; account=$2; shift 2;;
        --project) [[ $# -ge 2 ]] || die 'gcp restart --project requires a value'; project=$2; shift 2;;
        --zone) [[ $# -ge 2 ]] || die 'gcp restart --zone requires a value'; zone=$2; shift 2;;
        -*) die "unknown gcp restart option: $1";;
        *) [[ -z $instance ]] || die 'gcp restart accepts one INSTANCE'; instance=$1; shift;;
      esac; done
      [[ -n $project && -n $zone && -n $instance ]] || die 'gcp restart requires --account, --project, --zone, INSTANCE'
      ;;
    firewall)
      [[ ${1:-} == list ]] || die 'gcp firewall currently supports: list'
      shift
      while [[ $# -gt 0 ]]; do case "$1" in
        --account) [[ $# -ge 2 ]] || die 'gcp firewall --account requires a value'; account=$2; shift 2;;
        --project) [[ $# -ge 2 ]] || die 'gcp firewall --project requires a value'; project=$2; shift 2;;
        --filter) [[ $# -ge 2 ]] || die 'gcp firewall --filter requires a value'; filter=$2; shift 2;;
        *) die "unknown gcp firewall option: $1";;
      esac; done
      [[ -n $project ]] || die 'gcp firewall list requires --account, --project'
      ;;
    *) die "unsupported gcp operation: $operation";;
  esac

  case "$account" in
    animated-ads-cy|bashqueue) ;;
    '') die 'gcp operations require explicit --account animated-ads-cy|bashqueue';;
    *) die "unsupported gcloud account configuration: $account (use animated-ads-cy or bashqueue)";;
  esac
  local script_dir
  script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
  [[ -x "$script_dir/gcloud-account.sh" ]] || die "gcloud account wrapper not found: $script_dir/gcloud-account.sh"
  gcloud_cmd=("$script_dir/gcloud-account.sh" "$account")

  case "$operation" in
    restart)
      "${gcloud_cmd[@]}" compute instances reset "$instance" --project="$project" --zone="$zone" --quiet
      ;;
    firewall)
      args=(compute firewall-rules list --project="$project" --format=json)
      [[ -n $filter ]] && args+=(--filter="$filter")
      "${gcloud_cmd[@]}" "${args[@]}"
      ;;
  esac
}

awsctl() {
  need aws
  local region='' instance='' group=''
  case "$operation" in
    restart)
      while [[ $# -gt 0 ]]; do case "$1" in
        --region) region=$2; shift 2;; *) instance=$1; shift;; esac; done
      [[ -n $region && -n $instance ]] || die 'aws restart requires --region, INSTANCE_ID'
      aws ec2 reboot-instances --region "$region" --instance-ids "$instance"
      ;;
    firewall)
      [[ ${1:-} == list ]] || die 'aws firewall currently supports: list'
      shift
      while [[ $# -gt 0 ]]; do case "$1" in
        --region) region=$2; shift 2;; --group-id) group=$2; shift 2;; *) die "unknown aws firewall option: $1";; esac; done
      [[ -n $region && -n $group ]] || die 'aws firewall list requires --region, --group-id'
      aws ec2 describe-security-groups --region "$region" --group-ids "$group" --output json
      ;;
    *) die "unsupported aws operation: $operation";;
  esac
}

azurectl() {
  need az
  local rg='' vm='' nsg=''
  case "$operation" in
    restart)
      while [[ $# -gt 0 ]]; do case "$1" in
        --resource-group) rg=$2; shift 2;; *) vm=$1; shift;; esac; done
      [[ -n $rg && -n $vm ]] || die 'azure restart requires --resource-group, VM_NAME'
      az vm restart --resource-group "$rg" --name "$vm" --only-show-errors
      ;;
    firewall)
      [[ ${1:-} == list ]] || die 'azure firewall currently supports: list'
      shift
      while [[ $# -gt 0 ]]; do case "$1" in
        --resource-group) rg=$2; shift 2;; --nsg) nsg=$2; shift 2;; *) die "unknown azure firewall option: $1";; esac; done
      [[ -n $rg && -n $nsg ]] || die 'azure firewall list requires --resource-group, --nsg'
      az network nsg rule list --resource-group "$rg" --nsg-name "$nsg" --output json --only-show-errors
      ;;
    *) die "unsupported azure operation: $operation";;
  esac
}

ocictl() {
  need oci
  local region='' compartment='' instance=''
  case "$operation" in
    restart)
      while [[ $# -gt 0 ]]; do case "$1" in
        --region) region=$2; shift 2;; --compartment-id) compartment=$2; shift 2;; *) instance=$1; shift;; esac; done
      [[ -n $region && -n $compartment && -n $instance ]] || die 'oci restart requires --region, --compartment-id, INSTANCE_OCID'
      oci compute instance action --region "$region" --compartment-id "$compartment" --instance-id "$instance" --action SOFTRESET
      ;;
    firewall) die 'oci firewall list requires an explicit VCN/security-list mapping; use oci directly until configured';;
    *) die "unsupported oci operation: $operation";;
  esac
}

vultrctl() {
  need curl
  local key=${VULTR_API_KEY:-}
  if [[ -z $key && -n ${VULTR_API_KEY_FILE:-} ]]; then key=$(tr -d '[:space:]' < "$VULTR_API_KEY_FILE"); fi
  [[ -n $key ]] || die 'VULTR_API_KEY or VULTR_API_KEY_FILE is required'
  local base=https://api.vultr.com/v2 response='' id=''
  case "$operation" in
    restart)
      id=${1:-}; [[ -n $id ]] || die 'vultr restart requires INSTANCE_ID'
      curl -fsS -X POST "$base/instances/$id/reboot" -H "Authorization: Bearer $key" -H 'Accept: application/json'
      ;;
    firewall)
      [[ ${1:-} == list ]] || die 'vultr firewall currently supports: list'
      shift; id=${1:-}
      if [[ -n $id ]]; then
        curl -fsS "$base/firewall/groups/$id/rules" -H "Authorization: Bearer $key" -H 'Accept: application/json'
      else
        curl -fsS "$base/firewall/groups" -H "Authorization: Bearer $key" -H 'Accept: application/json'
      fi
      ;;
    *) die "unsupported vultr operation: $operation";;
  esac
}

case "$provider" in
  gcp) gcp "$@";; aws) awsctl "$@";; azure) azurectl "$@";; oci) ocictl "$@";; vultr) vultrctl "$@";; help|-h|--help) usage;; *) die "unknown provider: $provider";;
esac
