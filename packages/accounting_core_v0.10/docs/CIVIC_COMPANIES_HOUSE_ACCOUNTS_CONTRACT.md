# Civic -> Accounting Companies House accounts contract v0.2

This is the normalized projection consumed by `AccountingCivicCompaniesHouseImport`.
It is not the raw Companies House API, HTML or iXBRL schema.

## Authority split

### Civic owns

- approved Companies House endpoint/document retrieval
- credential references and network policy
- exact retrieved source bytes
- immutable retrieval/cache/observation evidence
- source document SHA-512 (and optionally SHA-256)
- filing identity
- iXBRL/XBRL/source-format parsing
- taxonomy/context/dimension resolution
- versioned mapping into this contract
- source pointers back to the filed evidence

### Accounting owns

- validating the normalized projection
- retaining Civic evidence/mapping identity
- retaining exact lexical and normalized fact evidence
- idempotent/conflict-safe assessment import
- assessment/reconciliation policy execution
- preventing implicit conversion into native GL truth

## Required top-level fields

| Field | Meaning |
|---|---|
| `contract_generation` | `civic.companieshouse.accounts/<generation>` |
| `mapping_generation` | Exact Civic mapping generation |
| `evidence_identity` | Immutable Civic evidence identity |
| `body_sha512` | 128-character lower/upper hex SHA-512 of exact source bytes |
| `company_number` | Companies House company number |
| `period_end` | Accounting period end, `YYYY-MM-DD` |
| `statement_kind` | e.g. `ANNUAL_ACCOUNTS` |
| `filing_identity` | Stable filing/document identity |
| `facts` | Ordered array of normalized facts |

For source contract `civic.companieshouse.accounts/0.2`, every fact also requires `source_pointer`.

## Optional top-level fields

- `body_sha256`
- `source_url`
- `source_document_name`
- `source_content_type`
- `company_name`
- `period_start`
- `reporting_basis`
- `units_description`
- `retrieved_at`
- `filing_date`
- `authorised_at`
- `access_state`
- `cache_state`
- `body_record_id`
- `observation_record_id`
- `taxonomy_refs` (ordered array)
- `completeness` (directory)

## Completeness

Completeness records what the filed package does and does not contain. Example keys are:

- `balance_sheet_delivered`
- `income_statement_delivered`
- `notes_delivered`
- `income_statement_omission_statement`
- `accounts_status_members`
- `accounts_type_members`
- `accounting_standard_members`
- `applicable_legislation_members`

Consumers must not interpret a statement explicitly not delivered as a statement of zero values.

## v0.2 fact shape

Required:

- `concept_id`
- `lexical_value` (presence required; empty text is permitted for valid no-content facts)
- `source_pointer`

Optional:

- `label`
- `value_type`
- `currency`
- `unit`
- `period_start`
- `period_end`
- `instant_date`
- `mapping_state`
- `dimensions`
- `provenance`

Recommended `provenance` keys:

- `source_concept_qname`
- `source_context_ref`
- `source_unit_ref`
- `source_format`
- `source_decimals`
- `source_scale`
- `source_element`
- `normalized_value`
- `duplicate_of`

`normalized_value` is an exact string representation. Decimal conversion must not pass through binary floating point.

## Canonical concept identity

For XML-taxonomy facts, the recommended canonical concept ID is:

```text
{namespace-uri}local-name
```

Source prefixes such as `ns5:` are preserved separately in provenance because prefixes are aliases local to a document.

## Dimensions

Dimensions are a directory of canonical dimension identity -> canonical member identity. Typed dimensions may use a producer-defined, versioned exact representation as long as the source context reference is also retained.

Accounting preserves dimensions without interpreting their legal/accounting meaning in core mechanics.

## Duplicate facts

Civic must not silently throw away repeated filed facts. A producer may mark a repeated equivalent fact with:

```text
mapping_state = REPORTED_DUPLICATE
provenance.duplicate_of = <source pointer of first equivalent fact>
```

Assessment policy can then choose a primary fact for arithmetic while the evidence store retains the duplicate occurrence.

## Identity and conflict behavior

The adapter derives:

```text
CIVIC-COMPANIES-HOUSE:<company_number>:<filing_identity>:<mapping_generation>
```

- exact re-import -> `DUPLICATE`
- same external identity with changed evidence/facts/completeness -> `EXTERNAL_IDENTITY_CONFLICT`

The statement fingerprint recursively covers nested metadata such as completeness arrays.

## No posting side effect

This contract terminates at `AccountingAssessmentBook`. It has no implicit posting semantics.

Any posting proposed from external filed accounts must be a later, explicit accounting-policy action with its own authority/evidence chain.

## Current Civic baseline

The supplied roll-up contains CivicPort v0.12. Its Companies House adapter currently exposes company-profile functionality, not this filed-accounts mapping. The included reference iXBRL projector qualifies the producer/consumer contract against a real filing; production implementation remains a Civic responsibility.
