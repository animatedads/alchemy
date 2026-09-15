# QueueRexx typed operations

QueueRexx operation objects sit above the recovery-safe compatibility kernel. They may request transitions; they may not move QueueBash files directly.

Public CLI mutation remains disabled. These are internal/API qualification surfaces.

Dev11 binds worker execution policy to the exact QueueBash 0.18.144 policy gate through `QueueBashClassPolicyProvider`. The provider evaluates a temporary job-record copy and returns evidence only. `QueueWorkerAdmission` still owns the post-claim decision flow and `QueueTransitionService` alone commits `running -> pol_blocked`.

Typed submission remains fail-closed unless an explicit submit-policy implementation is supplied; dev11 does not pretend the smaller `QueueSubmitRequest` captures QueueBash's full submit-time security-policy contract.

## Submit

```text
QueueSubmitRequest
    -> explicit QueueOperationPolicyGate
    -> QueueSubmitService
       -> unmanaged: QueuePendingAllocator -> pending
       -> WLU-managed: QueueWaitingAllocator -> waiting + QUEUEREXX_WLU_HOLD
    -> QueueBash-compatible .job record
```

A missing policy implementation denies submission. Managed WLU records persist the original requested class plus immutable expected/ceiling/rate demand. The QueueBash-visible hold class prevents non-WLU-aware execution.

## Legacy/unmanaged worker admission

```text
QueueWorkerAdmission
    -> choose pending candidate
    -> QueueTransitionService pending -> running
    -> explicit execution policy
    -> runner-provider selection
    -> STOP
```

In dev8, `QueueWorkerAdmission` still stops at admission/provider selection. Payload start is deliberately a separate `QueueExecutionService` authority so claim/policy and process launch have distinct recovery evidence. `QueueTypedWorker` composes the two only after scheduling/WLU/placement eligibility has been established.

## WLU-managed admission and activation

Managed work follows a different authority path:

```text
waiting + WLU hold
    -> QueueWLUPlacementRequestAdapter
    -> Job-to-Node eligibility / placement
    -> QueueJobNodeWLUAdmission
       -> WLU Authority reserves ceiling work + WLU/s
       -> placement lease carries reservationRef
    -> QueueWLUActivationService
       -> validate active reservation + Job-to-Node-verified current placement lease
       -> acquire normal QID lock
       -> QueueTransitionService~transitionWithLock(waiting -> running)
```

A QueueBash worker therefore never needs to understand WLU in order to avoid executing unadmitted managed work.

## Usage

`QueueWLUUsageService` records measured WLU only if the one authoritative queue record is `running`. It takes the ordinary QID lock before calling WLU Authority so a terminal operation cannot race a late consume.

## Terminal operations

`QueueWLUTerminalService` composes queue and WLU authorities under the QID lock:

```text
complete -> QueueState DONE      + WLU settle(actual)
fail     -> QueueState FAILED    + WLU settle(actual)
cancel   -> QueueState CANCELLED + WLU release(unused; consumed remains spent)
```

The service persists WLU terminal intent before the queue transition and records the queue commit before WLU close. `QueueWLULifecycleRecovery` completes a missing WLU close after a crash without repeating the queue mutation or double-charging work.

If QueueBash itself commits a terminal state, recovery treats that filesystem state as authority and repairs only missing WLU accounting.

## Mutation rule

All state movement goes through `QueueTransitionService`. `transitionWithLock()` exists so a composed authority can retain the same already-acquired QID lock around side-intent and post-transition authority work. It is not a bypass around validation.

## Mixed-engine acceptance rule

Every new mutating operation should have at least one QueueBash/QueueRexx interoperability test. Current proof includes:

```text
QueueRexx record -> QueueBash source/list
QueueRexx submit -> QueueBash executes to done
QueueBash submit -> QueueRexx typed admission -> running
QueueBash cancel -> QueueRexx WLU recovery closes accounting only
```
