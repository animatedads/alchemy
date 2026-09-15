# Architecture

```text
CRM / Interaction / Reputation
          |
          v
   Relationship Case
     DECISION element -----------+
          |                       |
          | points at             v
          +------------> authoritative decision
                               |
                               v
                  FederationBank Relationship Adapter
                               |
                       Institutional Policy
                    authority/action mapping
                               |
                  +------------+------------+
                  |                         |
             NO_BANK_ACTION        FederationBankCommand
                                            |
                                    ordinary STAFF channel
                                            |
                           FederationBank Account / Payments
                                            |
                              Bouncer -> Bank Policy -> Legal
                                            |
                                          Ledger
```

The adapter is a translation boundary, not a superior banking authority. A case coordinates the reference graph; authoritative specialist systems own their decisions; Core Banking owns banking execution; Ledger owns monetary truth.
