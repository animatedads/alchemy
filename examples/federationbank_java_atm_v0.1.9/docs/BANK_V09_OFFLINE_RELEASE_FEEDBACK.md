# FederationBank v0.9 ATM unused-offline-authority feedback

## Finding

`GET_OFFLINE_ALLOWANCE` with `authorityMode=RESERVED_ALLOWANCE` creates a real Ledger hold and a retained `ACTIVE` offline authority. If the authority is never used, stock v0.9 has no channel operation that returns it.

The gap was reproduced directly:

```text
issue 10000 RESERVED_ALLOWANCE
book balance       unchanged
available balance  -10000
hold               ACTIVE
authority          ACTIVE

LOGOFF
hold               ACTIVE
authority          ACTIVE

RELEASE_OFFLINE_ALLOWANCE
-> OPERATION_UNSUPPORTED
```

No book money is lost, but customer availability can remain constrained indefinitely.

## Required invariant

An unused authority may be cancelled only while there is no physical-cash ambiguity.

Authority cancellation must not be implemented as "release the hold and then mark the authority cancelled", because a bank crash in between could leave a still-vendable retained authority with no reservation behind it.

The safe ordering is:

```text
ACTIVE
  |
  | persist cancellation intent
  v
RELEASE_PENDING       authority cannot vend
  |
  | idempotent RELEASE_HOLD
  v
RELEASED
```

If the bank restarts at `RELEASE_PENDING`, reconstruction must restore that non-vendable state and resume the same hold release.

## Candidate

`integration/oorexx/federationbank_v0.9_atm_offline_release.patch` adds the narrow gateway/service behaviour only. The Java ATM sends a stable release idempotency identity and journals its own `RELEASE_PENDING` before transport.

The candidate:

- validates authority/terminal/customer binding;
- rejects consumed or otherwise non-active authority;
- persists `RELEASE_PENDING`;
- releases a `RESERVED_ALLOWANCE` hold through the normal bank command path;
- persists `RELEASED`;
- treats same-key replay as success;
- rejects a conflicting release identity.

## Qualification

The candidate test deliberately:

1. issues a reserved authority;
2. persists bank-side `RELEASE_PENDING`;
3. reconstructs the gateway from retained state;
4. resumes the same release;
5. proves the Ledger hold is released;
6. replays the release and proves it is harmless.

Existing ATM protocol, money, offline-authority, mandatory-settlement and hold-lifecycle tests remain applicable.

## Follow-up

Automatic expiry reaping is a separate lifecycle problem. It must not simply release a reservation at `expiresAt`: delayed evidence may prove that cash physically left while authority was valid. A future reaper needs an explicit reconciliation grace/evidence policy and must preserve the difference between authority-to-vend and authority-to-settle already-dispensed cash.
