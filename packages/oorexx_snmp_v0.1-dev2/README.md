# ooRexx SNMP v0.1-dev2

Second executable object-model cut for a native ooRexx SNMP service.

The core rule remains: **OIDs belong to the protocol implementation; managed objects and events belong to applications.**

This cut extends the `/0.1` API without requiring generated Rexx classes for MIB objects.

## What dev2 proves

- JSON implementation maps define dynamic SNMP properties consumed through `UNKNOWN`.
- map-defined aliases project protocol names into application vocabulary (`sysName` -> `name`, `ifTable` -> `interfaces`).
- aliases are scope-aware, so the same application name can mean different mapped properties on an agent and on a table row.
- dynamic setters route through the same projection map and retain SNMP access control (`read-only`, `read-write`, etc.).
- tables discover their rows from the mapped INDEX column and expose ordinary managed row objects.
- `do row over router~interfaces` works through the table's collection projection.
- semantic event rules live in the implementation map and support threshold/edge semantics such as ENTER/EXIT.
- applications can register using semantic rule names: `sensor~on('temperatureCritical', ...)`.
- notification names are also valid registration vocabulary: `wan~on('linkDown', ...)`.
- incoming notification varbinds seed the managed object's observed state before the semantic event is published.
- managed state carries generations and retained detached snapshots.
- the observation view satisfies ooRexx Observation v0.5 without making Observation a hard dependency of the SNMP core.
- implementation-map schema `/0.2` remains backward compatible with `/0.1` maps.

## Application-facing shape

```rexx
router = .SnmpAgent~new('core-router', session, implementationMap)

say router~name
say router~description

wan = router~interfaces[17]
say wan~description
say wan~operStatus

wan~adminStatus = 'down'

wan~on('linkDown', alarm, 'failed')
```

A vendor sensor map can add semantics without adding source methods:

```rexx
sensor~adopt(vendorMap)

say sensor~temperatureCelsius
sensor~on('temperatureCritical', cooling, 'emergency')
```

The application does not need the underlying OID, ASN.1 syntax, wire enumeration, notification OID, or threshold definition.

## Dependencies

Required:

- ooRexx 5.3.0 r13196 or compatible
- `json.cls` from the ooRexx distribution
- ooRexx Event Runtime `event.runtime/0.1` (`EventRuntime.cls`)

Optional integration qualified in this cut:

- Observation v0.5 (`Observation.cls`)

Planned wire/security/provider work:

- Foreign Runtime for native socket/ABI crossings
- Crypto for SNMPv3 authentication/privacy
- Runtime Registry / Component Projection for resident service discovery and inspection

`SnmpMemoryTransport` remains an executable qualification transport. It is not presented as an SNMP wire implementation.
