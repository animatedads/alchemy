# Authority separation

External Cash may determine that a specific sealed physical shipment is authorised to cross the branch perimeter. It does not own the branch vault and cannot manufacture vault-custody consent.

```text
cash centre / carrier shipment authority
              |
              v
       External Cash
              |
       exact shipment
              |
              v
      branch custody adapter
              |
       current vault control
              |
              v
        Branch Cash vault
```

The branch side must independently validate its current dual custody before changing physical vault truth.
