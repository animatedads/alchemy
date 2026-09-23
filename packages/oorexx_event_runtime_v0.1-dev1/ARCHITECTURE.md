# ooRexx Event Runtime v0.1-dev1

This is a small provider-neutral event substrate for the wider ooRexx API estate.
It is deliberately not an exception bus and deliberately not a wrapper around a
polling loop.

## Core rule

Application layers should state *what relationship they want*:

```rexx
source~when(filter)~fire(target,'attach')
```

Providers own native I/O. Domain APIs turn native facts into typed events. The
event runtime owns registration and dispatch. Observation owns retained passive
history. Policy/permissions own whether consequential actions are authorised.

## ooRexx semantics used deliberately

* Methods on the dispatcher are guarded by default. Registration state therefore
  belongs to the dispatcher object, rather than attempting to `GUARD` an
  arbitrary Directory or List.
* `publish` snapshots matching registrations, then executes `GUARD OFF` before
  invoking application code. Callbacks can safely register/unregister handlers.
* `Object~sendWith()` is synchronous.
* `Object~startWith()` is asynchronous and returns the real ooRexx Message
  object. Async delivery therefore has completion/error/result semantics already
  supplied by the language runtime.
* `GUARD ON WHEN` is for conditions over exposed object variables. A producer
  that needs to wake a waiting activity must mutate an exposed condition
  variable; changing only the internals of a referenced Queue/List is not the
  GUARD wake-up contract.
* `RAISE USER` remains a condition/exception mechanism propagating through the
  caller/sender condition chain. Ordinary publish/subscribe events do not use it.

## Separation

```
native provider -> domain object -> EventSource -> registrations/triggers
                                  -> Observation (retained facts)
                                  -> action authority/policy (side effects)
```

A subscription records interest. A trigger records a conditional behaviour
binding. Both are first-class EventRegistration objects with identity, enable
state, delivery mode, fire count and last delivered event.

## Intended consumers

Device Runtime, USB, ADB, Bluetooth, MQTT and SNMP are natural consumers. SNMP
should publish semantic managed-object events rather than exposing numeric OIDs
to ordinary application code; Bluetooth should publish discovery, connection and
GATT value events rather than expose BlueZ/WinSock mechanics above its provider.
