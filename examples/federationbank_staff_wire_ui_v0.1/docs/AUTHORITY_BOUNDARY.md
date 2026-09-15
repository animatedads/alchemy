# Authority boundary

`FederationBankStaffWireApplication` is presentation/orchestration glue only.

```text
Access Control (already admitted to staff-banking domain)
        |
        v
Wire UI session / server-owned context
        |
        v
CUSTOMER.TRANSFER.SUBMIT intent
        |
        +--> exact Method Permission admission (object+method+Security Effect)
        |
        v
Staff Channel request
        |
        +--> Staff Authority (business authority; maker/checker)
        |
        v
Core Banking
        |
        v
Ledger
```

The UI does not turn role names, button visibility, method-permission proofs, authentication evidence, or Access Control admission into Staff Authority.

v0.1 deliberately omits checker completion UI. `APPROVAL_REQUIRED` work is visible and durable, but checker interaction will be added as a separate exact-authority journey rather than a generic button toggle.
