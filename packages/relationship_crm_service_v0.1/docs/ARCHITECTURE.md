# Relationship CRM Service architecture

```text
staff channel / CRM product adapter / batch servicing
                  |
             Queue Fabric
                  |
      Relationship CRM Service
       idempotency / persistence
        outbox / projected reads
                  |
       Relationship CRM v0.1
                  |
     Institutional Policy release
```

The service boundary owns coordination durability, not money, account controls, specialist decisions or case work-state authority.
