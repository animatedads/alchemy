# Messaging & Presence instrumentation

Baseline: `instrumentation.mesh/0.1`, originally qualified against `oorexx_instrumentation_mesh_v0.1-dev3`.

Instrumentation is an observer of authoritative Messaging & Presence facts. It is not a second messaging protocol, history database, Intention service, or management bypass.

The adapter emits the mesh's standard request and I/O vocabulary plus service counters for messaging send/receive and presence publish/query/observe/subscribe/unsubscribe, plus provider/transport state.

Wire bytes use common `io.bytes.in.total` and `io.bytes.out.total` and are counted by the transport decorator after the authoritative transport reports accepted/read bytes. They are not inferred from message body size.

Register `MessagingPresenceInstrumentation` with an `InstrumentationRegistry`. Standard Instrumentation service/publisher/collector components provide publication and `LATEST`/`HISTORY`/`SERIES`; no duplicate history is implemented here.

The instrumentation capability advertises no management commands. Message sending, presence publication and subscription remain on normal Messaging/Presence and Intention paths.
