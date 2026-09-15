#!/usr/bin/env bash
set -euo pipefail

QB_ROOT="${QUEUEREXX_QUEUEBASH_144_ROOT:?set QUEUEREXX_QUEUEBASH_144_ROOT}"
QR_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

qroot="$tmp/qroot"
shared="$tmp/shared-policies"
mkdir -p "$shared/class-statement"

export QUEUEBASH_ROOT="$qroot"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_SHARED_POLICY_ROOT="$shared"
export QUEUEREXX_QUEUEBASH_SOURCE="$QB_ROOT/queuebash.sh"

# Exact QueueBash 0.18.144 creates the authoritative records.
# shellcheck source=/dev/null
source "$QB_ROOT/queuebash.sh" >/dev/null

allow_out="$(queue submit policy-allow --runner direct -- /bin/echo allowed)"
allow_qid="$(printf '%s\n' "$allow_out" | awk '/^Submitted /{print $2; exit}')"
auth_out="$(queue submit policy-authorised --runner direct -- /bin/true)"
auth_qid="$(printf '%s\n' "$auth_out" | awk '/^Submitted /{print $2; exit}')"
block_out="$(queue submit policy-block --runner direct -- /bin/false)"
block_qid="$(printf '%s\n' "$block_out" | awk '/^Submitted /{print $2; exit}')"
[[ -n "$allow_qid" && -n "$auth_qid" && -n "$block_qid" ]]

cat > "$shared/class-statement/default.env" <<'EOF'
CLASS_POLICY_BLOCK_COMMAND_WORDS="/bin/true /bin/false"
CLASS_POLICY_BLOCK_COMMAND_REQUIRE="authorisation"
EOF

# Before an authorisation exists, the /bin/true job is denied.
set +e
pre_auth_json="$("$QR_ROOT/bin/queuerexx" policy-check "$auth_qid" --json)"
pre_auth_rc=$?
set -e
[[ "$pre_auth_rc" -eq 1 ]]
python3 - "$pre_auth_json" <<'PY'
import json,sys
d=json.loads(sys.argv[1])
assert d["allowed"] is False and d["decision"]=="deny",d
print("PASS blocked command is denied before command-bound authorisation exists")
PY

# QueueBash itself creates the command-bound authorisation.  The QueueRexx
# provider must consume QueueBash's on-file validation semantics, not reimplement
# them or treat a free-form reason as authority.
current_user="$(id -un)"
auth_gen="$(queue authorisation generate --admin queuerexx-dev11 --user "$current_user" -- /bin/true)"
auth_code="$(printf '%s\n' "$auth_gen" | awk '/^authorisation:/{print $2; exit}')"
[[ -n "$auth_code" ]]

# Read-only policy inspection must use the exact QueueBash gate but must not
# append exemptions or otherwise alter the authoritative record.
block_file="$(find "$qroot/pending" -type f -name "$block_qid.job" -print -quit)"
before="$(sha256sum "$block_file" | awk '{print $1}')"
set +e
policy_json="$("$QR_ROOT/bin/queuerexx" policy-check "$block_qid" --json)"
policy_rc=$?
set -e
[[ "$policy_rc" -eq 1 ]]
after="$(sha256sum "$block_file" | awk '{print $1}')"
[[ "$before" == "$after" ]]
python3 - "$policy_json" <<'PY'
import json,sys
d=json.loads(sys.argv[1])
assert d["schema"]=="queuerexx.policy_assessment.v1",d
assert d["allowed"] is False,d
assert d["decision"]=="deny",d
assert d["code"]=="QUEUEBASH_EXECUTION_POLICY_DENIED",d
assert d["provider"]=="queuebash.class-policy",d
assert d["evidence"]["authoritative_record_mutated"] is False,d
print("PASS read-only policy-check mirrors QueueBash deny without mutating the job record")
PY

allow_json="$("$QR_ROOT/bin/queuerexx" policy-check "$allow_qid" --json)"
auth_json="$("$QR_ROOT/bin/queuerexx" policy-check "$auth_qid" --json)"
python3 - "$allow_json" "$auth_json" <<'PY'
import json,sys
allow=json.loads(sys.argv[1]); auth=json.loads(sys.argv[2])
assert allow["allowed"] is True and allow["code"]=="QUEUEBASH_EXECUTION_POLICY_ALLOWED",allow
assert auth["allowed"] is True and auth["code"]=="QUEUEBASH_EXECUTION_POLICY_ALLOWED",auth
print("PASS QueueBash allow and on-file command-bound authorisation are honoured")
PY

# QueueRexx worker admission consumes the same provider verdict. The provider
# itself never moves state; QueueTransitionService owns running/pol_blocked.
rexx "$QR_ROOT/tests/test_queuebash_policy_provider.rex" "$qroot" "$QB_ROOT/queuebash.sh" "$allow_qid" "$auth_qid" "$block_qid"

qb_json="$(queue list --json)"
python3 - "$allow_qid" "$auth_qid" "$block_qid" "$qb_json" <<'PY'
import json,sys
allow,auth,block=sys.argv[1:4]
d=json.loads(sys.argv[4])
by={j["qid"]:j for j in d.get("jobs",[])}
assert by[allow]["state"]=="running",by.get(allow)
assert by[auth]["state"]=="running",by.get(auth)
assert by[block]["state"]=="pol_blocked",by.get(block)
print("PASS QueueBash sees QueueRexx policy allow/authorised as running and deny as pol_blocked")
PY

# Duplicate authority must fail closed before provider execution.
cp "$qroot/running/$allow_qid.job" "$qroot/done/$allow_qid.job"
set +e
amb_json="$("$QR_ROOT/bin/queuerexx" policy-check "$allow_qid" --json)"
amb_rc=$?
set -e
[[ "$amb_rc" -eq 1 ]]
python3 - "$amb_json" <<'PY'
import json,sys
d=json.loads(sys.argv[1])
assert d["decision"]=="error",d
assert d["code"]=="QUEUE_STATE_AMBIGUOUS",d
assert d["evidence"]["record_count"]==2,d
print("PASS duplicate QID policy inspection fails closed before policy authority is consulted")
PY
