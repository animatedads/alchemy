# All Japan Insurance front-end boundary

## Owned here

- AJI browser bootstrap and branded shell;
- responsive presentation recipes;
- semantic workspace vocabulary for early Wire UI compilation;
- non-authoritative visual preview fixtures;
- front-end-only validation.

## Not owned here

The UI is **not** an authority for:

- product or coverage definition;
- rating factors, rating plans or rating-function identity;
- underwriting decisions or authority;
- quote premium or override authority;
- policy bind, endorsement, cancellation or reinstatement semantics;
- billing balances, allocation, arrears or customer credit;
- claim coverage, assessment, reserve or claim payment;
- AJI accounting journals or balances;
- Federation Intermediary authority;
- FederationBank or Vector Meridian Markets authority.

The browser renders server-authored projections and emits semantic intent only. It must never calculate a premium, infer claim coverage, decide arrears, manufacture a journal entry, or turn a disabled visual control into authority.

## Currency rule

AJI's legal-entity/operator presentation defaults to JPY. The browser may format an authoritative monetary value and currency, but it must not translate currencies or invent an FX rate.

## Preview rule

`web/preview.html` is a NON-AUTHORITATIVE FRONT-END FIXTURE. It contains illustrative data only, makes no network calls, and must never be mistaken for an AJI policy/claims/billing implementation.
