# Authority separation

- Staff Authority decides whether employees may request/approve the operation.
- Branch Cash decides whether physical branch cash may move between custody endpoints.
- Teller Till owns the physical truth of an individual till.
- Core Banking owns customer-account monetary truth.
- Ledger remains authoritative monetary posting truth.

An internal branch cash transfer is not a customer deposit/withdrawal and must not be disguised as one.


## Exact-action authority

Branch Cash v0.2 turns its own decision into a typed authority envelope only after the exact transfer, checker approval, upstream Staff Authority reference, and Branch Cash policy agree. The envelope is immutable evidence for downstream custody adapters; it is not an invitation to bypass the destination authority.
