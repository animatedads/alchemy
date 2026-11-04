# Remote Compute MU native mesh ingress — 2026-10-29

Native ooRexx RemoteComputeMUMeshService fronts RemoteComputeMUFront through the candidate service compute.remote/0.1. This is a semantic receiver, not an XTP socket, Queue Fabric transport, LDAP server, scheduler or live provider.

## Caller chain
MI authenticated XTP/Queue Fabric transport -> trusted carrier context supplied OUT OF BAND -> injected policy.admit(context, service, operation, jobId, requestId) -> RemoteComputeMUMeshService.handle(envelope, trustedContext) -> RemoteComputeMUFront -> Job-to-Node/WLU/Storage authority checks -> provider.

Envelope (ooRexx Directory): service, requestId, operation, jobId; DISPATCH additionally requires an intent Directory with the identical jobId. Supported operations: DISPATCH, STATUS, CANCEL, RECOVER. Semantic reply: compute.remote.reply/0.1, requestId, outcome, optional result. This is NOT a wire serialization.

## Security and authority
- The trusted context is derived from the authenticated carrier, never payload identity fields.
- No context, missing policy, denied/stale identity, wrong service, mismatched job ID, and malformed intent fail closed.
- The injected policy MUST verify LDAP-derived identity, current MI incarnation/membership and ownership fence, audience, operation, replay freshness, and revocation. This implementation intentionally does not impersonate that policy.
- Every operation, including STATUS, is subject to policy admission.
- External Job-to-Node lease verification, WLU entitlement, Storage Fabric and provider idempotency remain indispensable.
- The transport MUST project reply fields through an allowlist and MUST NOT serialize internal objects or secrets.

## Qualification and unbound work
Native tests/test_mesh.rex passes on ooRexx 5.3.0 r13196 using a fake authenticated policy and controller; 21 prior Python tests and tests/test_front.rex still pass. Live XTP named-service registration, LDAP policy binding, Queue Fabric delivery, HA ownership and Colab/ZeroGPU/Windows submission are NOT qualified or enabled.
