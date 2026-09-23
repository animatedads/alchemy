# Architecture

## 1. Separation of concerns

```text
application behaviour
        |
managed objects / UNKNOWN projection
        |
semantic aliases + event rules
        |
implementation map (semantic adoption)
        |
MIB / vendor protocol definitions
        |
SNMP session
        |
transport + BER/PDU engine
        |
UDP/TCP/TLS/native runtime
```

A MIB says what a protocol object is. An implementation map says how that protocol object is projected into the ooRexx object model. They are related but deliberately not conflated.

## 2. UNKNOWN is the projection seam

`SnmpManagedObject~UNKNOWN` resolves messages through the active implementation map.

Resolution order for a getter is:

1. directly mapped object definition;
2. directly mapped table;
3. scope-appropriate semantic alias to an object or table;
4. normal ooRexx unknown-message failure.

A setter follows the same property projection and then applies the mapped SNMP access/encoding rules.

No generated `sysName`, `ifOperStatus`, vendor-sensor or model-specific methods are required.

## 3. Scoped semantic aliases

Protocol vocabulary is not required to become application vocabulary.

Example map:

```text
AGENT:
  name        -> sysName
  description -> sysDescr
  interfaces  -> ifTable

TABLE:ifTable:
  description -> ifDescr
  adminStatus -> ifAdminStatus
  operStatus  -> ifOperStatus
```

The same alias name may be defined in different scopes. This permits a stable application model over different MIB/vendor implementations.

## 4. Tables are object collections

A `SnmpManagedTable` uses the table's mapped INDEX definition to walk the transport and discover instance suffixes. Those suffixes become `SnmpIndex` identities and are projected as `SnmpManagedRow` objects.

Application code can therefore use:

```rexx
do interface over router~interfaces
    say interface~description interface~operStatus
end
```

Composite index typing remains a future extension; the current identity preserves the complete instance suffix rather than discarding it.

## 5. Events are semantic state transitions

Protocol evidence is not itself the application event.

```text
GET observes ifOperStatus up -> down ----+
                                         +--> INTERFACE.LINK.DOWN
linkDown notification ------------------+
```

Dev2 adds map-level semantic event rules. A rule names:

- source property;
- comparison operator/value;
- edge (`ENTER`, `EXIT`, `CHANGE`, `ALWAYS`);
- application event type;
- object/table scope.

The application may register by semantic rule name rather than event constant:

```rexx
sensor~on('temperatureCritical', target, 'handleCritical')
```

Notification names are resolved the same way:

```rexx
interface~on('linkDown', target, 'failed')
```

## 6. Notification evidence updates state

An incoming notification is an observation. Resolved varbinds that belong to the targeted managed object are seeded into its retained state before the semantic notification event is published.

The seed operation does not manufacture a second transition event. The explicitly mapped notification remains the evidence path for that packet.

## 7. Observation integration

Each managed object retains a bounded history of detached `SnmpObservationSnapshot` objects. `SnmpObservationView` presents the existing Observation v0.5 read-only contract:

```text
sessionId / terminalType / deviceName
snapshot / current / back / history
knownStateStatus / knownStateId / knownStateGeneration / knownStateHistory
```

Observation is deliberately shape-compatible rather than a hard class dependency. The SNMP package can run without Observation installed; when Observation is available, the view validates directly with `ObservationProtocol` and can be published through `ObservationStream`.

## 8. Layered adoption

An agent may adopt maps in order:

```text
SNMPv2-MIB / IF-MIB
    + vendor family
    + exact model
    + site-local semantics
```

Later layers replace object, notification, alias and semantic-rule definitions under stable identities. Stale reverse OID mappings and replaced semantic rules are cleaned up.

## 9. Transport boundary

The current executable transport contract is:

```text
get(oid)
set(oid, value)
walk(baseOid)
```

The initial cut supplies `SnmpMemoryTransport` for qualification. BER/PDU, request correlation, retry/timeout, SNMPv1/v2c/v3 and UDP/TCP concerns remain below `SnmpSession`.

SNMPv3 security is expected to consume shared Crypto services rather than embedding private-key/password primitives into managed objects.
