# FlyLo legal model

The website and Grok assistant do not carry passenger-rights law in prompts. Legal duties are represented as a compiler-admitted **Legal Effect v0.14** generation and evaluated from evidence-bearing operational facts.

## Current sources

- UK Regulation (EC) No 261/2004 as it applies in UK law, including the Aviation (Consumers) (Amendment) Regulations 2023 (SI 2023/1370).
- 14 CFR Part 260 for U.S. airline fare and ancillary-service refunds.
- U.S. DOT July 2026 flight-renumbering enforcement discretion, modelled separately from the substantive Part 260 entitlement.

## Boundary

The application derives operational facts such as `FLIGHT_CANCELLED`, `ARRIVAL_DELAY_AT_LEAST_3H`, `CARE_THRESHOLD_REACHED`, `US_COVERED_FLIGHT`, and `PASSENGER_DID_NOT_ACCEPT_ALTERNATIVE`. Legal Effect decides whether a norm applies. Grok receives a bounded explanation of the resulting assessment and may explain it, but cannot create, waive, or alter an entitlement.

An unknown fact that matters to a legal outcome stays unknown. For example, if an arrival delay exceeds three hours but `EXTRAORDINARY_CIRCUMSTANCES` is unresolved, the compensation assessment becomes `REVIEW_REQUIRED` rather than allowing an LLM to guess.

## Source assurance

v0.2 carries forward the v0.1 verification of the exact retained source representations used for compilation and therefore produces a compiler-certified generation. It deliberately does **not** fabricate publisher signatures or authority attestations. Production publication should add the authoritative retrieval/publisher chain and source-authority attestation before the legal generation is promoted as fully attested.
