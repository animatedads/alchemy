# FederationBank Gopher sphere v0.2

This is the LLM-facing documentation interface for the FederationBank banking demo.

The point is not to make the architecture sound simpler than it is. The sphere makes the authority boundaries searchable so an LLM can answer **who owns this fact?** before it starts writing banking code.

## Start

After loading the sphere into LLM Gopher v0.19-dev1+:

```sh
gopher --profile federationbank context federationbank --full
gopher --profile federationbank search "monetary truth" --sphere federationbank
gopher --profile federationbank search "physical cash" --sphere federationbank
gopher --profile federationbank search "Merchant collateral" --sphere federationbank
gopher --profile federationbank open architecture.federationbank.authority-map
gopher --profile federationbank open ledger.federationbank.monetary-truth
```

Exact topic lookup is also available:

```sh
gopher --profile federationbank lookup topic=replay --sphere federationbank
gopher --profile federationbank lookup topic=staff-channel --sphere federationbank
gopher --profile federationbank lookup topic=collateral --sphere federationbank
```

## What it teaches

- Account Engine vs Payments Engine vs Ledger Engine ownership.
- Atomic double-entry monetary truth and SQL/receipt replay.
- Holds as reservations rather than postings.
- Customer intent vs physical cash fact vs monetary truth.
- Staff Channel and Staff Authority as a separate Core payment ingress.
- Teller Till / Branch Cash / Branch Day physical-custody boundaries.
- Bank-issued offline ATM authority and bounded delayed reconciliation.
- Merchant Banking as an arm's-length authority, never a Core module.
- Merchant close-out vs Core collateral realisation as two independent effects.
- Institutional Policy / Legal Effect ownership and the rule that package fixtures are not real regulation.

## Provenance

Articles carry canonical structured provenance (`artifact`, SHA-256, member and line range) back to the supplied qualified/component packages. The current observed Core baseline recorded by this sphere is `federationbank_engine_v0.9.2.zip`.

When a newer component arrives, inspect the new package first. Source/package evidence supersedes stale sphere prose; revise the smallest affected sphere object rather than teaching the LLM two contradictory architectures.
