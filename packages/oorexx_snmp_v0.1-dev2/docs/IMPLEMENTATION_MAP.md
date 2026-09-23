# SNMP implementation map /0.2

The implementation map is a runtime object-projection contract. It is not merely an OID constants file.

The `/0.2` loader accepts both `snmp.implementation.map/0.2` and the previous `/0.1` schema.

## Top-level fields

- `schema`
- `name`
- `objects`
- `tables`
- `notifications`
- `aliases` (new in `/0.2`)
- `eventRules` (new in `/0.2`)

## Objects

Object fields currently implemented:

- `name`
- `oid`
- `kind`: `scalar` or `column`
- `table` for a column
- `syntax`
- `access`
- `enum`: wire-number to symbolic-value mapping
- `events`: exact old/new transition to semantic event type
- `metadata`

`events` remains useful for discrete state machines such as `ifOperStatus`.

## Tables

Table fields:

- `name`
- `oid`
- `index`: one or more mapped index object names
- `metadata`

Dev2 uses the first mapped INDEX column as the discovery walk and preserves the complete instance suffix as `SnmpIndex`. Typed decomposition of complex INDEX clauses is intentionally left for a later MIB/type layer.

## Notifications

Notification fields:

- `name`
- `oid`
- `eventType`
- optional `targetTable`
- optional `indexVarbind`
- optional `metadata`

A notification name is also a semantic registration name.

## Aliases

Aliases project protocol vocabulary to application vocabulary.

```json
{
  "name": "interfaces",
  "target": "ifTable",
  "kind": "table",
  "scope": "AGENT"
}
```

Fields:

- `name`: public/application name
- `target`: mapped object or table name
- `kind`: `property`, `table`, or `auto`
- `scope`: `*`, an object kind such as `AGENT`, or `TABLE:<tableName>`
- optional `metadata`

## Semantic event rules

Rules turn observed values into named application events.

```json
{
  "name": "temperatureCritical",
  "property": "temperature",
  "operator": "GE",
  "value": 80,
  "edge": "ENTER",
  "eventType": "SENSOR.TEMPERATURE.CRITICAL",
  "scope": "AGENT"
}
```

Operators presently implemented:

- `EQ`, `NE`
- `GT`, `GE`, `LT`, `LE`
- `ALWAYS`

Edges presently implemented:

- `ENTER`: predicate false -> true
- `EXIT`: predicate true -> false
- `CHANGE`: value changed and new value satisfies predicate
- `ALWAYS`: every changed observation satisfying the predicate

Rules are evaluated only after a baseline has been established, so first observation does not accidentally become an alert.

## Design direction

The map is intentionally richer than MIB compiler output. Later versions may add:

- typed/scaled/composed properties;
- MIB-derived INDEX decoders;
- device personality matching and automatic adoption;
- poll/freshness policy;
- write read-back verification;
- notification correlation;
- evidence policy;
- provider quirks and model-specific amendments.

Those belong in reusable knowledge/projection layers, not application code.
