# Architecture

    cREXX typed object
          |
         RXPA
       /      \
 native payload  CALLMETHOD
       |           |
 projection    cREXX callback

Rules:

1. RXPA value handles are borrowed, never durable identities.
2. Native payload owns a ref-counted projection.
3. Copy retains; finalization releases.
4. Explicit close is alias-visible and idempotent.
5. Signals remain distinct from ordinary results.
6. dev1 callbacks are same-thread and synchronous.
7. No private VM value/proc_runtime/frame API is used.
8. cREXX metadata remains authoritative for cREXX contracts.
9. Alchemy identity is independent of RXBIN graph/runtime IDs.
