# Architecture

```text
Vault Authority -----------\
Teller Till ----------------+--> endpoint evidence
Branch Cash Service --------+--> position / in-transit / reconciliation evidence
Teller Cash / cash control -+--> customer cash-in/out control totals
External cash logistics ----+--> external cash-in/out control totals
                             |
                             v
                       BRANCH DAY
                    open / closing / closed
                             |
                             v
                    operational certification
```

Branch Day coordinates evidence; it does not edit any evidence source. Failure to certify a close leaves the day `CLOSING` and requires the underlying custody/reconciliation problem to be resolved at its authority.
