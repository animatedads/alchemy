#!/usr/bin/env bash
set -euo pipefail

# Alchemy Cloud Control v0.1-dev3 resource transport.
# API authority: alchemy.cloud-control/0.1 RESOURCE.
# Provider credentials remain in provider-native configuration/identity stores.

fail() { echo "cloudctl: $*" >&2; exit 2; }
need() { command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"; }
need_value() { [[ $# -ge 2 && -n ${2:-} ]] || fail "$1 requires a value"; }

usage() {
  cat >&2 <<'USAGE'
Usage:
  cloudctl PROVIDER machine list [CONTEXT...]
  cloudctl PROVIDER machine start|stop|reboot|destroy --machine HANDLE [CONTEXT...]
  cloudctl PROVIDER machine create --name NAME --size SIZE [provider creation fields...]
  cloudctl PROVIDER firewall list --scope SCOPE [CONTEXT...]
  cloudctl PROVIDER firewall allow --scope SCOPE --protocol PROTO --source CIDR [--port PORT] [--rule NAME]
  cloudctl PROVIDER firewall revoke --scope SCOPE --rule RULE_ID_OR_NAME [CONTEXT...]

Providers: azure, gcp, aws, oci, vultr

GCP requires explicit --account animated-ads-cy|bashqueue.  Credentials are not
accepted as command options.  This transport does not perform human confirmation;
callers such as ooRexx Cloud Console own PLAN/APPLY confirmation and pass only an
already-authorized operation here.
USAGE
  exit 2
}

[[ $# -ge 3 ]] || usage
provider=${1,,}; noun=${2,,}; action=${3,,}; shift 3
case "$provider" in azure|gcp|aws|oci|vultr) ;; *) fail "unknown provider: $provider";; esac
case "$noun" in machine|firewall) ;; *) fail "unknown resource kind: $noun";; esac

machine='' name='' region='' zone='' project='' account='' configuration=''
group='' subscription='' scope='' rule='' protocol='' port='' source=''
description='' priority='3000' compartment='' availability_domain=''
subnet='' network='' image='' image_family='' image_project='' size='' security_group=''
key_name='' admin_user='' ssh_key='' os='' ssh_keys='' firewall_group='' tags=''
aws_profile='' oci_profile='' oci_auth='' vultr_config=''

while [[ $# -gt 0 ]]; do
  key=$1; shift
  case "$key" in
    --machine|--name|--region|--zone|--project|--account|--configuration|--group|--subscription|--scope|--rule|--protocol|--port|--source|--description|--priority|--compartment|--availability-domain|--subnet|--network|--image|--image-family|--image-project|--size|--security-group|--key-name|--admin-user|--ssh-key|--os|--ssh-keys|--firewall-group|--tags|--aws-profile|--oci-profile|--oci-auth|--vultr-config)
      [[ $# -gt 0 ]] || fail "$key requires a value"
      value=$1; shift
      ;;
    --password|--secret|--token|--api-key|--apikey)
      fail "secret-bearing option is forbidden: $key"
      ;;
    *) fail "unknown option: $key";;
  esac
  case "$key" in
    --machine) machine=$value;; --name) name=$value;; --region) region=$value;; --zone) zone=$value;;
    --project) project=$value;; --account) account=$value;; --configuration) configuration=$value;;
    --group) group=$value;; --subscription) subscription=$value;; --scope) scope=$value;; --rule) rule=$value;;
    --protocol) protocol=$value;; --port) port=$value;; --source) source=$value;; --description) description=$value;;
    --priority) priority=$value;; --compartment) compartment=$value;; --availability-domain) availability_domain=$value;;
    --subnet) subnet=$value;; --network) network=$value;; --image) image=$value;; --image-family) image_family=$value;; --image-project) image_project=$value;;
    --size) size=$value;; --security-group) security_group=$value;; --key-name) key_name=$value;; --admin-user) admin_user=$value;;
    --ssh-key) ssh_key=$value;; --os) os=$value;; --ssh-keys) ssh_keys=$value;; --firewall-group) firewall_group=$value;;
    --tags) tags=$value;; --aws-profile) aws_profile=$value;; --oci-profile) oci_profile=$value;; --oci-auth) oci_auth=$value;;
    --vultr-config) vultr_config=$value;;
  esac
done

add() { local -n a=$1; local flag=$2 val=$3; if [[ -n $val ]]; then a+=("$flag" "$val"); fi; return 0; }
split_scope() { [[ $scope == *:* ]] || fail "$provider firewall --scope must be GROUP:NAME"; scope_a=${scope%%:*}; scope_b=${scope#*:}; [[ -n $scope_a && -n $scope_b ]] || fail "invalid --scope: $scope"; }
split_gcp_machine() { if [[ $machine == */* && -z $zone ]]; then zone=${machine%%/*}; machine=${machine#*/}; fi; }

azure() {
  need az
  local -a cmd
  case "$noun:$action" in
    machine:list)
      cmd=(az vm list --show-details --output json --only-show-errors); add cmd --subscription "$subscription"; add cmd --resource-group "$group";;
    machine:start|machine:stop|machine:reboot|machine:destroy)
      [[ -n $machine ]] || fail "azure machine $action requires --machine"
      case "$action" in start) verb=start;; stop) verb=deallocate;; reboot) verb=restart;; destroy) verb=delete;; esac
      cmd=(az vm "$verb" --ids "$machine" --only-show-errors); [[ $action == destroy ]] && cmd+=(--yes); add cmd --subscription "$subscription";;
    machine:create)
      [[ -n $group && -n $name && -n $image && -n $size ]] || fail 'azure machine create requires --group --name --image --size'
      cmd=(az vm create --resource-group "$group" --name "$name" --image "$image" --size "$size" --only-show-errors)
      add cmd --location "$region"; add cmd --zone "$zone"; add cmd --admin-username "$admin_user"; add cmd --ssh-key-values "$ssh_key"; add cmd --nsg "$security_group"; add cmd --subscription "$subscription";;
    firewall:list)
      split_scope; cmd=(az network nsg rule list --resource-group "$scope_a" --nsg-name "$scope_b" --output json --only-show-errors); add cmd --subscription "$subscription";;
    firewall:allow)
      split_scope; [[ -n $rule && -n $protocol && -n $port && -n $source ]] || fail 'azure firewall allow requires --scope --rule --protocol --port --source'
      cmd=(az network nsg rule create --resource-group "$scope_a" --nsg-name "$scope_b" --name "$rule" --priority "$priority" --access Allow --direction Inbound --protocol "$protocol" --source-address-prefixes "$source" --destination-port-ranges "$port" --only-show-errors); add cmd --description "$description"; add cmd --subscription "$subscription";;
    firewall:revoke)
      split_scope; [[ -n $rule ]] || fail 'azure firewall revoke requires --rule'
      cmd=(az network nsg rule delete --resource-group "$scope_a" --nsg-name "$scope_b" --name "$rule" --only-show-errors); add cmd --subscription "$subscription";;
    *) fail "unsupported azure action: $noun $action";;
  esac
  exec "${cmd[@]}"
}

gcp() {
  [[ -n $account ]] || account=$configuration
  case "$account" in animated-ads-cy|bashqueue) ;; '') fail 'gcp operations require explicit --account animated-ads-cy|bashqueue';; *) fail "unsupported gcloud account configuration: $account";; esac
  wrapper=${ALCHEMY_GCLOUD_ACCOUNT_WRAPPER:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/gcloud-account.sh}
  [[ -x $wrapper ]] || fail "gcloud account wrapper not found: $wrapper"
  local -a cmd=("$wrapper" "$account")
  case "$noun:$action" in
    machine:list)
      cmd+=(compute instances list --format=json --quiet); add cmd --project "$project";;
    machine:start|machine:stop|machine:reboot|machine:destroy)
      [[ -n $machine ]] || fail "gcp machine $action requires --machine"; split_gcp_machine; [[ -n $zone ]] || fail "gcp machine $action requires --zone or zone/name handle"
      case "$action" in start) verb=start;; stop) verb=stop;; reboot) verb=reset;; destroy) verb=delete;; esac
      cmd+=(compute instances "$verb" "$machine" --zone "$zone" --quiet); add cmd --project "$project";;
    machine:create)
      [[ -n $name && -n $zone && -n $size ]] || fail 'gcp machine create requires --name --zone --size'
      [[ -n $image || -n $image_family ]] || fail 'gcp machine create requires --image or --image-family'
      cmd+=(compute instances create "$name" --zone "$zone" --machine-type "$size" --quiet); add cmd --image "$image"; add cmd --image-family "$image_family"; add cmd --image-project "$image_project"; add cmd --network "$network"; add cmd --subnet "$subnet"; add cmd --tags "$tags"; add cmd --project "$project";;
    firewall:list)
      [[ -n $scope ]] || fail 'gcp firewall list requires --scope network'; cmd+=(compute firewall-rules list --format=json --filter="network:$scope" --quiet); add cmd --project "$project";;
    firewall:allow)
      [[ -n $scope && -n $rule && -n $protocol && -n $port && -n $source ]] || fail 'gcp firewall allow requires --scope --rule --protocol --port --source'
      cmd+=(compute firewall-rules create "$rule" --network "$scope" --direction INGRESS --action ALLOW --rules "$protocol:$port" --source-ranges "$source" --quiet); add cmd --description "$description"; add cmd --project "$project";;
    firewall:revoke)
      [[ -n $rule ]] || fail 'gcp firewall revoke requires --rule'; cmd+=(compute firewall-rules delete "$rule" --quiet); add cmd --project "$project";;
    *) fail "unsupported gcp action: $noun $action";;
  esac
  exec "${cmd[@]}"
}

awsctl() {
  need aws
  local -a cmd
  case "$noun:$action" in
    machine:list) cmd=(aws ec2 describe-instances --output json);;
    machine:start|machine:stop|machine:reboot|machine:destroy)
      [[ -n $machine ]] || fail "aws machine $action requires --machine"
      case "$action" in start) verb=start-instances;; stop) verb=stop-instances;; reboot) verb=reboot-instances;; destroy) verb=terminate-instances;; esac
      cmd=(aws ec2 "$verb" --instance-ids "$machine" --output json);;
    machine:create)
      [[ -n $name && -n $image && -n $size ]] || fail 'aws machine create requires --name --image --size'
      cmd=(aws ec2 run-instances --image-id "$image" --instance-type "$size" --min-count 1 --max-count 1 --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$name}]" --output json); add cmd --subnet-id "$subnet"; add cmd --security-group-ids "$security_group"; add cmd --key-name "$key_name";;
    firewall:list)
      [[ -n $scope ]] || fail 'aws firewall list requires --scope security-group-id'; cmd=(aws ec2 describe-security-group-rules --filters "Name=group-id,Values=$scope" --output json);;
    firewall:allow)
      [[ -n $scope && -n $protocol && -n $port && -n $source ]] || fail 'aws firewall allow requires --scope --protocol --port --source'; cmd=(aws ec2 authorize-security-group-ingress --group-id "$scope" --protocol "$protocol" --port "$port" --cidr "$source" --output json); add cmd --tag-specifications "$description";;
    firewall:revoke)
      [[ -n $scope && -n $rule ]] || fail 'aws firewall revoke requires --scope --rule'; cmd=(aws ec2 revoke-security-group-ingress --group-id "$scope" --security-group-rule-ids "$rule" --output json);;
    *) fail "unsupported aws action: $noun $action";;
  esac
  add cmd --region "$region"; add cmd --profile "$aws_profile"; cmd+=(--no-cli-pager); exec "${cmd[@]}"
}

ocictl() {
  need oci
  local -a cmd
  case "$noun:$action" in
    machine:list)
      [[ -n $compartment ]] || fail 'oci machine list requires --compartment'; cmd=(oci compute instance list --compartment-id "$compartment" --all --output json);;
    machine:start|machine:stop|machine:reboot)
      [[ -n $machine ]] || fail "oci machine $action requires --machine"; case "$action" in start) verb=START;; stop) verb=SOFTSTOP;; reboot) verb=SOFTRESET;; esac; cmd=(oci compute instance action --instance-id "$machine" --action "$verb");;
    machine:destroy)
      [[ -n $machine ]] || fail 'oci machine destroy requires --machine'; cmd=(oci compute instance terminate --instance-id "$machine" --force);;
    machine:create)
      [[ -n $compartment && -n $availability_domain && -n $subnet && -n $image && -n $size && -n $name ]] || fail 'oci machine create requires --compartment --availability-domain --subnet --image --size --name'
      cmd=(oci compute instance launch --compartment-id "$compartment" --availability-domain "$availability_domain" --subnet-id "$subnet" --image-id "$image" --shape "$size" --display-name "$name"); add cmd --ssh-authorized-keys-file "$ssh_key";;
    firewall:list)
      [[ -n $scope ]] || fail 'oci firewall list requires --scope NSG_OCID'; cmd=(oci network nsg rules list --nsg-id "$scope" --all --output json);;
    firewall:allow)
      [[ -n $scope && -n $protocol && -n $source ]] || fail 'oci firewall allow requires --scope --protocol --source'
      case "${protocol,,}" in tcp) p=6;; udp) p=17;; icmp) p=1;; all) p=all;; *) fail 'oci protocol must be tcp, udp, icmp or all';; esac
      desc=${description:-${rule:-cloudctl rule}}; json="[{\"direction\":\"INGRESS\",\"protocol\":\"$p\",\"source\":\"$source\",\"sourceType\":\"CIDR_BLOCK\",\"description\":$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$desc")"
      if [[ ${protocol,,} == tcp || ${protocol,,} == udp ]]; then [[ -n $port ]] || fail 'oci tcp/udp allow requires --port'; opt="${protocol,,}Options"; json+=",\"$opt\":{\"destinationPortRange\":{\"min\":$port,\"max\":$port}}"; fi
      json+='}]'; cmd=(oci network nsg rules add --nsg-id "$scope" --security-rules "$json");;
    firewall:revoke)
      [[ -n $scope && -n $rule ]] || fail 'oci firewall revoke requires --scope --rule'; cmd=(oci network nsg rules remove --nsg-id "$scope" --security-rule-ids "[\"$rule\"]" --force);;
    *) fail "unsupported oci action: $noun $action";;
  esac
  add cmd --profile "$oci_profile"; add cmd --region "$region"; add cmd --auth "$oci_auth"; exec "${cmd[@]}"
}

vultr() {
  need vultr-cli
  local -a cmd
  case "$noun:$action" in
    machine:list) cmd=(vultr-cli instance list --output json);;
    machine:start|machine:stop|machine:reboot|machine:destroy)
      [[ -n $machine ]] || fail "vultr machine $action requires --machine"; case "$action" in start) verb=start;; stop) verb=stop;; reboot) verb=restart;; destroy) verb=delete;; esac; cmd=(vultr-cli instance "$verb" "$machine" --output json);;
    machine:create)
      [[ -n $name && -n $region && -n $size ]] || fail 'vultr machine create requires --name --region --size'; [[ -n $os || -n $image ]] || fail 'vultr machine create requires --os or --image'
      cmd=(vultr-cli instance create --region "$region" --plan "$size" --label "$name" --output json); add cmd --os "$os"; add cmd --image "$image"; add cmd --ssh-keys "$ssh_keys"; add cmd --firewall-group "$firewall_group"; add cmd --tags "$tags";;
    firewall:list) [[ -n $scope ]] || fail 'vultr firewall list requires --scope firewall-group-id'; cmd=(vultr-cli firewall rule list "$scope" --output json);;
    firewall:allow)
      [[ -n $scope && -n $protocol && -n $source ]] || fail 'vultr firewall allow requires --scope --protocol --source'; addr=${source%/*}; bits=${source#*/}; [[ $addr != "$source" ]] || fail 'vultr firewall source must be CIDR'; [[ $addr == *:* ]] && iptype=v6 || iptype=v4
      cmd=(vultr-cli firewall rule create --id "$scope" --ip-type "$iptype" --protocol "$protocol" --subnet "$addr" --size "$bits" --output json); add cmd --port "$port"; add cmd --notes "${description:-$rule}";;
    firewall:revoke) [[ -n $scope && -n $rule ]] || fail 'vultr firewall revoke requires --scope --rule'; cmd=(vultr-cli firewall rule delete "$scope" "$rule" --output json);;
    *) fail "unsupported vultr action: $noun $action";;
  esac
  add cmd --config "$vultr_config"; exec "${cmd[@]}"
}

case "$provider" in azure) azure;; gcp) gcp;; aws) awsctl;; oci) ocictl;; vultr) vultr;; esac
