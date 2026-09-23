# ooRexx Event Runtime v0.1-dev1

Typed, first-class event registrations for ooRexx.

Classes:

- `Event`
- `EventFilter`
- `EventRegistration`
- `EventDispatchResult`
- `EventDispatcher`
- `EventBinding`
- `EventSource`

No shell, no native dependency, and no invented mutex abstraction. It uses the
ooRexx object guard and Message facilities directly.

Run:

```sh
./run_tests.sh
```

Design consumers included in this cut:

- `docs/SNMP_MODEL.md`
- `docs/BLUETOOTH_MODEL.md`
