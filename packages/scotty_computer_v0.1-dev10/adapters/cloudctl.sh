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
  cloudctl vultr restart INSTANCE_ID|NODE_ALIAS
  cloudctl vultr restart ed209k

Firewall list examples:
  cloudctl gcp   firewall list --account animated-ads-cy --project PROJECT --filter FILTER
  cloudctl gcp   firewall list --account bashqueue --project PROJECT --filter FILTER
  cloudctl gcp   firewall allow-xtp-peers --account ACCOUNT --project PROJECT --network NETWORK --name RULE --target-tag TAG --source-range CIDR [--source-range CIDR ...]
  cloudctl gcp   firewall replace-xtp-peers --account ACCOUNT --project PROJECT --network NETWORK --name RULE --target-tag TAG --udp-port PORT --source-range CIDR [--source-range CIDR ...]
  cloudctl aws   firewall list --region REGION --group-id SG_ID
  cloudctl aws   firewall allow-xtp-peers --region REGION --group-id SG_ID --source-range CIDR [--source-range CIDR ...]
  cloudctl aws   firewall replace-xtp-peers --region REGION --group-id SG_ID --udp-port PORT [--raw-source CIDR ...] [--udp-source CIDR ...]
  cloudctl azure firewall list --resource-group GROUP --nsg NAME
  cloudctl azure firewall set-sources --resource-group GROUP --nsg NAME --rule RULE --source CIDR [--source CIDR ...]
  cloudctl azure firewall allow-xtp-peers --resource-group GROUP --nsg NAME --rule RULE --source CIDR [--source CIDR ...]
  cloudctl azure firewall replace-xtp-peers --resource-group GROUP --nsg NAME --udp-port PORT [--raw-source CIDR ...] [--udp-source CIDR ...]
  cloudctl oci   firewall list --compartment-id OCID
  cloudctl oci   firewall allow-xtp-peers --security-list-id OCID --source CIDR [--source CIDR ...]
  cloudctl oci   firewall replace-xtp-peers --security-list-id OCID --udp-port PORT [--raw-source CIDR ...] [--udp-source CIDR ...]
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
  local fw_action='' fw_name='' fw_network='default' fw_priority=900 fw_allow='all' fw_udp_port=''
  local -a fw_sources=() fw_tags=()
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
      case "${1:-}" in
      list)
      fw_action=list
      shift
      while [[ $# -gt 0 ]]; do case "$1" in
        --account) [[ $# -ge 2 ]] || die 'gcp firewall --account requires a value'; account=$2; shift 2;;
        --project) [[ $# -ge 2 ]] || die 'gcp firewall --project requires a value'; project=$2; shift 2;;
        --filter) [[ $# -ge 2 ]] || die 'gcp firewall --filter requires a value'; filter=$2; shift 2;;
        *) die "unknown gcp firewall option: $1";;
      esac; done
      [[ -n $project ]] || die 'gcp firewall list requires --account, --project'
      ;;
      allow-xtp-peers)
      fw_action=allow-xtp-peers
      shift
      while [[ $# -gt 0 ]]; do case "$1" in
        --account) account=$2; shift 2;;
        --project) project=$2; shift 2;;
        --network) fw_network=$2; shift 2;;
        --name) fw_name=$2; shift 2;;
        --priority) fw_priority=$2; shift 2;;
        --target-tag) fw_tags+=("$2"); shift 2;;
        --source-range) fw_sources+=("$2"); shift 2;;
        *) die "unknown gcp firewall allow-xtp-peers option: $1";;
      esac; done
      [[ -n $project && -n $fw_name && ${#fw_sources[@]} -gt 0 && ${#fw_tags[@]} -gt 0 ]] || die 'gcp firewall allow-xtp-peers requires --account, --project, --name, --target-tag and at least one --source-range'
      ;;
      replace-xtp-peers)
      fw_action=replace-xtp-peers
      shift
      while [[ $# -gt 0 ]]; do case "$1" in
        --account) account=$2; shift 2;;
        --project) project=$2; shift 2;;
        --network) fw_network=$2; shift 2;;
        --name) fw_name=$2; shift 2;;
        --priority) fw_priority=$2; shift 2;;
        --target-tag) fw_tags+=("$2"); shift 2;;
        --source-range) fw_sources+=("$2"); shift 2;;
        --udp-port) fw_udp_port=$2; shift 2;;
        *) die "unknown gcp firewall replace-xtp-peers option: $1";;
      esac; done
      [[ -n $project && -n $fw_name && -n $fw_udp_port && ${#fw_sources[@]} -gt 0 && ${#fw_tags[@]} -gt 0 ]] || die 'gcp firewall replace-xtp-peers requires --account, --project, --name, --target-tag, --udp-port and peer sources'
      [[ $fw_udp_port =~ ^[0-9]+$ ]] && ((fw_udp_port >= 1 && fw_udp_port <= 65535)) || die 'gcp firewall --udp-port must be 1..65535'
      fw_allow="udp:$fw_udp_port"
      ;;
      *) die 'gcp firewall currently supports: list, allow-xtp-peers, replace-xtp-peers';;
      esac
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
      if [[ $fw_action == allow-xtp-peers || $fw_action == replace-xtp-peers ]]; then
        local source_csv tag_csv
        source_csv=$(IFS=,; echo "${fw_sources[*]}")
        tag_csv=$(IFS=,; echo "${fw_tags[*]}")
        local description='Allow commissioned XTP-over-UDP only from explicitly listed ED209 peer addresses'
        if "${gcloud_cmd[@]}" compute firewall-rules describe "$fw_name" --project="$project" >/dev/null 2>&1; then
          "${gcloud_cmd[@]}" compute firewall-rules update "$fw_name" --project="$project" --allow="$fw_allow" --source-ranges="$source_csv" --target-tags="$tag_csv" --priority="$fw_priority" --description="$description"
        else
          "${gcloud_cmd[@]}" compute firewall-rules create "$fw_name" --project="$project" --network="$fw_network" --direction=INGRESS --priority="$fw_priority" --action=ALLOW --rules="$fw_allow" --source-ranges="$source_csv" --target-tags="$tag_csv" --description="$description"
        fi
      else
        args=(compute firewall-rules list --project="$project" --format=json)
        [[ -n $filter ]] && args+=(--filter="$filter")
        "${gcloud_cmd[@]}" "${args[@]}"
      fi
      ;;
  esac
}

awsctl() {
  need aws
  local region='' instance='' group='' udp_port=''
  local -a sources=() raw_sources=() udp_sources=()
  case "$operation" in
    restart)
      while [[ $# -gt 0 ]]; do case "$1" in
        --region) region=$2; shift 2;; *) instance=$1; shift;; esac; done
      [[ -n $region && -n $instance ]] || die 'aws restart requires --region, INSTANCE_ID'
      aws ec2 reboot-instances --region "$region" --instance-ids "$instance"
      ;;
    firewall)
      [[ ${1:-} == list || ${1:-} == allow-xtp-peers || ${1:-} == replace-xtp-peers ]] || die 'aws firewall currently supports: list, allow-xtp-peers, replace-xtp-peers'
      local fw_action=$1
      shift
      while [[ $# -gt 0 ]]; do case "$1" in
        --region) [[ $# -ge 2 ]] || die 'aws firewall --region requires a value'; region=$2; shift 2;;
        --group-id) [[ $# -ge 2 ]] || die 'aws firewall --group-id requires a value'; group=$2; shift 2;;
        --source-range) [[ $# -ge 2 ]] || die 'aws firewall --source-range requires a CIDR'; sources+=("$2"); shift 2;;
        --raw-source) [[ $# -ge 2 ]] || die 'aws firewall --raw-source requires a CIDR'; raw_sources+=("$2"); shift 2;;
        --udp-source) [[ $# -ge 2 ]] || die 'aws firewall --udp-source requires a CIDR'; udp_sources+=("$2"); shift 2;;
        --udp-port) [[ $# -ge 2 ]] || die 'aws firewall --udp-port requires a value'; udp_port=$2; shift 2;;
        *) die "unknown aws firewall option: $1";;
      esac; done
      [[ -n $region && -n $group ]] || die "aws firewall $fw_action requires --region, --group-id"
      if [[ $fw_action == list ]]; then
        ((${#sources[@]} == 0)) || die 'aws firewall list does not accept --source-range'
        aws ec2 describe-security-groups --region "$region" --group-ids "$group" --output json
      elif [[ $fw_action == allow-xtp-peers ]]; then
        ((${#sources[@]} > 0)) || die 'aws firewall allow-xtp-peers requires at least one --source-range'
        need jq
        local current cidr
        current=$(aws ec2 describe-security-groups --region "$region" --group-ids "$group" --output json)
        for cidr in "${sources[@]}"; do
          [[ $cidr =~ ^[0-9./]+$ ]] || die "invalid IPv4 CIDR: $cidr"
          if jq -e --arg cidr "$cidr" '.SecurityGroups[0].IpPermissions[]? | select(.IpProtocol == "36") | .IpRanges[]?.CidrIp | select(. == $cidr)' <<<"$current" >/dev/null; then
            printf 'Already allowed: protocol 36 from %s\n' "$cidr"
          else
            aws ec2 authorize-security-group-ingress --region "$region" --group-id "$group" --protocol 36 --cidr "$cidr" --output json
          fi
          current=$(aws ec2 describe-security-groups --region "$region" --group-ids "$group" --output json)
        done
      else
        [[ $udp_port =~ ^[0-9]+$ ]] && ((udp_port >= 1 && udp_port <= 65535)) || die 'aws firewall replace-xtp-peers requires --udp-port 1..65535'
        ((${#sources[@]} == 0)) || die 'use --raw-source and --udp-source with replace-xtp-peers'
        ((${#raw_sources[@]} + ${#udp_sources[@]} > 0)) || die 'aws firewall replace-xtp-peers requires peer sources'
        need jq
        local current cidr
        current=$(aws ec2 describe-security-groups --region "$region" --group-ids "$group" --output json)
        for cidr in "${raw_sources[@]}"; do
          [[ $cidr =~ ^[0-9./]+$ ]] || die "invalid IPv4 CIDR: $cidr"
          if ! jq -e --arg cidr "$cidr" '.SecurityGroups[0].IpPermissions[]? | select(.IpProtocol == "36") | .IpRanges[]?.CidrIp | select(. == $cidr)' <<<"$current" >/dev/null; then
            aws ec2 authorize-security-group-ingress --region "$region" --group-id "$group" --protocol 36 --cidr "$cidr" >/dev/null
          fi
        done
        for cidr in "${udp_sources[@]}"; do
          [[ $cidr =~ ^[0-9./]+$ ]] || die "invalid IPv4 CIDR: $cidr"
          if ! jq -e --arg cidr "$cidr" --argjson port "$udp_port" '.SecurityGroups[0].IpPermissions[]? | select(.IpProtocol == "udp" and .FromPort == $port and .ToPort == $port) | .IpRanges[]?.CidrIp | select(. == $cidr)' <<<"$current" >/dev/null; then
            aws ec2 authorize-security-group-ingress --region "$region" --group-id "$group" --protocol udp --port "$udp_port" --cidr "$cidr" >/dev/null
          fi
        done
        for cidr in $(jq -r '.SecurityGroups[0].IpPermissions[]? | select(.IpProtocol == "36") | .IpRanges[]?.CidrIp' <<<"$current"); do
          if [[ ! " ${raw_sources[*]} " == *" $cidr "* ]]; then
            aws ec2 revoke-security-group-ingress --region "$region" --group-id "$group" --protocol 36 --cidr "$cidr" >/dev/null
          fi
        done
        while IFS= read -r cidr; do
          [[ -n $cidr ]] || continue
          aws ec2 revoke-security-group-ingress --region "$region" --group-id "$group" --protocol udp --port 43601-43656 --cidr "$cidr" >/dev/null
        done < <(jq -r '.SecurityGroups[0].IpPermissions[]? | select(.IpProtocol == "udp" and .FromPort == 43601 and .ToPort == 43656) | .IpRanges[]?.CidrIp' <<<"$current")
        printf 'Replaced XTP ingress: protocol 36 peers=%s; UDP %s peers=%s\n' "${#raw_sources[@]}" "$udp_port" "${#udp_sources[@]}"
      fi
      ;;
    *) die "unsupported aws operation: $operation";;
  esac
}

azurectl() {
  need az
  local rg='' vm='' nsg='' rule=''
  local -a sources=()
  case "$operation" in
    restart)
      while [[ $# -gt 0 ]]; do case "$1" in
        --resource-group) rg=$2; shift 2;; *) vm=$1; shift;; esac; done
      [[ -n $rg && -n $vm ]] || die 'azure restart requires --resource-group, VM_NAME'
      az vm restart --resource-group "$rg" --name "$vm" --only-show-errors
      ;;
    firewall)
      case "${1:-}" in
        list)
          shift
          while [[ $# -gt 0 ]]; do case "$1" in
            --resource-group) [[ $# -ge 2 ]] || die 'azure firewall --resource-group requires a value'; rg=$2; shift 2;;
            --nsg) [[ $# -ge 2 ]] || die 'azure firewall --nsg requires a value'; nsg=$2; shift 2;;
            *) die "unknown azure firewall option: $1";;
          esac; done
          [[ -n $rg && -n $nsg ]] || die 'azure firewall list requires --resource-group, --nsg'
          az network nsg rule list --resource-group "$rg" --nsg-name "$nsg" --output json --only-show-errors
          ;;
        set-sources)
          shift
          while [[ $# -gt 0 ]]; do case "$1" in
            --resource-group) [[ $# -ge 2 ]] || die 'azure firewall --resource-group requires a value'; rg=$2; shift 2;;
            --nsg) [[ $# -ge 2 ]] || die 'azure firewall --nsg requires a value'; nsg=$2; shift 2;;
            --rule) [[ $# -ge 2 ]] || die 'azure firewall --rule requires a value'; rule=$2; shift 2;;
            --source) [[ $# -ge 2 ]] || die 'azure firewall --source requires a CIDR'; sources+=("$2"); shift 2;;
            *) die "unknown azure firewall option: $1";;
          esac; done
          [[ -n $rg && -n $nsg && -n $rule && ${#sources[@]} -gt 0 ]] || die 'azure firewall set-sources requires --resource-group, --nsg, --rule and at least one --source CIDR'
          az network nsg rule update --resource-group "$rg" --nsg-name "$nsg" --name "$rule" --source-address-prefixes "${sources[@]}" --output json --only-show-errors
          ;;
        allow-xtp-peers)
          shift
          while [[ $# -gt 0 ]]; do case "$1" in
            --resource-group) rg=$2; shift 2;;
            --nsg) nsg=$2; shift 2;;
            --rule) rule=$2; shift 2;;
            --source) sources+=("$2"); shift 2;;
            *) die "unknown azure firewall allow-xtp-peers option: $1";;
          esac; done
          [[ -n $rg && -n $nsg && -n $rule && ${#sources[@]} -gt 0 ]] || die 'azure firewall allow-xtp-peers requires --resource-group, --nsg, --rule and at least one --source CIDR'
          # Azure NSGs do not expose custom protocol numbers. '*' is the narrowest
          # available protocol selector, so sources are restricted to the ED209 peers.
          if az network nsg rule show --resource-group "$rg" --nsg-name "$nsg" --name "$rule" --output none --only-show-errors >/dev/null 2>&1; then
            az network nsg rule update --resource-group "$rg" --nsg-name "$nsg" --name "$rule" --priority 250 --direction Inbound --access Allow --protocol '*' --source-address-prefixes "${sources[@]}" --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges '*' --output json --only-show-errors
          else
            az network nsg rule create --resource-group "$rg" --nsg-name "$nsg" --name "$rule" --priority 250 --direction Inbound --access Allow --protocol '*' --source-address-prefixes "${sources[@]}" --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges '*' --description 'XTP qualification peer access; Azure NSG custom IP protocol numbers are unavailable' --output json --only-show-errors
          fi
          ;;
        replace-xtp-peers)
          local udp_port=62801 raw_rule=ed209-xtp-peers udp_rule=ed209-xtp-udp
          local -a raw_sources=() udp_sources=()
          shift
          while [[ $# -gt 0 ]]; do case "$1" in
            --resource-group) rg=$2; shift 2;;
            --nsg) nsg=$2; shift 2;;
            --udp-port) udp_port=$2; shift 2;;
            --raw-source) raw_sources+=("$2"); shift 2;;
            --udp-source) udp_sources+=("$2"); shift 2;;
            --raw-rule) raw_rule=$2; shift 2;;
            --udp-rule) udp_rule=$2; shift 2;;
            *) die "unknown azure firewall replace-xtp-peers option: $1";;
          esac; done
          [[ -n $rg && -n $nsg && $udp_port =~ ^[0-9]+$ ]] || die 'azure firewall replace-xtp-peers requires --resource-group, --nsg and valid --udp-port'
          ((udp_port >= 1 && udp_port <= 65535)) || die 'azure firewall --udp-port must be 1..65535'
          ((${#raw_sources[@]} > 0 && ${#udp_sources[@]} > 0)) || die 'azure firewall replace-xtp-peers requires raw and UDP peer source lists'
          if az network nsg rule show --resource-group "$rg" --nsg-name "$nsg" --name "$raw_rule" --output none --only-show-errors >/dev/null 2>&1; then
            az network nsg rule update --resource-group "$rg" --nsg-name "$nsg" --name "$raw_rule" --priority 250 --direction Inbound --access Allow --protocol '*' --source-address-prefixes "${raw_sources[@]}" --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges '*' --output none --only-show-errors
          else
            az network nsg rule create --resource-group "$rg" --nsg-name "$nsg" --name "$raw_rule" --priority 250 --direction Inbound --access Allow --protocol '*' --source-address-prefixes "${raw_sources[@]}" --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges '*' --description 'XTP raw36 peers; Azure NSG has no custom IP protocol selector' --output none --only-show-errors
          fi
          if az network nsg rule show --resource-group "$rg" --nsg-name "$nsg" --name "$udp_rule" --output none --only-show-errors >/dev/null 2>&1; then
            az network nsg rule update --resource-group "$rg" --nsg-name "$nsg" --name "$udp_rule" --priority 249 --direction Inbound --access Allow --protocol Udp --source-address-prefixes "${udp_sources[@]}" --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges "$udp_port" --output none --only-show-errors
          else
            az network nsg rule create --resource-group "$rg" --nsg-name "$nsg" --name "$udp_rule" --priority 249 --direction Inbound --access Allow --protocol Udp --source-address-prefixes "${udp_sources[@]}" --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges "$udp_port" --description 'XTP encapsulation from GCP peers on the commissioned port' --output none --only-show-errors
          fi
          printf 'Replaced Azure XTP ingress: raw peer sources=%s; UDP %s sources=%s\n' "${#raw_sources[@]}" "$udp_port" "${#udp_sources[@]}"
          ;;
        *) die 'azure firewall currently supports: list, set-sources, allow-xtp-peers, replace-xtp-peers';;
      esac
      ;;
    *) die "unsupported azure operation: $operation";;
  esac
}

ocictl() {
  need oci
  local region='' compartment='' instance='' security_list=''
  local -a sources=()
  case "$operation" in
    restart)
      while [[ $# -gt 0 ]]; do case "$1" in
        --region) region=$2; shift 2;; --compartment-id) compartment=$2; shift 2;; *) instance=$1; shift;; esac; done
      [[ -n $region && -n $compartment && -n $instance ]] || die 'oci restart requires --region, --compartment-id, INSTANCE_OCID'
      oci compute instance action --region "$region" --instance-id "$instance" --action SOFTRESET
      ;;
    firewall)
      case "${1:-}" in
        list)
          shift
          while [[ $# -gt 0 ]]; do case "$1" in
            --compartment-id) compartment=$2; shift 2;;
            --region) region=$2; shift 2;;
            *) die "unknown oci firewall list option: $1";;
          esac; done
          [[ -n $compartment ]] || die 'oci firewall list requires --compartment-id'
          local -a list_args=(network security-list list --compartment-id "$compartment" --all --output json)
          [[ -n $region ]] && list_args+=(--region "$region")
          oci "${list_args[@]}"
          ;;
        allow-xtp-peers)
          need jq
          shift
          while [[ $# -gt 0 ]]; do case "$1" in
            --security-list-id) security_list=$2; shift 2;;
            --source) sources+=("$2"); shift 2;;
            *) die "unknown oci firewall allow-xtp-peers option: $1";;
          esac; done
          [[ -n $security_list && ${#sources[@]} -gt 0 ]] || die 'oci firewall allow-xtp-peers requires --security-list-id and at least one --source CIDR'
          local sources_json rules_file
          sources_json=$(printf '%s\n' "${sources[@]}" | jq -R . | jq -s .)
          rules_file=$(mktemp /tmp/cloudctl-oci-ingress.XXXXXX.json)
          oci network security-list get --security-list-id "$security_list" --output json \
            | jq --argjson sources "$sources_json" '
                .data["ingress-security-rules"]
                | map(select(.description != "ED209 XTP peer qualification"))
                + [ $sources[] as $s |
                    {description:"ED209 XTP peer qualification",isStateless:false,protocol:"36",source:$s,sourceType:"CIDR_BLOCK"},
                    {description:"ED209 XTP peer qualification UDP test range",isStateless:false,protocol:"17",source:$s,sourceType:"CIDR_BLOCK",udpOptions:{destinationPortRange:{min:43601,max:43656}}}
                  ]' > "$rules_file"
          oci network security-list update --security-list-id "$security_list" --ingress-security-rules "file://$rules_file" --force --output json
          rm -f "$rules_file"
          ;;
        replace-xtp-peers)
          need jq
          local udp_port=62801
          local -a raw_sources=() udp_sources=()
          shift
          while [[ $# -gt 0 ]]; do case "$1" in
            --security-list-id) security_list=$2; shift 2;;
            --udp-port) udp_port=$2; shift 2;;
            --raw-source) raw_sources+=("$2"); shift 2;;
            --udp-source) udp_sources+=("$2"); shift 2;;
            *) die "unknown oci firewall replace-xtp-peers option: $1";;
          esac; done
          [[ -n $security_list && $udp_port =~ ^[0-9]+$ ]] || die 'oci firewall replace-xtp-peers requires --security-list-id and valid --udp-port'
          ((udp_port >= 1 && udp_port <= 65535)) || die 'oci firewall --udp-port must be 1..65535'
          ((${#raw_sources[@]} > 0 && ${#udp_sources[@]} > 0)) || die 'oci firewall replace-xtp-peers requires raw and UDP peer source lists'
          local raw_json udp_json rules_file
          raw_json=$(printf '%s\n' "${raw_sources[@]}" | jq -R . | jq -s .)
          udp_json=$(printf '%s\n' "${udp_sources[@]}" | jq -R . | jq -s .)
          rules_file=$(mktemp /tmp/cloudctl-oci-ingress.XXXXXX.json)
          chmod 600 "$rules_file"
          oci network security-list get --security-list-id "$security_list" --output json \
            | jq --argjson raw "$raw_json" --argjson udp "$udp_json" --argjson port "$udp_port" '
                .data["ingress-security-rules"]
                | map(select(.description != "ED209 XTP peer qualification" and .description != "ED209 XTP peer qualification UDP test range" and .description != "ED209 XTP raw36 peer" and .description != "ED209 XTP UDP commissioned port"))
                + ($raw | map({description:"ED209 XTP raw36 peer",isStateless:false,protocol:"36",source:.,sourceType:"CIDR_BLOCK"}))
                + ($udp | map({description:"ED209 XTP UDP commissioned port",isStateless:false,protocol:"17",source:.,sourceType:"CIDR_BLOCK",udpOptions:{destinationPortRange:{min:$port,max:$port}}}))' > "$rules_file"
          oci network security-list update --security-list-id "$security_list" --ingress-security-rules "file://$rules_file" --force --output json
          rm -f "$rules_file"
          printf 'Replaced OCI XTP ingress: raw peer sources=%s; UDP %s sources=%s\n' "${#raw_sources[@]}" "$udp_port" "${#udp_sources[@]}"
          ;;
        *) die 'oci firewall currently supports: list, allow-xtp-peers, replace-xtp-peers';;
      esac
      ;;
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
      id=${1:-}; [[ -n $id ]] || die 'vultr restart requires INSTANCE_ID or NODE_ALIAS'
      case "$id" in
        # Vultr node registry: ED209K, Frankfurt Debian free-year instance.
        ed209k) id=befff703-37ce-4f13-820a-98a5a75f4eaa;;
      esac
      curl -fsS -X POST "$base/instances/$id/reboot" -H "Authorization: Bearer $key" -H 'Accept: application/json'
      ;;
    firewall)
      [[ ${1:-} == list ]] || die 'vultr firewall currently supports: list'
      shift; id=${1:-}
      if [[ -n $id ]]; then
        curl -fsS "$base/firewalls/$id/rules" -H "Authorization: Bearer $key" -H 'Accept: application/json'
      else
        curl -fsS "$base/firewalls" -H "Authorization: Bearer $key" -H 'Accept: application/json'
      fi
      ;;
    *) die "unsupported vultr operation: $operation";;
  esac
}

case "$provider" in
  gcp) gcp "$@";; aws) awsctl "$@";; azure) azurectl "$@";; oci) ocictl "$@";; vultr) vultrctl "$@";; help|-h|--help) usage;; *) die "unknown provider: $provider";;
esac
