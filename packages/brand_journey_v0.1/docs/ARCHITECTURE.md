# Brand Journey v0.1 architecture

```text
Chat / support / delivery / billing / sales access points
                 |
        correlation is external
                 v
        Interaction Event / Brand Episode
                 |
                 v
        Brand Journey Touchpoints
             + Handoffs
                 |
                 v
       Journey continuity assessment
                 |
       +---------+----------+
       |                    |
       v                    v
Brand Interaction Effect   longitudinal/statistical analysis
```

## Boundary

Brand Journey is **not CRM**.  It does not discover people, own customer identity,
store raw conversations, or decide that two sessions belong to one person.
An external component supplies correlation.  `relationshipRef` is protected
`SECRET`; the journey carries privacy-minimised semantic residue.

It is also not telemetry.  Access points belong elsewhere.  A touchpoint may
reference upstream evidence, but the package does not own mouse, billing, chat,
page-navigation, delivery or CRM instrumentation.

## Service as Sales

Support and delivery are customer-facing brand experiences.  They can therefore
be `PROMOTIONAL_WORK`, `REPUTATIONAL_WORK` and
`COMMERCIAL_RELATIONSHIP_WORK` even when `EXPLICIT_SALESPROP=false`.

That does **not** grant authority to sell.  The model keeps these separate:

```text
brand significance != sales intent
brand opportunity   != action authority
Service as Sales    != upsell mandate
```

## Cross-department continuity

The customer experiences one organisation even when the backend sees Support,
Delivery, Billing and Sales.  Handoffs therefore record whether context was
carried, whether the customer had to repeat information, whether an unresolved
need crossed the boundary, and the time gap when known.

A later recovery does not erase earlier context loss.  Both remain evidence.
