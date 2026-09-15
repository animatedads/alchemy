# Retained authority revalidation — RYTA v0.25-work

## Rule

A durable retained queue event is **evidence of what was published**, not a durable grant of the authority that existed when it was published.

```text
publisher-time authority != consumer-time authority
queue retention/durability != authority
runtime provenance != authority
```

Queue Fabric v0.8.2 already marks late retained delivery with native headers:

```text
oqf.topic.retained       = 1
oqf.topic.publication_id = <stable publication id>
```

RYTA consumes those public headers directly. It does not create a second retained-event flag.

## Execution boundary

For ordinary live work, the v0.21 START/COMPLETE/ACK execution boundary is unchanged.

For a retained replay:

```text
claim retained package
        |
        v
build stable queue work/attempt evidence
        |
        v
consumer-time revalidation               <-- before ledger START
        |
        +-- REFUSE --> no HardWorld mutation; no START; no ACK
        |
        v
fresh sealed promotion set
        |
        v
START -> EvidencePromotionApplier -> COMPLETE -> ACK
```

`QueueAuthorityRevalidationResult` binds the Queue Fabric publication id, consumer-context identity, revalidator identity and fresh promotion canonical text into the v0.25 work fingerprint. Its Alchemy object id and observation timestamp are deliberately not authority identity.

A revalidator may not return the publisher set itself, nor a distinct object with the same canonical promotion semantics. Both are stale publisher authority.

## Legal Effect v0.10 consumer-time revalidation

`LegalEffectV010RetainedAuthorityRevalidator` does not accept a precomputed Legal execution envelope. The host supplies:

- a Legal Effect engine object;
- a live `LegalRuntimeRuleLease`;
- the action to assess; and
- the consumer Legal context.

Inside `revalidate()` it:

1. runs `LegalEffectV07PinnedEvaluator` on the exact generation/action/context, retaining the conservative reducer-order guard;
2. obtains canonical action/context identities from that pinned input snapshot;
3. calls the live Legal runtime lease at consumer time;
4. re-pins the action/context after that live call and refuses mutation/race drift;
5. checks the pinned/runtime statuses agree;
6. projects the live result through `LegalEffectV010PromotionAdapter`; and
7. returns a distinct sealed consumer promotion set bound to the retained publication id.

The resulting authority remains the native v0.10 form:

```text
LEGAL_EFFECT/0.10/<generation>
  @<semantic>
  +<conservative execution>
  +cert:<certificate>
  +verified:<verification closure>
  +sourceauth:<host source-authority verification closure>
```

The known REVIEW/STATUS_EFFECT + REQUIRES_OBLIGATION reducer ambiguity still fails closed as `LEGAL_STATUS_REDUCTION_AMBIGUOUS`.

## Adversarial guarantees

The executable v0.25 tests prove:

- retained publisher promotions are refused with no revalidator;
- refusal happens before execution-ledger `START`;
- explicit consumer denial remains denial and is not ACKed as success;
- a mismatched publication id is refused;
- returning the same publisher promotion-set object is refused;
- returning a copied promotion set with identical canonical publisher semantics is also refused;
- a distinct current consumer set may execute and ACK;
- publisher-time approval is not silently copied into the consumer world;
- Legal v0.10 source-authority closure is preserved on the applied current fact;
- releasing the Legal runtime lease causes the next retained replay to fail at the fresh live evaluation rather than reuse old authority; and
- a non-retained live topic delivery remains compatible with the pre-v0.25 executor path.

This remains deliberately **non-XA**. Queue retention/idempotency and RYTA's durable START/COMPLETE ledger reduce replay hazards, but HardWorld mutation plus queue acknowledgement are not represented as one atomic distributed transaction.
