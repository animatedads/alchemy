# SNMP as an ooRexx object/event model

The application-facing API must not be a bag of OID strings. Numeric OIDs are
wire identity and provenance; MIB definitions provide semantic identity.

## Layers

```
UDP/TCP/TLS/DTLS provider
        |
SNMP codec + v1/v2c/v3 message/security processing
        |
MibRepository / MibModule / MibObjectDefinition
        |
ManagedAgent
  +-- ManagedScalar
  +-- ManagedTable
  +-- ManagedRow
  +-- ManagedInterface (semantic projection where a MIB defines one)
        |
EventSource + Observation
```

Proposed classes include `SnmpEngine`, `SnmpSession`, `SnmpVarBind`,
`SnmpNotification`, `MibRepository`, `MibModule`, `MibObjectDefinition`,
`MibTableDefinition`, `ManagedAgent`, `ManagedObject`, `ManagedTable` and
`SnmpMonitorRegistration`.

## Event model

Polling and notifications are two providers of the same semantic facts. A
monitor registration can own cadence, threshold, hysteresis, deduplication and
freshness. Trap/inform reception can update the same managed-object state and
emit the same event families.

Examples:

- `SNMP.AGENT.REACHABLE`
- `SNMP.AGENT.UNREACHABLE`
- `SNMP.OBJECT.CHANGED`
- `SNMP.THRESHOLD.CROSSED`
- `SNMP.TABLE.ROW.ADDED`
- `SNMP.TABLE.ROW.REMOVED`
- `SNMP.NOTIFICATION.RECEIVED`
- semantic projections such as `SNMP.INTERFACE.LINK.DOWN`

Each event retains raw PDU/varbind/OID provenance where useful, but ordinary
application code consumes named MIB objects and domain objects.

Desired application shape:

```rexx
router = snmp~agent('core-router')
wan = router~interface('wan0')

wan~when(.SnmpEventFilter~linkDown)~fire(alarm,'raiseLinkAlarm')
wan~when(.SnmpThreshold~new('inUtilisation',80,5))~notify(graph,'recordHighLoad')
```

No application should need to remember `1.3.6.1...` unless it is explicitly
working with unknown/private MIB material.
