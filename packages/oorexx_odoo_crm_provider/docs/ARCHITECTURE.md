# Architecture — discovery-driven Odoo object graph

## Authority split

- Odoo remains provider-side CRM data authority.
- Relationship CRM remains application relationship/interaction authority.
- ooRexx SIP remains signalling/media authority.
- `OdooObject` is a live provider projection, not a replacement for either domain authority.

## Object composition

`OdooObject` inherits a small set of Object-based mixins. Mixins collaborate only through `~odooState`; they do not assume that `EXPOSE` variables are shared across mixin method scopes.

## Discovery

1. Read the local `discovery.operation` policy.
2. Call Odoo `fields_get` through the injected provider transport.
3. Cache field metadata including type/relation/read-only flags.
4. Build trusted local getter/setter/operation methods with `.Method~new`.
5. Attach methods to that object instance with `setMethod()`.
6. Redispatch the original message after lazy discovery.

## Relation graph

A discovered relational getter interprets Odoo field metadata:

```
crm.lead.partner_id (many2one -> res.partner)
       |
       +--> OdooObject(res.partner, 10)
                 |
                 +--> name / phone / email ...

res.partner.child_ids (one2many -> res.partner)
       |
       +--> Array[ OdooObject(...), ... ]
```

Only remote identity is needed to construct a related object. Missing values are hydrated on first getter access. Relation cache entries are invalidated when the raw relation value changes during local write or remote refresh.

## Mutation

Scalar writes use Odoo `write`. `many2one` can safely normalize a related `OdooObject` to its remote ID. Collection-relation mutation is deliberately not inferred because Odoo `one2many`/`many2many` writes require command semantics; those must be named local operations in `discovery.operation` before being exposed.

## Events

`OdooUpdateEvent` carries source, model, record ID, changed fields, old/new values and reason. Current reasons are `LOCAL_WRITE` and `REMOTE_REFRESH`.


## dev6 retained query objects

`OdooLiveQuery` is the model-level live collection projection. It is not a polling scheduler; callers decide when to invoke `~update`/`~refresh`. Query membership is keyed by remote record id and surviving `OdooObject` instances are retained. New ids produce `ADDED`, missing ids produce `REMOVED`, and changed snapshots merge into the existing object and produce `UPDATED`. Query refresh is discovery-gated through the locally authorized `OdooModel`.

## Provider-wide canonical object identity (dev7)

`OdooCRMProvider~odooObject(model,id,...)` is the canonicalization point for
all record materialization.  The provider keeps `(model,id) -> WeakReference`
entries, so browse, search/searchRead, live queries and discovered relations
converge on the same live `OdooObject` while the application retains it.

Fresh seed data is merged into an existing canonical object with reason
`IDENTITY_MERGE`.  Ordinary record listeners therefore observe a real changed
field regardless of which provider path delivered the fresher representation.
The weak identity map itself does not keep otherwise-unused records alive.

Lifecycle/introspection operations:

* `identityObject(model,id)` -- return the current canonical object or `.nil`.
* `identityObjectCount()` -- count live canonical records, pruning dead weak refs.
* `purgeIdentityMap()` -- remove cleared weak references.
* `evictIdentityObject(model,id)` -- deliberately stop canonicalizing to a
  particular wrapper; existing application references remain valid objects.
