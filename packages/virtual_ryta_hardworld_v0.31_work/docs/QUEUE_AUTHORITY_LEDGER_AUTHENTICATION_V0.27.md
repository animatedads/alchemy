# Queue authority ledger authentication — v0.27

## Boundary

v0.26 made durable `COMPLETE` useful for ACK-only recovery. v0.27 therefore treats the execution ledger itself as evidence that must be authenticated before it can suppress a future authority-bearing mutation.

```text
durable text != trusted completion
```

## V3 record

`RYTA_QUEUE_AUTHORITY_LEDGER_V3` records carry:

- global sequence number;
- START / COMPLETE;
- execution key;
- immutable work-envelope fingerprint;
- authority-decision fingerprint;
- non-secret attempt evidence;
- timestamp;
- previous authenticated record tag;
- MAC algorithm id;
- MAC key id;
- MAC tag.

The MAC key is supplied by the host through the public `CryptoMacKeyRing` behavior. RYTA does not write or hash the key material. The Queue Fabric `claimToken` remains a live acknowledgement capability and is excluded from the record.

## Recovery rule

Only a MAC-verified V3 `COMPLETE` with a matching immutable work envelope may produce `ALREADY_COMPLETE_ACKED`. A V1/V2 record returns `LEGACY_LEDGER_RECORD_UNTRUSTED` on the current recovery path.

Fresh compatibility execution without a keyring is still possible and writes V2, but its completion is intentionally not reusable as automatic recovery authority after restart/retry.

## Chain and rotation

V3 records form one append chain. Sequence and previous-tag checks detect insertion, record mutation, deletion/reordering inside the observed chain, and key metadata is retained per record so a rotated key ring can verify historical entries.

Once V3/keyed operation is active, legacy V1/V2 writes are refused; downgrade cannot be appended behind authenticated state.

## Rollback qualification

A valid *older prefix* remains cryptographically valid. A local MAC chain cannot prove that a newer tail once existed if both the file and all local metadata can be rolled back.

`QueueAuthorityExecutionLedger~chainCheckpointText` is therefore designed to be retained by a host in a separate trusted/monotonic store. Passing that value back as the optional constructor checkpoint causes a mismatch to fail closed with `QUEUE_AUTHORITY_LEDGER_CHECKPOINT_MISMATCH`.

This distinction is deliberate:

```text
MAC/chain authenticity != monotonic storage
```

## Executable adversaries

`test_queue_authority_ledger_auth_v027.rex` proves:

1. authenticated START -> COMPLETE -> failed ACK;
2. restart verifies the V3 chain and permits ACK-only cleanup;
3. V3 cannot be opened without the required key ring;
4. changing COMPLETE to START invalidates the MAC;
5. record reordering breaks chain sequence;
6. a syntactically valid forged COMPLETE with a fake tag is rejected;
7. key rotation across records verifies with the full ring and fails if a historical key is absent;
8. rollback to an older valid prefix is detected when the external checkpoint is supplied;
9. V2 completion remains readable but cannot cause blind ACK;
10. raw and hex Queue claim tokens do not occur in ledger material.

`test_legal_v010_ledger_auth_v027.rex` repeats completed-work recovery through real Legal Effect v0.10.1 + Runtime Registry v0.12: after the side effect reaches authenticated COMPLETE and ACK fails, the Legal lease is released, the ledger is reopened from disk against the trusted checkpoint, and only transport cleanup survives. New retained work after release remains refused by live Legal evaluation.
