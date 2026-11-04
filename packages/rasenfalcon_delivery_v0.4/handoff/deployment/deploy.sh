#!/usr/bin/env bash
# RasenFalcon dogfood deployment controller v0.3
# Owned ooRexx/Alchemy service binaries ONLY. Never install an alternative MTA,
# IMAP server, directory daemon, reverse proxy, webmail, or MCP authority.
set -Eeuo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
RELEASE="${RF_RELEASE:-$ROOT/release}"
ROLE="${RF_ROLE:-}"
TEST_USER="${RF_TEST_USER:-}"

log(){ printf '[RasenFalcon %s] %s\n' "${ROLE:-unset}" "$*" >&2; }
die(){ log "ERROR: $*"; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || die "Missing prerequisite: $1"; }
require_root(){ [[ "$(id -u)" == 0 ]] || die 'Command requires root'; }
usage(){ cat <<'EOF'
RasenFalcon full-stack DOGFOOD release deployment v0.3

  RF_ROLE=ROLE RF_RELEASE=/path/to/reviewed-release ./deployment/deploy.sh COMMAND

Roles: gateway | office | noc | mcp | identity | public | all
Commands:
  preflight       Report prerequisites and host facts without mutation
  check-release   Validate file digests, per-role service units and real test inventory
  install         Install reviewed, hashed owned-component release (not activate)
  start           Start/enable our systemd services and run real readiness tests
  verify          Run real release readiness tests against live services
  accept          Run real FULL e2e and negative tests; record stdout as evidence
  deploy          install + start + verify (explicit approval required)
  status          Report declared unit state (not an acceptance claim)
  rollback PATH   Restore files from an exact installation backup

Requirements: a release must contain roles/ROLE/files, manifest.tsv, services.txt
and tests.tsv plus executable tests. The release and all tests are supplied by Codex
from accepted, build-verified owned service components; there are NO mock daemons.

Mandatory environment for mutation:
  RF_APPROVE_ACTIVATION=YES     approves start/deploy of reviewed release
  RF_TEST_USER=user            unprivileged account for protocol test execution

This controller does not install Postfix/Dovecot/slapd/Nginx, configure DNS,
issue certificates, invent SMTP/IMAP/LDAP listener implementations, open firewall
ports, alter live credentials or place secrets in source control. Those must be
provided by reviewed owned-component packages and operator approval.
EOF
}

validate_role(){
 [[ "$ROLE" =~ ^(gateway|office|noc|mcp|identity|public|all)$ ]] || die 'Set RF_ROLE to gateway, office, noc, mcp, identity, public or all'
 RDIR="$RELEASE/roles/$ROLE"
 MANIFEST="$RDIR/manifest.tsv"
 SERVICES="$RDIR/services.txt"
 TESTS="$RDIR/tests.tsv"
}

preflight(){
 validate_role
 [[ "$(uname -s)" == Linux ]] || die 'Linux systemd host required'
 need systemctl; need sha256sum; need install; need python3; need timeout
 log "Host=$(hostname) Role=$ROLE Release=$RDIR"
 if [[ -f /etc/os-release ]]; then . /etc/os-release; log "OS=${ID:-unknown}/${VERSION_ID:-unknown}"; fi
 log 'Running processes/listening ports (for human collision review):'
 if command -v ss >/dev/null; then ss -lnt | head -n 35 || true; else log '(ss unavailable)'; fi
 if command -v dig >/dev/null; then
   log 'Supplied NOC DNS CNAME and canonical A (not assumed healthy):'
   dig +short CNAME noc.rasenfalcon.com || true
   dig +short A london1.rasenfalcon.com || true
   log 'MX and gateway name:'
   dig +short MX rasenfalcon.com || true
   dig +short A gateway.rasenfalcon.com || true
 else log 'DNS client absent. External cutover DNS checks remain mandatory.'; fi
 log 'No changes made. Inspect target reachability and existing service collisions before installing.'
}

# Entire release is per-host-role. No service or file name may escape its role.
# Verify digest of every staged file and each executable protocol test.
manifest_dest_ok(){
 case "$1" in
  /opt/rasenfalcon/*|/etc/rasenfalcon/*|/var/www/rasenfalcon/*|/etc/systemd/system/rasenfalcon-*.service) return 0;;
  *) return 1;;
 esac
}
no_symlink_parents(){
 local path="$1" part cur=''
 [[ "$path" == /* ]] || return 1
 IFS='/' read -ra parts <<< "${path#/}"
 for part in "${parts[@]}"; do
  [[ -n "$part" ]] || continue
  cur+="/$part"
  [[ ! -L "$cur" ]] || return 1
 done
}
# Restrictive format intentionally disallows whitespace/newlines in source or destination.
valid_file_path(){ [[ "$1" =~ ^[A-Za-z0-9_./-]+$ && "$1" != /* && "$1" != *..* && "$1" != *//* ]]; }
valid_target_path(){ [[ "$1" =~ ^/[A-Za-z0-9_./-]+$ && "$1" != *..* && "$1" != *//* ]]; }
valid_mode(){ [[ "$1" =~ ^0?[0-7]{3}$ ]]; }
file_hash(){ sha256sum "$1" | cut -d' ' -f1; }

validate_manifest(){
 [[ -f "$MANIFEST" ]] || die "Missing $MANIFEST"
 local rel dst mode sha extr n=0
 declare -A dst_seen=()
 while IFS=$'\t' read -r rel dst mode sha extr || [[ -n "${rel:-}" ]]; do
  [[ -z "${rel:-}" || "${rel:0:1}" == '#' ]] && continue
  [[ -z "${extr:-}" ]] || die "Extra column in $MANIFEST"
  valid_file_path "$rel" || die "Bad source path: $rel"
  valid_target_path "$dst" || die "Bad destination path: $dst"
  manifest_dest_ok "$dst" || die "Destination not allowlisted: $dst"
  no_symlink_parents "$dst" || die "Symlink in destination path: $dst"
  valid_mode "$mode" || die "Bad mode for $rel"
  [[ "$sha" =~ ^[a-f0-9]{64}$ ]] || die "Bad sha256 for $rel"
  [[ -z "${dst_seen[$dst]:-}" ]] || die "Repeated destination: $dst"
  dst_seen["$dst"]=1
  [[ -f "$RDIR/files/$rel" && ! -L "$RDIR/files/$rel" ]] || die "Missing/nonregular file $rel"
  [[ "$(file_hash "$RDIR/files/$rel")" == "$sha" ]] || die "Hash mismatch: $rel"
  n=$((n+1))
 done < "$MANIFEST"
 ((n > 0)) || die 'Empty installation manifest'
 log "Verified $n shipped files"
}

# Required actual daemon families are role-specific. No Port 25/993 emulation.
required_units(){
 case "$ROLE" in
 gateway) printf '%s\n' rasenfalcon-https.service rasenfalcon-smtp.service rasenfalcon-imap.service rasenfalcon-wire-gateway.service rasenfalcon-terminal3270.service rasenfalcon-webrelay.service;;
 office) printf '%s\\n' rasenfalcon-office-https.service rasenfalcon-wire-office.service rasenfalcon-notnotes.service;;
 noc) printf '%s\\n' rasenfalcon-noc-https.service;;
 public) printf '%s\\n' rasenfalcon-https.service;;
 mcp) printf '%s\n' rasenfalcon-https.service rasenfalcon-mcp.service;;
 identity) printf '%s\n' rasenfalcon-ldap.service;;
 all) printf '%s\\n' rasenfalcon-https.service rasenfalcon-noc-https.service rasenfalcon-office-https.service rasenfalcon-smtp.service rasenfalcon-imap.service rasenfalcon-wire-office.service rasenfalcon-wire-gateway.service rasenfalcon-notnotes.service rasenfalcon-mcp.service rasenfalcon-ldap.service rasenfalcon-terminal3270.service rasenfalcon-webrelay.service;;
 esac
}
required_test_names(){
 # 'ready' and 'e2e' are distinct: process up != application operational.
 case "$ROLE" in
 gateway) printf '%s\n' 'ready:https_gateway' 'ready:smtp_listener' 'ready:imap_listener' 'ready:ldap_portal_auth' 'e2e:incoming_mail' 'e2e:outbound_submission' 'e2e:no_open_relay' 'e2e:gateway_ldap_denial' 'e2e:3270_ed209zz' 'e2e:3270_ed209z' 'e2e:web_ed209cray' 'e2e:web_ed209tops';;
 office) printf '%s\n' 'ready:https_office' 'ready:wire_mail' 'ready:wire_notnotes' 'e2e:office_mail_read_send' 'e2e:office_notnotes_revision' 'e2e:office_ldap_denial';;
 noc) printf '%s\n' 'ready:https_noc_alias' 'e2e:noc_cname_sni_host';;
 mcp) printf '%s\n' 'ready:https_mcp' 'ready:mcp_mail' 'ready:mcp_notnotes' 'e2e:agent_chatgpt_mail' 'e2e:agent_claude_mail' 'e2e:notnotes_acl_revision' 'e2e:mcp_denials';;
 identity) printf '%s\n' 'ready:ldap_bind' 'e2e:ldap_revoke' 'e2e:sign_verify_revoke';;
 public) printf '%s\n' 'ready:https_public' 'e2e:public_site_tls';;
 all) printf '%s\n' 'ready:https_gateway' 'ready:smtp_listener' 'ready:imap_listener' 'ready:ldap_bind' 'ready:wire_mail' 'ready:wire_notnotes' 'ready:mcp_mail' 'ready:mcp_notnotes' 'e2e:incoming_mail' 'e2e:no_open_relay' 'e2e:office_mail_read_send' 'e2e:office_notnotes_revision' 'e2e:agent_chatgpt_mail' 'e2e:agent_claude_mail' 'e2e:3270_ed209zz' 'e2e:3270_ed209z' 'e2e:web_ed209cray' 'e2e:web_ed209tops' 'e2e:noc_cname_sni_host' 'e2e:ldap_revoke' 'e2e:sign_verify_revoke';;
 esac
}

validate_services(){
 [[ -f "$SERVICES" ]] || die "Missing $SERVICES"
 local unit cnt=0
 declare -A got=()
 while IFS= read -r unit || [[ -n "${unit:-}" ]]; do
  [[ -z "$unit" || "${unit:0:1}" == '#' ]] && continue
  [[ "$unit" =~ ^rasenfalcon-[A-Za-z0-9_-]+\.service$ ]] || die "Non-RasenFalcon service listed: $unit"
  [[ -z "${got[$unit]:-}" ]] || die "Duplicate service: $unit"
  got["$unit"]=1
  grep -qF "$'	'" /dev/null 2>/dev/null || true  # harmless portability guard
  if ! awk -F '\t' -v dst="/etc/systemd/system/$unit" '$2 == dst { found=1 } END { exit !found }' "$MANIFEST"; then
   die "Unit must be staged by release manifest: $unit"
  fi
  cnt=$((cnt+1))
 done < "$SERVICES"
 local required
 while IFS= read -r required; do [[ -n "${got[$required]:-}" ]] || die "Required owned service missing: $required"; done < <(required_units)
 log "Verified $cnt declared owned systemd units"
}

validate_tests(){
 [[ -f "$TESTS" ]] || die "Missing $TESTS"
 local phase name rel sha extra cnt=0
 declare -A got=()
 while IFS=$'\t' read -r phase name rel sha extra || [[ -n "${phase:-}" ]]; do
  [[ -z "${phase:-}" || "${phase:0:1}" == '#' ]] && continue
  [[ -z "${extra:-}" ]] || die 'Extra test metadata'
  [[ "$phase" == ready || "$phase" == e2e ]] || die "Invalid test phase $phase"
  [[ "$name" =~ ^[a-z][a-z0-9_]+$ ]] || die "Bad test ID $name"
  valid_file_path "$rel" || die "Unsafe test path $rel"
  [[ "$rel" == tests/* ]] || die "Test outside tests/: $rel"
  [[ "$sha" =~ ^[a-f0-9]{64}$ ]] || die "Invalid test hash $rel"
  [[ -f "$RDIR/$rel" && ! -L "$RDIR/$rel" ]] || die "Missing test script $rel"
  [[ "$(file_hash "$RDIR/$rel")" == "$sha" ]] || die "Test hash mismatch: $rel"
  [[ -z "${got[$phase:$name]:-}" ]] || die "Duplicate test $phase:$name"
  got["$phase:$name"]=1
  cnt=$((cnt+1))
 done < "$TESTS"
 local req
 while IFS= read -r req; do [[ -n "${got[$req]:-}" ]] || die "Mandatory real test absent: $req"; done < <(required_test_names)
 log "Verified $cnt test scripts. Scripts must test LIVE owned protocol behaviour, not dummy success."
}
check_release(){ validate_role; need sha256sum; validate_manifest; validate_services; validate_tests; }

run_tests(){
 local phase="$1" ph name rel sha extra failed=0 count=0
 [[ -n "$TEST_USER" ]] || die 'RF_TEST_USER must be a nonprivileged test identity for live probes'
 [[ "$TEST_USER" != root ]] || die 'Refusing to run application tests as root'
 id "$TEST_USER" >/dev/null 2>&1 || die "Missing test user: $TEST_USER"
 need runuser; need timeout
 while IFS=$'\t' read -r ph name rel sha extra || [[ -n "${ph:-}" ]]; do
  [[ -z "${ph:-}" || "${ph:0:1}" == '#' || "$ph" != "$phase" ]] && continue
  count=$((count+1))
  log "TEST $phase/$name"
  if timeout --signal=TERM --kill-after=4s 90s runuser -u "$TEST_USER" -- /usr/bin/env bash "$RDIR/$rel" </dev/null; then
    log "PASS $phase/$name"
  else log "FAIL $phase/$name"; failed=1; fi
 done < "$TESTS"
 ((count > 0)) || die "No $phase tests"
 ((failed == 0)) || die "$phase protocol tests FAILED"
}

verify_units(){
 local unit failed=0
 while IFS= read -r unit || [[ -n "${unit:-}" ]]; do
  [[ -z "$unit" || "${unit:0:1}" == '#' ]] && continue
  if systemctl is-active --quiet "$unit"; then log "ACTIVE $unit"; else log "INACTIVE $unit"; failed=1; fi
 done < "$SERVICES"
 ((failed == 0)) || die 'Required owned services not all active'
}

verify(){ require_root; check_release; verify_units; run_tests ready; log 'READINESS verified. Run accept for real end-to-end acceptance.'; }
accept(){ require_root; check_release; verify_units; run_tests ready; run_tests e2e; log 'All declared role acceptance tests PASS; retain external evidence and operator approval for production cutover.'; }

install_release(){
 require_root; check_release
 [[ "${RF_APPROVE_INSTALL:-NO}" == YES ]] || die 'Set RF_APPROVE_INSTALL=YES after reviewing owned-component release and destinations'
 need cp; need systemctl; need mkdir; need date
 local backup="/var/backups/rasenfalcon/${ROLE}-$(date -u +%Y%m%dT%H%M%SZ)-$$"
 install -d -m 0700 "$backup/original"
 : > "$backup/created.list"
 cp -- "$MANIFEST" "$backup/manifest.tsv"
 cp -- "$SERVICES" "$backup/services.txt"
 local rel dst mode sha extra
 while IFS=$'\t' read -r rel dst mode sha extra || [[ -n "${rel:-}" ]]; do
  [[ -z "${rel:-}" || "${rel:0:1}" == '#' ]] && continue
  if [[ -f "$dst" ]]; then
    install -d -m 0700 "$backup/original$(dirname "$dst")"
    cp -p -- "$dst" "$backup/original$dst"
  elif [[ -e "$dst" ]]; then die "Destination is not a regular file: $dst"
  else printf '%s\n' "$dst" >> "$backup/created.list"; fi
 done < "$MANIFEST"
 log "Recovery copy: $backup"
 local failed=0
 while IFS=$'\t' read -r rel dst mode sha extra || [[ -n "${rel:-}" ]]; do
  [[ -z "${rel:-}" || "${rel:0:1}" == '#' ]] && continue
  if ! install -D -m "$mode" -- "$RDIR/files/$rel" "$dst"; then failed=1; break; fi
 done < "$MANIFEST"
 if ((failed)); then restore_backup "$backup"; die 'Install aborted; previous file content restored'; fi
 if ! systemctl daemon-reload; then restore_backup "$backup"; die 'systemd reload failed; restored previous files'; fi
 log 'Installed pinned owned components (NOT yet activated).'
 log "Record backup path for explicit rollback: $backup"
}

restore_backup(){
 local backup="$1" dst src
 [[ -f "$backup/manifest.tsv" && -f "$backup/created.list" ]] || die 'Invalid backup directory'
 while IFS= read -r dst || [[ -n "${dst:-}" ]]; do
  [[ -n "$dst" ]] || continue
  [[ "$dst" =~ ^/[A-Za-z0-9_./-]+$ ]] || die 'Unsafe saved destination'
  [[ -f "$backup/original$dst" ]] || rm -f -- "$dst"
 done < "$backup/created.list"
 # Only restore known manifest destinations, not arbitrary files.
 local rel mode sha extr
 while IFS=$'\t' read -r rel dst mode sha extr || [[ -n "${rel:-}" ]]; do
  [[ -z "${rel:-}" || "${rel:0:1}" == '#' ]] && continue
  if [[ -f "$backup/original$dst" ]]; then
    manifest_dest_ok "$dst" || die "Backup destination outside allowlist: $dst"
    no_symlink_parents "$dst" || die "Unsafe destination path: $dst"
    install -D -m "$mode" -- "$backup/original$dst" "$dst"
  fi
 done < "$backup/manifest.tsv"
 systemctl daemon-reload
 log "Restored file snapshot $backup; service restart/re-verification is required."
}
rollback(){ require_root; [[ $# == 1 ]] || die 'rollback requires exact backup directory path'; restore_backup "$1"; }

start_services(){
 require_root; check_release
 [[ "${RF_APPROVE_ACTIVATION:-NO}" == YES ]] || die 'Set RF_APPROVE_ACTIVATION=YES to start services'
 local unit
 while IFS= read -r unit || [[ -n "${unit:-}" ]]; do
  [[ -z "$unit" || "${unit:0:1}" == '#' ]] && continue
  systemctl enable --now "$unit" || die "Failed starting owned service $unit"
 done < "$SERVICES"
 verify
 log 'Ready tests passed. Real e2e tests still require accept; no automatic PUBLIC GO-LIVE claim.'
}

status(){ validate_role; [[ -f "$SERVICES" ]] || die 'No services file'; local unit
 while IFS= read -r unit || [[ -n "${unit:-}" ]]; do
  [[ -z "$unit" || "${unit:0:1}" == '#' ]] && continue
  printf '%-46s %s\n' "$unit" "$(systemctl is-active "$unit" 2>/dev/null || true)"
 done < "$SERVICES"
}

command="${1:---help}"
case "$command" in
 help|-h|--help) usage;;
 preflight) preflight;;
 check-release) check_release;;
 install) install_release;;
 start) start_services;;
 verify) verify;;
 accept) accept;;
 deploy) [[ "${RF_APPROVE_ACTIVATION:-NO}" == YES ]] || die 'Approval required for combined deploy'; install_release; start_services;;
 status) status;;
 rollback) validate_role; shift; rollback "$@";;
 *) usage; die "Unknown command: $command";;
esac
