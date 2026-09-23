# Changelog

## 0.1-dev2

- Added implementation-map schema `snmp.implementation.map/0.2`, while retaining `/0.1` loader compatibility.
- Added scoped semantic aliases for application-facing names over MIB/vendor object names and tables.
- Added `UNKNOWN`-driven alias getters and setters.
- Added map-defined semantic rules with comparison and ENTER/EXIT/CHANGE/ALWAYS edge handling.
- Added registration by semantic rule name and notification name.
- Added table row discovery by walking the mapped INDEX column; `SnmpManagedTable` is now DO-OVER compatible.
- Added notification-state seeding before semantic event publication.
- Added retained SNMP state generations, detached snapshots and an Observation-v0.5-compatible read-only view.
- Added cleanup semantics for replaced notifications and semantic rules during layered adoption.
- Added tests for aliases, table enumeration, threshold events, notification state, Observation integration and `/0.1` map compatibility.

## 0.1-dev1

- Initial implementation-map/UNKNOWN object projection.
- Scalar and table-column GET/SET projection.
- Layered map adoption.
- Exact state-transition events and notification projection.
- In-memory qualification transport.
