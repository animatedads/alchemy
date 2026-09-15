# Merchant Banking Front-End Boundary

## Owned here

- browser bootstrap;
- Merchant Banking visual shell;
- responsive/accessibility presentation;
- local-only early-UI navigation;
- visual development fixtures;
- Wire UI server-side read/navigation application;
- bounded server-side projection adapter over already-authoritative Merchant/Risk/Accounting facts;
- UI/projection validation.

The server-side projection adapter owned here is still presentation infrastructure. It may discover, correlate and copy attributable facts into bounded UI rows/details; it does not become authority for those facts.

## Never owned here

- derivative product or instrument meaning;
- trade/order validation, booking or execution truth;
- position or valuation truth;
- hedge equivalence or whole-book risk calculations;
- remediation approval or execution assessment;
- settlement obligations, instructions or observations;
- accounting-event interpretation or journal posting;
- margin/collateral authority;
- Core Banking balances or movements;
- VMM business logic.

## Multi-truth display rule

The UI must not collapse independent domain states into a single green/red status. It can validly show a client-visible close, two live contracts, net-zero directional exposure, an impaired hedge, completed cash settlement and an open accounting control at the same time.

## Close-position rule

The front end may display or emit an authoritative semantic action labelled "Close position" only when the live server release grants that action. It must never locally infer that close means deleting or terminating the original CFD.

## Remediation rule

`APPROVED` plan is not `EXECUTED`. A UI work item becoming complete is not proof that Merchant risk has been cured. Execution checkpoints and fresh whole-book assessments are rendered as authoritative projections.

## Settlement rule

Obligation, instruction and externally observed settlement are different facts. A browser acknowledgement or instruction status must never be displayed as proof of cash movement unless the authoritative projection says settlement was observed.

## Accounting rule

Settlement completion is not proof that derivative carrying value has been derecognised or realised P&L recognised. Non-posting settlement amount determinations must be presented as determinations, never as amendments to Merchant contractual obligations.


## Authority refresh rule

`WORKSPACE.REFRESH` may re-read the exact bound Merchant Bank, Risk Service and Accounting Adapter authorities. It may not create a missing assessment or evidence item to make the screen more complete. Filter/sort/select/open work only over the current server-side projection and never refresh or mutate business state.
