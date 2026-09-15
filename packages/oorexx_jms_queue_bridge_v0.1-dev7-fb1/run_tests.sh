#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
: "${QF_SRC:?set QF_SRC to Queue Fabric src}"
: "${ALCHEMY_OBJECTS_SRC:?set ALCHEMY_OBJECTS_SRC to Alchemy Objects src}"
: "${CRYPTO_SRC:?set CRYPTO_SRC to ooRexx crypto src}"

BASE_REXX_PATH="$ROOT/src:$ROOT/tests:$QF_SRC:$ALCHEMY_OBJECTS_SRC:$CRYPTO_SRC"
if [[ -n "${SECRET_BROKER_SRC:-}" ]]; then
  BASE_REXX_PATH="$BASE_REXX_PATH:$SECRET_BROKER_SRC"
fi
if [[ -n "${RUNTIME_REGISTRY_SRC:-}" ]]; then
  BASE_REXX_PATH="$BASE_REXX_PATH:$RUNTIME_REGISTRY_SRC"
fi
export REXX_PATH="$BASE_REXX_PATH${REXX_PATH:+:$REXX_PATH}"

mode="${1:-all}"
run() { printf '\n== %s ==\n' "$1"; shift; "$@"; }

case "$mode" in
  style)
    run style rexx "$ROOT/tests/test_style.rex"
    ;;
  compile)
    for f in "$ROOT"/src/*.cls; do
      if [[ "$(basename "$f")" == "JMSQueueBridgeBSF.cls" ]] && ! rexx -e '::requires "BSF.CLS"' >/dev/null 2>&1; then
        echo "SKIP live BSF compile: BSF.CLS unavailable"
        continue
      fi
      if [[ "$(basename "$f")" == "JMSQueueBridgeSecrets.cls" && -z "${SECRET_BROKER_SRC:-}" ]]; then
        echo "SKIP Secret Broker adapter compile: SECRET_BROKER_SRC unavailable"
        continue
      fi
      run "compile $(basename "$f")" rexxc "$f" /tmp/"$(basename "$f")".cls
      rm -f /tmp/"$(basename "$f")".cls
    done
    ;;
  inbound)
    run inbound-client-ack-idempotency rexx "$ROOT/tests/test_inbound_idempotency.rex"
    run inbound-client-ack-recovery rexx "$ROOT/tests/test_inbound_rollback.rex"
    run inbound-auto-ack-monitoring rexx "$ROOT/tests/test_auto_ack_monitoring.rex"
    ;;
  outbound)
    run outbound-semantics rexx "$ROOT/tests/test_outbound_semantics.rex"
    run federationbank-compat rexx "$ROOT/tests/test_federationbank_compat.rex"
    run federationbank-fake-bsf-edge env REXX_PATH="$ROOT/tests/bsf_stub:$REXX_PATH" rexx "$ROOT/tests/test_federationbank_bsf_edge.rex"
    ;;
  persistence)
    run persistence rexx "$ROOT/tests/test_persistence.rex"
    ;;
  lifecycle)
    run runtime-lifecycle-surface rexx "$ROOT/tests/test_runtime_lifecycle.rex"
    run provider-and-flow-probe rexx "$ROOT/tests/test_provider_probe.rex"
    ;;
  session)
    run session-policy rexx "$ROOT/tests/test_session_policy.rex"
    run flow-capability-model rexx "$ROOT/tests/test_flow_capability.rex"
    run operational-readiness rexx "$ROOT/tests/test_operational_readiness.rex"
    ;;
  adoption)
    run alchemy-v08-adoption rexx "$ROOT/tests/test_alchemy_adoption.rex"
    ;;
  credentials)
    run environment-credentials rexx "$ROOT/tests/test_environment_credentials.rex"
    ;;
  secret)
    : "${SECRET_BROKER_SRC:?set SECRET_BROKER_SRC to ooRexx Secret Broker src}"
    run secret-broker-credentials rexx "$ROOT/tests/test_secret_broker_credentials.rex"
    ;;
  registry)
    : "${RUNTIME_REGISTRY_SRC:?set RUNTIME_REGISTRY_SRC to Runtime Registry src}"
    run runtime-registry-v014 rexx "$ROOT/tests/test_runtime_registry_v014.rex"
    ;;
  bsf-probe)
    run bsf-jms-classpath rexx "$ROOT/tests/test_bsf_jms_probe.rex"
    ;;
  live-activemq-edge)
    if [[ "${JMS_LIVE_ACTIVEMQ_EDGE:-}" != "1" ]]; then
      echo "Refusing live ActiveMQ edge test: set JMS_LIVE_ACTIVEMQ_EDGE=1 explicitly" >&2
      exit 2
    fi
    : "${ACTIVEMQ_BROKER_URL:?set ACTIVEMQ_BROKER_URL}"
    run federationbank-live-activemq-edge rexx "$ROOT/tests/test_federationbank_bsf_activemq_live.rex" "$ACTIVEMQ_BROKER_URL"
    ;;
  live-probe)
    if [[ "${JMS_LIVE_PROBE:-}" != "1" ]]; then
      echo "Refusing live JMS connection probe: set JMS_LIVE_PROBE=1 explicitly" >&2
      exit 2
    fi
    run live-jms-connect-only rexx "$ROOT/examples/faa_swim_probe.rex"
    ;;
  live-flow-probe)
    if [[ "${JMS_LIVE_FLOW_PROBE:-}" != "1" ]]; then
      echo "Refusing live JMS flow activation probe: set JMS_LIVE_FLOW_PROBE=1 explicitly" >&2
      exit 2
    fi
    run live-jms-flow-activation-no-receive rexx "$ROOT/examples/faa_swim_flow_probe.rex"
    ;;
  live-capability-probe)
    if [[ "${JMS_LIVE_CAPABILITY_PROBE:-}" != "1" ]]; then
      echo "Refusing live JMS capability matrix: set JMS_LIVE_CAPABILITY_PROBE=1 explicitly" >&2
      exit 2
    fi
    run live-jms-flow-capability-no-receive rexx "$ROOT/examples/faa_swim_capability_probe.rex"
    ;;
  core)
    "$0" style
    "$0" compile
    "$0" inbound
    "$0" outbound
    "$0" persistence
    "$0" lifecycle
    "$0" session
    "$0" adoption
    "$0" credentials
    ;;
  all)
    "$0" core
    "$0" secret
    "$0" registry
    ;;
  *)
    echo "unknown mode: $mode" >&2
    exit 2
    ;;
esac
