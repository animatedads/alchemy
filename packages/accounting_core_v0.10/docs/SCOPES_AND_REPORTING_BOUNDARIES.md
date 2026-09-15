# Accounting scopes and reporting boundaries v0.6

Accounting Core v0.5 treats legal entity, establishment, tax registration,
professional/regulatory registration, client-money arrangement and reporting
boundary as independent concepts.

The accounting book remains the economic book of the legal entity.  A foreign
tax registration does not create another company, and a branch/place of
business is not automatically an intercompany counterparty.

## Standard line dimensions

The core reserves these optional dimension keys:

- `accounting.establishmentRef`
- `accounting.taxRegistrationRef`
- `accounting.taxElectionRef`
- `accounting.taxElectionIdentity`
- `accounting.regulatoryRegistrationRef`
- `accounting.clientMoneyArrangementRef`
- `accounting.matterRef`
- `accounting.relationshipKind`

`relationshipKind` distinguishes `EXTERNAL`, `INTRA_ENTITY`,
`INTER_ESTABLISHMENT` and `INTERCOMPANY`.  It does not infer one from another.

Company-specific dimensions remain allowed and are not reinterpreted by the
core.

## Tax registration versus tax election

`AccountingTaxRegistration` is the statutory relationship: authority,
jurisdiction, tax type, registration number, optional establishment, basis and
effective lifecycle.

`AccountingTaxElection` is separately effective dated and has both a semantic/version reference and an immutable exact identity. It freezes:

- the tax registration to which it applies;
- ruleset semantic reference and exact identity;
- rounding algorithm reference;
- calculation granularity;
- return scheme; and
- supporting evidence/metadata.

The scope registry rejects overlapping elections for the same tax
registration.  Once an active election is configured, a tax-tagged journal
line must carry both `accounting.taxElectionRef` and `accounting.taxElectionIdentity`; a posting cannot silently omit, redefine or substitute the elected method.

This permits, for example, one US legal entity to hold a GB VAT registration
as a non-established taxable person without creating a fictional UK company
or UK establishment.

The core does not calculate VAT/GST.  Jurisdiction policy code calculates the
legal tax amount at high precision and stamps the exact registration/election
identity into the proposed accounting transaction.  Accounting then posts
exact integer minor units under the existing DIGITS 50 contract.

## Client money

`AccountingClientMoneyArrangement` associates a client/trust account with an
establishment, regulatory registration and currency.  It does not define SRA,
Australian trust-account or other regulator-specific rules.  Those rules live
in policy modules.

When a journal line cites a client-money arrangement, Accounting validates the
registered arrangement, effective date, currency and any accompanying
establishment/regulator dimensions before posting.

## Reporting boundaries

`AccountingReportingBoundary` is an immutable selection definition over one
or more accounting books.  It carries:

- reporting authority;
- report type;
- effective period;
- included legal entities and book IDs;
- exact dimension selectors;
- semantic reporting policy reference and exact policy identity;
- evidence and metadata.

`AccountingReportingService` derives a view from immutable journal lines.  It
does not copy, rewrite or repost them.

This permits the same underlying book to support simultaneously, for example:

- a GB VAT return selected by `accounting.taxRegistrationRef`;
- an Australian GST/BAS view selected by another registration;
- a professional-regulator Client Account view spanning multiple client-money
  arrangements and currencies; and
- whole-firm management accounts with no jurisdiction selector.

The view retains the exact boundary fingerprint used to produce it.

## Persistence

Journal dimensions already use the v0.4 append-only persistence format and
scalar protection.  Therefore scope IDs, tax-election IDs, matter IDs and
leading-zero identifiers survive restart byte-exactly.  A reporting boundary
can be applied to a recovered book without reconstructing or reposting the
underlying transactions.

Scope/policy configuration itself remains a versioned configuration input in
v0.5; the posted journal retains the selected identities.  A future
configuration-store API can persist registries without changing the journal
contract.
