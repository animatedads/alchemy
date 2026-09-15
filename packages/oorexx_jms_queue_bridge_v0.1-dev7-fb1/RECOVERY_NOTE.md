# v0.1-dev7-fb1 delivery recovery

FederationBank Engine v0.8 names `oorexx_jms_queue_bridge_v0.1-dev7-fb1`, but that ZIP was not delivered in the later API roll-up. A previously written `oorexx_jms_queue_bridge_v0.1-dev7-fb1-fbcompat.zip` was recovered from project file history and its original `MANIFEST.sha256` verified before modification. This delivery is therefore based on the recovered source rather than a reimplementation from memory.

Before sealing the shared dependency, live BSF4ooRexx/JMS testing exposed and repaired three adapter-edge defects that deterministic tests could not see:

- `JMSBSFProvider~send` now exposes `config`, which it reads after the broker send to select the completion result.
- Java `Connection.start()` is dispatched with `~bsf.invoke("start")` at connect/probe/flow-probe sites so ooRexx does not intercept it as `Object~start`.
- Java `MessageProducer.send(Message)` is dispatched with `~bsf.invoke("send", javaMessage)` so ooRexx does not intercept it as `Object~send`.
- Java enumeration values returned by ActiveMQ are canonicalised through `javaString()` rather than blindly invoking Java `toString()` on values BSF4ooRexx has already converted to ooRexx strings.

These repairs do not change the public bridge API, Queue Fabric settlement model, or durable `alchemy.jms.message/0.1` representation. The recovered FederationBank MAP/property/correlation semantics remain intact.

Qualification used the supplied ooRexx 5.3.0 r13196 runtime and BSF4ooRexx v850 refresh, with the ActiveMQ 5.18.3 client/broker carried by the sealed IJCIB test system. The real edge test passed 24 checks covering inbound/outbound MAP, TEXT compatibility, application JMS properties, reserved bridge metadata, correlation, JMS type, and CLIENT_ACK settlement.

This is a delivery recovery with pre-delivery repairs; it is not claimed byte-identical to the undelivered original working copy.
