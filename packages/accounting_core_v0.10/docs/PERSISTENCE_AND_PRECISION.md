# Accounting persistence and precision contract v0.6

## Purpose

`accounting.store/0.1` makes a legal-entity accounting book restartable without changing the authority model established by the posting and transaction APIs.

Persistence is not a banking ledger and does not create cross-company authority. One store contains one accounting book for one legal entity.

## Precision invariant

Accounting Core uses exact whole-number minor units under `NUMERIC DIGITS 50`.

All Accounting Core ooRexx source packages declare:

```rexx
::OPTIONS DIGITS 50
```

A concrete `AccountingPolicy` package must also have package precision of at least 50 digits or registration is rejected.

Amounts are accepted only as non-negative whole numbers with no more than 50 significant integer digits. Values outside that contract are rejected rather than rounded.

## Durable amount representation

Rexx strings have numeric semantics and `json.cls` may emit a numeric-looking Rexx string as a JSON number. Therefore money is explicitly encoded:

```text
I:<canonical whole-number minor-unit amount>
```

Logical amount encoding:

```text
I:1234567890123456789012345678901234567890
```

Because `json.cls` can also coerce other numeric-looking Rexx strings, all persisted data scalars have a storage protection prefix. The physical JSONL representation is therefore:

```json
"debit_minor":"S:I:1234567890123456789012345678901234567890"
```

The `S:` layer preserves opaque IDs such as `00123456` and evidence references such as `000123`. On recovery the storage layer is removed, `I:` is validated, and the digits are passed through the same 50-digit whole-minor-unit validator.

## Append-only records

Record contract: `accounting.store.record/0.1`.

Record types:

- `BOOK_CREATED`
- `ACCOUNT_ADDED`
- `CHART_SEALED`
- `PERIOD_ADDED`
- `PERIOD_STATE_CHANGED`
- `JOURNAL_POSTED`

Every record has a contiguous sequence number. Recovery rejects sequence gaps, duplicate book creation, incompatible arithmetic profiles, unknown record types, journal replay failures, deterministic entry-ID mismatch and journal fingerprint mismatch.

`BOOK_CREATED` records:

- `legal_entity_id`
- `book_id`
- `reporting_basis`
- `arithmetic_profile`
- `numeric_digits`
- `amount_representation`

## Period lifecycle

Period state is `OPEN`, `CLOSED` or `LOCKED`.

Transitions are retained in `AccountingPeriodTransition` with:

- transition sequence
- period ID
- from/to state
- actor reference
- rationale
- evidence references
- caller-supplied occurrence time

A locked period cannot change state.

## Restart-safe event identity

A `JOURNAL_POSTED` record retains the whole immutable journal draft, including:

- source event reference
- source event fingerprint
- event type
- correlation
- counterparty
- semantic policy reference
- exact executable policy identity
- lines
- evidence
- metadata/dimensions

Recovery rebuilds `sourceIndex`. Therefore `AccountingEngine~transact()` still performs source replay/conflict resolution before accounting policy dispatch after restart.

This is deliberately stronger than simply rebuilding account balances.
