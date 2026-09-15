# Relationship CRM v0.1 architecture

```text
Customer Master / Core Banking        Interaction Event
          |                                 |
          | opaque subject/account refs     | opaque interaction refs
          v                                 v
                  Relationship CRM
       relationship / communication / task / promise
              complaint recognition / profile
                         |
                         | typed opaque references
                         v
                 Relationship Case
                         |
         specialist evidence / decisions / controls
```

The relationship domain is authoritative for **servicing relationship facts**, not monetary or specialist truth.

## Complaint distinction

CRM owns that the customer interaction has been recognised as a complaint and the relationship handling around it.  Relationship Case owns durable cross-system work state.  Legal/Policy modules own applicable obligations.  Core Banking owns any account/payment action.

## Service profile distinction

A `RelationshipServiceProfile` is a policy-derived servicing instruction such as preferred channel or callback-first handling.  It is not a customer risk decision, legal conclusion, account limit or authorisation.

## Information barriers

Projection is policy.  A teller may see general servicing work while restricted complaints are omitted; Complaints/Compliance can receive richer projections.  This is enforced before the UI boundary.
