# XTP dev24 named-service + SORT repair (review candidate)

A named service is encoded in FIRST. In dev24 the ooRexx provider
`XtpProviderSocket~send` dispatched all named-service writes to
`xtpNativeSendService`, discarding the configured `priorityMode` and
`prioritySort`. This also affected `XtpOperationalSocket~send`, which
uses priority derived from the Operational Planner.

The new `xtpNativeSendServicePriority` entrypoint transmits the service
name and priority in one native `SendOptions` value; it does not replace
the existing unprioritised named-service ABI. The sender selects that
entrypoint only when priority is enabled. The receiver's loopback
diagnostic now includes `priority` and `sort`.

Regression: `make test-service` and `make test-native-service-priority`
with `REXX_BIN` pointing to an ooRexx interpreter and matching headers.
No live ED209, raw36, multicast or persistent FIRST/KEY WAN qualification
is implied. Capacity, transformation and persistent-context limits remain
separate unresolved design boundaries.
