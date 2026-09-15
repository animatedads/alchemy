#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
OOREXX_BIN=${OOREXX_BIN:-}
NOSQL_SRC=${NOSQL_SRC:-}
RUNTIME_REGISTRY_SRC=${RUNTIME_REGISTRY_SRC:-}
CRYPTO_SRC=${CRYPTO_SRC:-${OOREXX_CRYPTO_SRC:-}}
ALCHEMY_OBJECTS_SRC=${ALCHEMY_OBJECTS_SRC:-${ALCHEMY_SRC:-}}
WLU_SRC=${WLU_SRC:-}
QF_V082_SRC=${QF_V082_SRC:-}
MODE=${1:-all}

if [[ -n "$OOREXX_BIN" ]]; then
  export PATH="$OOREXX_BIN:$PATH"
  OOREXX_LIB=$(cd "$OOREXX_BIN/../lib" 2>/dev/null && pwd || true)
  if [[ -n "$OOREXX_LIB" ]]; then
    export LD_LIBRARY_PATH="$OOREXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  fi
fi

if ! command -v rexx >/dev/null 2>&1; then
  echo "rexx not found; set OOREXX_BIN to the ooRexx bin directory" >&2
  exit 2
fi

need_crypto=0
need_nosql=0
need_registry=0
need_alchemy=0
need_wlu=0
need_v082=0
case "$MODE" in
  style) ;;
  compile) need_crypto=1; need_nosql=1; need_alchemy=1; need_wlu=1 ;;
  core) need_crypto=1; need_nosql=1; need_alchemy=1 ;;
  topics|distributed-topics) need_crypto=1; need_nosql=1; need_alchemy=1 ;;
  transport|transport-core) need_crypto=1; need_nosql=1; need_alchemy=1 ;;
  socket-transport|socket-security|socket-health) need_crypto=1; need_alchemy=1 ;;
  service) need_crypto=1; need_nosql=1; need_alchemy=1; need_wlu=1 ;;
  registry) need_crypto=1; need_registry=1; need_alchemy=1 ;;
  wlu) need_crypto=1; need_nosql=1; need_alchemy=1; need_wlu=1 ;;
  release-boundary) need_crypto=1; need_alchemy=1 ;;
  compatibility|compat-v082-v09|compat-v09-v082) need_v082=1; need_alchemy=1 ;;
  compat-v082-v09-auth|compat-v09-v082-auth) need_v082=1; need_crypto=1; need_alchemy=1 ;;
  crypto|crypto-known-answer|crypto-hmac|crypto-checkpoint|crypto-rotation|crypto-recovery|crypto-keyring|crypto-uow|crypto-channel|crypto-topic|crypto-distributed-topic) need_crypto=1; need_alchemy=1 ;;
  all) need_crypto=1; need_nosql=1; need_registry=1; need_alchemy=1; need_wlu=1; need_v082=1 ;;
  *)
    echo "usage: $0 [style|compile|core|topics|distributed-topics|transport|transport-core|socket-transport|socket-security|socket-health|service|registry|wlu|release-boundary|compatibility|compat-v082-v09|compat-v082-v09-auth|compat-v09-v082|compat-v09-v082-auth|crypto|crypto-known-answer|crypto-hmac|crypto-checkpoint|crypto-rotation|crypto-recovery|crypto-keyring|crypto-uow|crypto-channel|crypto-topic|crypto-distributed-topic|all]" >&2
    exit 2
    ;;
esac

if (( need_crypto )); then
  if [[ -z "$CRYPTO_SRC" || ! -f "$CRYPTO_SRC/crypto.cls" ]]; then
    echo "set CRYPTO_SRC to the standalone oorexx_crypto_v0.1 src directory" >&2
    exit 2
  fi
fi
if (( need_nosql )); then
  if [[ -z "$NOSQL_SRC" || ! -f "$NOSQL_SRC/NoSQLServer.cls" ]]; then
    echo "set NOSQL_SRC to the NoSQLServer v0.77 src directory" >&2
    exit 2
  fi
fi
if (( need_registry )); then
  if [[ -z "$RUNTIME_REGISTRY_SRC" || ! -f "$RUNTIME_REGISTRY_SRC/RuntimeRegistry.cls" ]]; then
    echo "set RUNTIME_REGISTRY_SRC to the Runtime Registry v0.12 src directory" >&2
    exit 2
  fi
fi
if (( need_alchemy )); then
  if [[ -z "$ALCHEMY_OBJECTS_SRC" || ! -f "$ALCHEMY_OBJECTS_SRC/AlchemyObject.cls" ]]; then
    echo "set ALCHEMY_OBJECTS_SRC (or ALCHEMY_SRC) to the Alchemy Objects v0.5 src directory" >&2
    exit 2
  fi
fi
if (( need_wlu )); then
  if [[ -z "$WLU_SRC" || ! -f "$WLU_SRC/WorkLoadUnits.cls" ]]; then
    echo "set WLU_SRC to the Work Load Units v0.6 src directory" >&2
    exit 2
  fi
fi
if (( need_v082 )); then
  if [[ -z "$QF_V082_SRC" || ! -f "$QF_V082_SRC/ObjectQueueFabric.cls" ]]; then
    echo "set QF_V082_SRC to the accepted Queue Fabric v0.8.2 src directory" >&2
    exit 2
  fi
fi

if [[ -n "$OOREXX_BIN" ]]; then
  OOREXX_CLASS_DIR="$OOREXX_BIN"
else
  OOREXX_CLASS_DIR=$(dirname "$(command -v rexx)")
fi

parts=("$ROOT/src")
[[ -n "$CRYPTO_SRC" ]] && parts+=("$CRYPTO_SRC")
[[ -n "$NOSQL_SRC" ]] && parts+=("$NOSQL_SRC")
[[ -n "$RUNTIME_REGISTRY_SRC" ]] && parts+=("$RUNTIME_REGISTRY_SRC")
[[ -n "$ALCHEMY_OBJECTS_SRC" ]] && parts+=("$ALCHEMY_OBJECTS_SRC")
[[ -n "$WLU_SRC" ]] && parts+=("$WLU_SRC")
parts+=("$OOREXX_CLASS_DIR")
REXX_PATH_JOINED=$(IFS=:; echo "${parts[*]}")
export REXX_PATH="$REXX_PATH_JOINED${REXX_PATH:+:$REXX_PATH}"

run_rexx_fixture() {
  local fixture=$1
  local work
  work=$(mktemp -d)
  cp -R "$ROOT/tests" "$work/tests"
  (
    cd "$work/tests"
    rexx "$fixture"
  )
  rm -rf "$work"
}

run_style() {
  bash "$ROOT/tests/test_oorexx_message_style.sh"
}

run_compile() {
  local work source
  if ! command -v rexxc >/dev/null 2>&1; then
    echo "rexxc not found; source compile cannot run" >&2
    exit 2
  fi
  work=$(mktemp -d)
  trap 'rm -rf "$work"' RETURN
  for source in "$ROOT"/src/*.cls; do
    echo "COMPILE $(basename "$source")"
    TERM=dumb rexxc "$source" "$work/$(basename "$source").orx" >/dev/null
  done
  rm -rf "$work"
  trap - RETURN
  echo "OBJECT QUEUE FABRIC V0.9-dev5 SOURCE COMPILE: OK"
}

run_core() {
  local work
  work=$(mktemp -d)
  cp -R "$ROOT/tests" "$work/tests"
  (
    cd "$work/tests"
    rexx test_queue_fabric.rex
    rexx test_queue_adversarial.rex
    rexx test_queue_concurrency.rex
    rexx test_queue_mq_semantics.rex
    rexx test_queue_mq_nosql.rex
    rexx test_queue_channels.rex
    rexx test_queue_channel_nosql.rex
    rexx test_queue_topics.rex
    rexx test_queue_topic_nosql.rex
  )
  rm -rf "$work"
}

run_topics() {
  local work
  work=$(mktemp -d)
  cp -R "$ROOT/tests" "$work/tests"
  (cd "$work/tests"; rexx test_queue_topics.rex; rexx test_queue_topic_nosql.rex)
  rm -rf "$work"
}

run_distributed_topics() {
  local work
  work=$(mktemp -d)
  cp -R "$ROOT/tests" "$work/tests"
  (
    cd "$work/tests"
    rexx test_queue_distributed_topics.rex
    rexx test_queue_distributed_topic_multihop.rex
    rexx test_queue_distributed_topic_recovery.rex
    rexx test_queue_distributed_topic_nosql.rex
  )
  rm -rf "$work"
  bash "$ROOT/tests/test_queue_distributed_topic_socket.sh"
}

run_transport_core() {
  local work
  work=$(mktemp -d)
  cp -R "$ROOT/tests" "$work/tests"
  (
    cd "$work/tests"
    rexx test_queue_socket_framer.rex
    rexx test_queue_transport_nosql.rex
    rexx test_queue_transport_failover_nosql.rex
  )
  rm -rf "$work"
}

run_socket_transport() { bash "$ROOT/tests/test_queue_socket_transport.sh"; }
run_socket_security() { run_rexx_fixture test_queue_socket_ip_policy.rex; run_rexx_fixture test_queue_socket_session_crypto.rex; bash "$ROOT/tests/test_queue_socket_security.sh"; }
run_socket_health() { bash "$ROOT/tests/test_queue_socket_health_failover.sh"; }
run_transport() { run_transport_core; run_socket_transport; run_socket_security; run_socket_health; }

run_service() {
  local work
  work=$(mktemp -d)
  cp -R "$ROOT/tests" "$work/tests"
  (
    cd "$work/tests"
    rexx test_queue_broker_service.rex
    rexx test_queue_broker_retry.rex
    rexx test_queue_broker_lifecycle.rex
    rexx test_queue_broker_drain.rex
    rexx test_queue_broker_alchemy_adoption.rex
    rexx test_queue_runtime_alchemy_adoption.rex
    rexx test_queue_broker_nosql.rex
  )
  rm -rf "$work"
}

run_registry() { run_rexx_fixture test_queue_broker_runtime_registry.rex; }
run_wlu() {
  local work
  work=$(mktemp -d)
  cp -R "$ROOT/tests" "$work/tests"
  (cd "$work/tests"; rexx test_queue_broker_wlu.rex; rexx test_queue_broker_heartbeat_wlu.rex)
  rm -rf "$work"
}
run_release_boundary() { run_rexx_fixture test_queue_release_boundary.rex; }

run_compat_v082_v09() { QF_V082_SRC="$QF_V082_SRC" bash "$ROOT/tests/test_queue_compat_v082.sh"; }
run_compat_v082_v09_auth() { QF_V082_SRC="$QF_V082_SRC" CRYPTO_SRC="$CRYPTO_SRC" bash "$ROOT/tests/test_queue_compat_v082_authenticated.sh"; }
run_compat_v09_v082() { QF_V082_SRC="$QF_V082_SRC" bash "$ROOT/tests/test_queue_compat_v09_to_v082.sh"; }
run_compat_v09_v082_auth() { QF_V082_SRC="$QF_V082_SRC" CRYPTO_SRC="$CRYPTO_SRC" bash "$ROOT/tests/test_queue_compat_v09_to_v082_authenticated.sh"; }
run_compatibility() { run_compat_v082_v09; run_compat_v082_v09_auth; run_compat_v09_v082; run_compat_v09_v082_auth; }

run_crypto_known_answer() { run_rexx_fixture test_crypto_known_answer.rex; }
run_crypto_hmac() { run_rexx_fixture test_queue_crypto.rex; }
run_crypto_checkpoint() { run_rexx_fixture test_queue_checkpoint.rex; }
run_crypto_rotation() { run_rexx_fixture test_queue_rotation.rex; }
run_crypto_recovery() { run_rexx_fixture test_queue_recovery.rex; }
run_crypto_keyring() { run_rexx_fixture test_checkpoint_keyring.rex; }
run_crypto_uow() { run_rexx_fixture test_queue_uow_crypto.rex; }
run_crypto_channel() { run_rexx_fixture test_queue_channel_crypto.rex; }
run_crypto_topic() { run_rexx_fixture test_queue_topic_crypto.rex; }
run_crypto_distributed_topic() { run_rexx_fixture test_queue_distributed_topic_crypto.rex; }
run_crypto() {
  run_crypto_known_answer
  run_crypto_hmac
  run_crypto_checkpoint
  run_crypto_rotation
  run_crypto_recovery
  run_crypto_keyring
  run_crypto_uow
  run_crypto_channel
  run_crypto_topic
  run_crypto_distributed_topic
}

case "$MODE" in
  style) run_style ;;
  compile) run_compile ;;
  core) run_core ;;
  topics) run_topics ;;
  distributed-topics) run_distributed_topics ;;
  transport) run_transport ;;
  transport-core) run_transport_core ;;
  socket-transport) run_socket_transport ;;
  socket-security) run_socket_security ;;
  socket-health) run_socket_health ;;
  service) run_service ;;
  registry) run_registry ;;
  wlu) run_wlu ;;
  release-boundary) run_release_boundary ;;
  compatibility) run_compatibility ;;
  compat-v082-v09) run_compat_v082_v09 ;;
  compat-v082-v09-auth) run_compat_v082_v09_auth ;;
  compat-v09-v082) run_compat_v09_v082 ;;
  compat-v09-v082-auth) run_compat_v09_v082_auth ;;
  crypto) run_crypto ;;
  crypto-known-answer) run_crypto_known_answer ;;
  crypto-hmac) run_crypto_hmac ;;
  crypto-checkpoint) run_crypto_checkpoint ;;
  crypto-rotation) run_crypto_rotation ;;
  crypto-recovery) run_crypto_recovery ;;
  crypto-keyring) run_crypto_keyring ;;
  crypto-uow) run_crypto_uow ;;
  crypto-channel) run_crypto_channel ;;
  crypto-topic) run_crypto_topic ;;
  crypto-distributed-topic) run_crypto_distributed_topic ;;
  all)
    run_style
    run_compile
    run_core
    run_distributed_topics
    run_transport
    run_service
    run_registry
    run_wlu
    run_release_boundary
    run_compatibility
    run_crypto
    ;;
esac
