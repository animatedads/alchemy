#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
export REXX_PATH="../src${REXX_PATH:+:${REXX_PATH}}"

# Pure QueueRexx/kernel tests first.
for t in test_load.rex test_dev2_load.rex test_core.rex test_providers.rex test_policy_provider_fail_closed.rex test_serialization.rex test_health.rex test_mutation_load.rex test_state_lock.rex test_mutation.rex test_recovery.rex test_operations_load.rex test_operations.rex test_execution_load.rex test_execution_direct.rex test_execution_recovery.rex test_execution_systemd_fake.rex test_runtime_monitor.rex test_provider_telemetry.rex test_durable_triggers.rex test_fleet_recovery.rex test_wlu_bridge.rex test_scheduling_load.rex test_wlu_model.rex; do
  echo "== $t =="
  rexx "$t"
done

# Run the CPU-heavy exact WLU authority/lifecycle tests before the mixed-user
# QueueBash shell probes create additional ooRexx rxapi user contexts.  This is
# test isolation only; it does not change QueueRexx/WLU authority semantics.
if [[ -n "${QUEUEREXX_WLU_SRC:-}" && -n "${QUEUEREXX_JOB_NODE_SRC:-}" && -n "${QUEUEREXX_ALCHEMY_SRC:-}" && -n "${QUEUEREXX_CRYPTO_SRC:-}" ]]; then
  WLU_SRC="${QUEUEREXX_WLU_SRC}"
  WLU_REXX_PATH="${WLU_SRC}:${QUEUEREXX_JOB_NODE_SRC}:${QUEUEREXX_ALCHEMY_SRC}:${QUEUEREXX_CRYPTO_SRC}:../src${REXX_PATH:+:${REXX_PATH}}"
  echo "== test_wlu_integration.rex =="
  REXX_PATH="$WLU_REXX_PATH" rexx test_wlu_integration.rex
  echo "== test_wlu_lifecycle.rex =="
  REXX_PATH="$WLU_REXX_PATH" rexx test_wlu_lifecycle.rex
  echo "== test_wlu_scheduling_execution.rex =="
  REXX_PATH="$WLU_REXX_PATH" rexx test_wlu_scheduling_execution.rex
  echo "== test_job_node_placement_verification.rex =="
  REXX_PATH="$WLU_REXX_PATH" rexx test_job_node_placement_verification.rex
fi

echo "== test_root_ownership.sh =="
./test_root_ownership.sh

echo "== test_diagnosis.sh =="
./test_diagnosis.sh

echo "== test_lock_permission.sh =="
./test_lock_permission.sh

echo "== test_provider_health_cli.sh =="
./test_provider_health_cli.sh

if [[ -n "${QUEUEREXX_QUEUEBASH_144_ROOT:-}" ]]; then
  echo "== test_mixed_queuebash.sh =="
  ./test_mixed_queuebash.sh
  echo "== test_queuebash_record_compat.sh =="
  ./test_queuebash_record_compat.sh
  echo "== test_queuebash_exec_compat.sh =="
  ./test_queuebash_exec_compat.sh
  echo "== test_queuebash_to_queuerexx_admission.sh =="
  ./test_queuebash_to_queuerexx_admission.sh
  echo "== test_queuebash_created_list_parity.sh =="
  ./test_queuebash_created_list_parity.sh
  echo "== test_execution_queuebash_cancel.rex =="
  rexx test_execution_queuebash_cancel.rex "${QUEUEREXX_QUEUEBASH_144_ROOT}"
  echo "== test_wlu_queuebash_fence.sh =="
  ./test_wlu_queuebash_fence.sh
  echo "== test_queuebash_to_wlu_bridge.sh =="
  ./test_queuebash_to_wlu_bridge.sh
  echo "== test_queuebash_policy_provider.sh =="
  ./test_queuebash_policy_provider.sh
  if [[ -n "${QUEUEREXX_WLU_SRC:-}" && -n "${QUEUEREXX_JOB_NODE_SRC:-}" && -n "${QUEUEREXX_ALCHEMY_SRC:-}" && -n "${QUEUEREXX_CRYPTO_SRC:-}" ]]; then
    echo "== test_wlu_queuebash_cancel.rex =="
    REXX_PATH="$WLU_REXX_PATH" rexx test_wlu_queuebash_cancel.rex "${QUEUEREXX_QUEUEBASH_144_ROOT}"
  fi
fi

if [[ -n "${QUEUEREXX_OBSERVATION_PATH:-}" ]]; then
  echo "== test_observation_bridge.rex =="
  REXX_PATH="${QUEUEREXX_OBSERVATION_PATH}:../src${REXX_PATH:+:${REXX_PATH}}" rexx test_observation_bridge.rex
  echo "== test_provider_telemetry_observation.rex =="
  REXX_PATH="${QUEUEREXX_OBSERVATION_PATH}:../src${REXX_PATH:+:${REXX_PATH}}" rexx test_provider_telemetry_observation.rex
fi

# QueueRexx central Job-to-Node authority server.  These tests are the
# authoritative remote-placement path used by FD / Migratable Job; Queue
# Fabric is transport, while Job-to-Node v0.6 remains placement/admission/
# ownership authority.
if [[ -n "${QUEUEREXX_QUEUE_SRC:-}" && -n "${QUEUEREXX_ALCHEMY_SRC:-}" && -n "${QUEUEREXX_CRYPTO_SRC:-}" && -n "${QUEUEREXX_JOB_NODE_SRC:-}" && -n "${QUEUEREXX_WLU_SRC:-}" ]]; then
  AUTH_REXX_PATH="${QUEUEREXX_QUEUE_SRC}:${QUEUEREXX_ALCHEMY_SRC}:${QUEUEREXX_CRYPTO_SRC}:${QUEUEREXX_JOB_NODE_SRC}:${QUEUEREXX_WLU_SRC}${QUEUEREXX_RUNTIME_REFERENCE_SRC:+:${QUEUEREXX_RUNTIME_REFERENCE_SRC}}${QUEUEREXX_FOREIGN_RUNTIME_REXX:+:${QUEUEREXX_FOREIGN_RUNTIME_REXX}}:../src${REXX_PATH:+:${REXX_PATH}}"
  echo "== test_network1_mesh_composition.rex =="
  REXX_PATH="$AUTH_REXX_PATH" rexx test_network1_mesh_composition.rex
  echo "== test_authority_client_config.rex =="
  REXX_PATH="$AUTH_REXX_PATH" rexx test_authority_client_config.rex
  echo "== test_authority_mesh_config.rex =="
  REXX_PATH="$AUTH_REXX_PATH" rexx test_authority_mesh_config.rex
  echo "== test_authority_server_recovery.rex =="
  REXX_PATH="$AUTH_REXX_PATH" rexx test_authority_server_recovery.rex
  echo "== test_authority_server_wlu_restart.rex =="
  REXX_PATH="$AUTH_REXX_PATH" rexx test_authority_server_wlu_restart.rex
  if [[ -n "${QUEUEREXX_CRYPTO_DIRECT_BRIDGE:-}" ]]; then
    echo "== test_network1_over_peer_mesh_socket.sh =="
    QF_CRYPTO_FOREIGN_BRIDGE="${QUEUEREXX_CRYPTO_DIRECT_BRIDGE}" REXX_PATH="$AUTH_REXX_PATH" ./test_network1_over_peer_mesh_socket.sh
    if [[ -n "${QUEUEREXX_MIGRATABLE_JOB_SRC:-}" ]]; then
      echo "== test_migratable_job_network_authority.sh =="
      QF_CRYPTO_FOREIGN_BRIDGE="${QUEUEREXX_CRYPTO_DIRECT_BRIDGE}" REXX_PATH="${QUEUEREXX_MIGRATABLE_JOB_SRC}:$AUTH_REXX_PATH" ./test_migratable_job_network_authority.sh
    fi
  fi
fi

# QueueRexx-to-QueueRexx peer authority mesh.  This is a Queue Fabric
# integration, not a pure-kernel test: it exercises durable direct queues,
# peer ACL/reply bindings, quorum semantics, JTN-backed load projection and,
# when the accelerated crypto bridge is supplied, real encrypted
# queue.transport/2 socket request/reply between separate processes.
if [[ -n "${QUEUEREXX_QUEUE_SRC:-}" && -n "${QUEUEREXX_ALCHEMY_SRC:-}" && -n "${QUEUEREXX_CRYPTO_SRC:-}" && -n "${QUEUEREXX_JOB_NODE_SRC:-}" ]]; then
  MESH_REXX_PATH="${QUEUEREXX_QUEUE_SRC}:${QUEUEREXX_ALCHEMY_SRC}:${QUEUEREXX_CRYPTO_SRC}:${QUEUEREXX_JOB_NODE_SRC}${QUEUEREXX_WLU_SRC:+:${QUEUEREXX_WLU_SRC}}${QUEUEREXX_RUNTIME_REFERENCE_SRC:+:${QUEUEREXX_RUNTIME_REFERENCE_SRC}}${QUEUEREXX_FOREIGN_RUNTIME_REXX:+:${QUEUEREXX_FOREIGN_RUNTIME_REXX}}:../src${REXX_PATH:+:${REXX_PATH}}"
  echo "== test_peer_mesh.rex =="
  REXX_PATH="$MESH_REXX_PATH" rexx test_peer_mesh.rex
  if [[ -n "${QUEUEREXX_WLU_SRC:-}" ]]; then
    echo "== test_authority_peer_mesh_composition.rex =="
    REXX_PATH="$MESH_REXX_PATH" rexx test_authority_peer_mesh_composition.rex
  fi
  if [[ -n "${QUEUEREXX_CRYPTO_DIRECT_BRIDGE:-}" ]]; then
    echo "== test_peer_mesh_socket.sh =="
    QF_CRYPTO_FOREIGN_BRIDGE="${QUEUEREXX_CRYPTO_DIRECT_BRIDGE}" REXX_PATH="$MESH_REXX_PATH" ./test_peer_mesh_socket.sh
  fi
fi

if [[ -n "${QUEUEREXX_MIGRATABLE_JOB_SRC:-}" && -n "${QUEUEREXX_JOB_NODE_SRC:-}" && -n "${QUEUEREXX_CRYPTO_SRC:-}" ]]; then
  echo "== test_migratable_job_load.rex =="
  REXX_PATH="${QUEUEREXX_MIGRATABLE_JOB_SRC}:${QUEUEREXX_JOB_NODE_SRC}:${QUEUEREXX_CRYPTO_SRC}${QUEUEREXX_RUNTIME_REFERENCE_SRC:+:${QUEUEREXX_RUNTIME_REFERENCE_SRC}}${QUEUEREXX_FOREIGN_RUNTIME_REXX:+:${QUEUEREXX_FOREIGN_RUNTIME_REXX}}:../src${REXX_PATH:+:${REXX_PATH}}" rexx test_migratable_job_load.rex
  echo "== test_migratable_job_integration.rex =="
  REXX_PATH="${QUEUEREXX_MIGRATABLE_JOB_SRC}:${QUEUEREXX_JOB_NODE_SRC}:${QUEUEREXX_CRYPTO_SRC}${QUEUEREXX_RUNTIME_REFERENCE_SRC:+:${QUEUEREXX_RUNTIME_REFERENCE_SRC}}${QUEUEREXX_FOREIGN_RUNTIME_REXX:+:${QUEUEREXX_FOREIGN_RUNTIME_REXX}}:../src${REXX_PATH:+:${REXX_PATH}}" rexx test_migratable_job_integration.rex
  echo "== test_migratable_job_starter_guard.rex =="
  REXX_PATH="${QUEUEREXX_MIGRATABLE_JOB_SRC}:${QUEUEREXX_JOB_NODE_SRC}:${QUEUEREXX_CRYPTO_SRC}${QUEUEREXX_RUNTIME_REFERENCE_SRC:+:${QUEUEREXX_RUNTIME_REFERENCE_SRC}}${QUEUEREXX_FOREIGN_RUNTIME_REXX:+:${QUEUEREXX_FOREIGN_RUNTIME_REXX}}:../src${REXX_PATH:+:${REXX_PATH}}" rexx test_migratable_job_starter_guard.rex
  echo "== test_migratable_job_managed_placement.rex =="
  REXX_PATH="${QUEUEREXX_MIGRATABLE_JOB_SRC}:${QUEUEREXX_JOB_NODE_SRC}:${QUEUEREXX_CRYPTO_SRC}${QUEUEREXX_RUNTIME_REFERENCE_SRC:+:${QUEUEREXX_RUNTIME_REFERENCE_SRC}}${QUEUEREXX_FOREIGN_RUNTIME_REXX:+:${QUEUEREXX_FOREIGN_RUNTIME_REXX}}:../src${REXX_PATH:+:${REXX_PATH}}" rexx test_migratable_job_managed_placement.rex
  echo "== test_migratable_job_durable_placement_restart.rex =="
  REXX_PATH="${QUEUEREXX_MIGRATABLE_JOB_SRC}:${QUEUEREXX_JOB_NODE_SRC}:${QUEUEREXX_CRYPTO_SRC}${QUEUEREXX_RUNTIME_REFERENCE_SRC:+:${QUEUEREXX_RUNTIME_REFERENCE_SRC}}${QUEUEREXX_FOREIGN_RUNTIME_REXX:+:${QUEUEREXX_FOREIGN_RUNTIME_REXX}}:../src${REXX_PATH:+:${REXX_PATH}}" rexx test_migratable_job_durable_placement_restart.rex
fi

if [[ -n "${QUEUEREXX_MIGRATABLE_JOB_SRC:-}" && -n "${QUEUEREXX_JOB_NODE_SRC:-}" && -n "${QUEUEREXX_CRYPTO_SRC:-}" && -n "${QUEUEREXX_QUEUE_SRC:-}" && -n "${QUEUEREXX_ALCHEMY_SRC:-}" && -n "${QUEUEREXX_RUNTIME_REGISTRY_SRC:-}" && -n "${QUEUEREXX_ACCESS_PERMISSIONS_SRC:-}" ]]; then
  echo "== test_migration_status_subscription.rex =="
  REXX_PATH="${QUEUEREXX_MIGRATABLE_JOB_SRC}:${QUEUEREXX_JOB_NODE_SRC}:${QUEUEREXX_CRYPTO_SRC}${QUEUEREXX_RUNTIME_REFERENCE_SRC:+:${QUEUEREXX_RUNTIME_REFERENCE_SRC}}${QUEUEREXX_FOREIGN_RUNTIME_REXX:+:${QUEUEREXX_FOREIGN_RUNTIME_REXX}}:${QUEUEREXX_QUEUE_SRC}:${QUEUEREXX_ALCHEMY_SRC}:${QUEUEREXX_RUNTIME_REGISTRY_SRC}:${QUEUEREXX_ACCESS_PERMISSIONS_SRC}:../src${REXX_PATH:+:${REXX_PATH}}" rexx test_migration_status_subscription.rex
  echo "== test_status_projection.rex =="
  REXX_PATH="${QUEUEREXX_MIGRATABLE_JOB_SRC}:${QUEUEREXX_JOB_NODE_SRC}:${QUEUEREXX_CRYPTO_SRC}${QUEUEREXX_RUNTIME_REFERENCE_SRC:+:${QUEUEREXX_RUNTIME_REFERENCE_SRC}}${QUEUEREXX_FOREIGN_RUNTIME_REXX:+:${QUEUEREXX_FOREIGN_RUNTIME_REXX}}:${QUEUEREXX_QUEUE_SRC}:${QUEUEREXX_ALCHEMY_SRC}:${QUEUEREXX_RUNTIME_REGISTRY_SRC}:${QUEUEREXX_ACCESS_PERMISSIONS_SRC}:../src${REXX_PATH:+:${REXX_PATH}}" rexx test_status_projection.rex
fi

if [[ -n "${QUEUEREXX_CRYPTO_DIRECT_BRIDGE:-}" && -n "${QUEUEREXX_CRYPTO_COMPAT_BRIDGE:-}" && -n "${QUEUEREXX_CRYPTO_SRC:-}" && -n "${QUEUEREXX_RUNTIME_REFERENCE_SRC:-}" && -n "${QUEUEREXX_FOREIGN_RUNTIME_REXX:-}" ]]; then
  echo "== test_sha_fallback.rex =="
  REXX_PATH="../src:${QUEUEREXX_CRYPTO_SRC}:${QUEUEREXX_RUNTIME_REFERENCE_SRC}:${QUEUEREXX_FOREIGN_RUNTIME_REXX}${REXX_PATH:+:${REXX_PATH}}" rexx test_sha_fallback.rex
  echo "== test_foreign_runtime_sha.rex =="
  REXX_PATH="../src:${QUEUEREXX_CRYPTO_SRC}:${QUEUEREXX_RUNTIME_REFERENCE_SRC}:${QUEUEREXX_FOREIGN_RUNTIME_REXX}${REXX_PATH:+:${REXX_PATH}}" rexx test_foreign_runtime_sha.rex "${QUEUEREXX_CRYPTO_DIRECT_BRIDGE}" "${QUEUEREXX_CRYPTO_COMPAT_BRIDGE}"
  if [[ -n "${QUEUEREXX_MIGRATABLE_JOB_ROOT:-}" ]]; then
    echo "== upstream test_foreign_runtime_digest.rex =="
    REXX_PATH="${QUEUEREXX_MIGRATABLE_JOB_SRC}:${QUEUEREXX_JOB_NODE_SRC}:${QUEUEREXX_CRYPTO_SRC}:${QUEUEREXX_RUNTIME_REFERENCE_SRC}:${QUEUEREXX_FOREIGN_RUNTIME_REXX}${REXX_PATH:+:${REXX_PATH}}" rexx "${QUEUEREXX_MIGRATABLE_JOB_ROOT}/tests/test_foreign_runtime_digest.rex" "${QUEUEREXX_CRYPTO_DIRECT_BRIDGE}" "${QUEUEREXX_CRYPTO_COMPAT_BRIDGE}"
  fi
fi
