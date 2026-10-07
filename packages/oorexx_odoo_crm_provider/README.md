# ooRexx Odoo CRM Provider v0.1-dev7.1.1

Discovery-driven Odoo 20 JSON-2 provider for Relationship CRM and SIP/CRM correlation.

## dev4: live remote object graph

`OdooObject` remains the primary remote-backed object and is composed from Object-based mixins:

- `OdooRemoteBackedMixin` — provider/model/id identity and shared state.
- `OdooDiscoveryMixin` — `fields_get`, `discovery.operation`, `UNKNOWN`, dynamic `Method` creation and `~performDiscovery`.
- `OdooRelationMixin` — discovered Odoo relation materialisation and safe write normalisation.
- `OdooMutableRemoteMixin` — read-through getters, write-through setters and `~update`/`~refresh`.
- `OdooUpdateEventMixin` — `OdooUpdateEvent` publication for local and remote changes.

### Relation behaviour

Discovered field metadata drives relation projection automatically:

- `many2one` -> one live `OdooObject` (or `.nil`).
- `one2many` -> Array of live `OdooObject` instances.
- `many2many` -> Array of live `OdooObject` instances.

Related objects keep their own model/id identity and participate in the same EAGER/LAZY discovery rules. Missing scalar fields use read-through hydration, so a related object created from only an Odoo ID can be investigated naturally.

Relation objects are cached per source field while the backing remote identity is unchanged. `~update` invalidates a relation cache entry when the backing value changes.

A mutable `many2one` accepts another `OdooObject` and writes its remote ID. Direct `one2many`/`many2many` assignment fails closed with `ODOO_RELATION_WRITE_REQUIRES_COMMAND`; Odoo command semantics must be represented by an explicit local discovered operation rather than guessed.

### Discovery and UNKNOWN

`discovery.operation` remains local declarative adapter policy. Models can use `EAGER` discovery on `~new` or `LAZY` discovery on first `UNKNOWN`. `~performDiscovery` is always available explicitly.

Remote schema data never supplies executable Rexx source. The provider creates small local `.Method` wrappers from trusted local templates and attaches them with `setMethod()`.

### Live CRM objects

Raw compatibility methods remain available, but the SIP/CRM bridge now uses object-returning provider methods:

- `~findContactObjectsByPhone`
- `~contactObjectsById`
- `~leadObjectsForPartner`

Thus a correlated call context contains live `OdooObject` contact and lead instances rather than anonymous directories.

Example:

```rexx
ctx = bridge~resolveInbound("sip-call-123", "07342209126")~value
partner = ctx~partner
say partner~name
say partner~phone

lead = ctx~leads[1]
say lead~name
say lead~partner_id~name

partner~onUpdate(listener)
partner~update
```

Runtime HTTPS is supplied by the portfolio `oorexx_api_client_v0.4.1`; this package does not use Python `requests` or curl at runtime.


## dev5 live model space

Adds discovery-driven `OdooModel` and `OdooModelSpace`. Model operations are declared locally in `discovery.operation`, installed dynamically on first use with `UNKNOWN`/`setMethod`, and return live `OdooObject` records. Supported declared operation kinds include browse, search-to-live-objects, search_read-to-live-objects, and create-to-live-object. The namespace facade supports `provider~modelSpace~res~partner` and `~crm~lead`; explicit `provider~model("res.partner")` remains available. Native Phone models intentionally omit create operations until Odoo's own external-SIP creation semantics are proven.


## dev6 live retained queries

Adds `OdooLiveQuery`, a retained discovery-gated remote collection. A query stores its model, domain, selected fields, limit and order; `~update`/`~refresh` re-runs `search_read` through the provider and reconciles membership by `(model,id)`.

Surviving records retain the same `OdooObject` identity and are merged in place. Record-level changes continue to emit `OdooUpdateEvent` with reason `QUERY_REFRESH`; the query additionally emits `OdooQueryEvent` with kinds `ADDED`, `REMOVED`, and `UPDATED`. The initial population is intentionally quiet, and a stable refresh emits no events.

Example:

```rexx
leadModel = provider~modelSpace~crm~lead
r = leadModel~liveQuery(domain, .array~of("id", "name", "partner_id"), 100, "id")
if r~ok then do
    openLeads = r~value
    openLeads~onUpdate(listener)
    say openLeads~items
    callResult = openLeads~update
end
```

`~liveQuery` and `OdooLiveQuery~update` both require `OdooModel~ensureDiscovery`; an undeclared model therefore cannot use retained queries to bypass `discovery.operation`.

### dev7: provider-wide object identity

All record-returning paths now converge through one weak identity map.  The
same Odoo `(model,id)` reached via `browse`, `searchRead`, a relation, or two
independent `OdooLiveQuery` instances is the same ooRexx `OdooObject` while it
is live.  The map uses ooRexx `.WeakReference`, so canonicalization does not
pin abandoned CRM records in memory.
