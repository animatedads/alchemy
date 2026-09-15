# Architecture

```text
Reference / Legal / Sanctions evidence
             |
             v
 Merchant Risk Service
   (discovery/orchestration)
             | exact instrument-evidence lookup
             v
 Merchant Bank v0.13  <--- risk authority
             |
             +--> versioned equivalence evidence
             +--> risk assessment
             +--> remediation obligation
             |
             v
 service operational work/events
```

The service never reconstructs hedge identity from ticker, ISIN or customer-facing `CLOSED` state. It uses `hedgesAffectedByInstrumentEvidence()` on the Merchant authority.


Approved plans do not cross this boundary as execution authority. Post-action execution evidence arrives from an authenticated owning Merchant authority; Risk Service forwards it into Merchant Bank, which records/verifies the evidence against a fresh whole-book assessment. Service-level deviation work is operational follow-up only and cannot cure the domain remediation obligation.
