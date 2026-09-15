# Queue Fabric Gateway Reliability Contract — development seam

This document extends the v0.3 browser gateway framing without changing the
`WIRE-UI/0.1` semantic application protocol.

The gateway is a trust boundary. It owns Queue Fabric credentials, CLAIM / ACK /
NACK and claim tokens. Browser code never receives a Queue Fabric claim token.

## Outbound browser -> Queue Fabric

Browser sends:

```json
{
  "type": "QUEUE_PUT",
  "clientPutId": "browser-message-id",
  "queue": "WIREUI.AP.IN",
  "correlationId": "optional",
  "payload": { "type": "UI_ACTION" }
}
```

A gateway may operate in fire-and-forget mode, or return:

```json
{
  "type": "QUEUE_PUT_RESULT",
  "clientPutId": "browser-message-id",
  "accepted": true,
  "packageId": "queue-package-id",
  "code": "OK"
}
```

Rejected PUTs use `accepted:false` plus `code` / `detail`.

`clientPutId` is browser correlation only. Queue Fabric remains authoritative
for the resulting package identity.

## Inbound Queue Fabric -> browser

Gateway claims from the access-point OUT queue and sends:

```json
{
  "type": "QUEUE_DELIVERY",
  "deliveryId": "opaque-gateway-id",
  "deliverySequence": 17,
  "package": {
    "packageId": "pkg:991",
    "sequence": 44018,
    "payload": { "type": "UI_VIEW_PATCH" }
  }
}
```

`deliverySequence` is contiguous for one logical browser delivery stream.
`package.sequence` is the original manager-wide Queue Fabric sequence and is
retained only as provenance.

After the semantic message has completed browser-side dispatch, the browser
sends:

```json
{
  "type": "QUEUE_DELIVERY_ACK",
  "deliveryId": "opaque-gateway-id",
  "messageId": "pkg:991"
}
```

If semantic dispatch throws before completion:

```json
{
  "type": "QUEUE_DELIVERY_NACK",
  "deliveryId": "opaque-gateway-id",
  "messageId": "pkg:991",
  "reason": "bounded diagnostic text"
}
```

The gateway maps the opaque `deliveryId` back to its private Queue Fabric
package/claim-token tuple and performs ACK/NACK there.

## Gateway delivery discipline

The simplest correct v0.1 gateway implementation should permit only one
unacknowledged Queue Fabric delivery per access point. This gives naturally
contiguous browser delivery ordering and avoids requiring the browser to hold a
large durable reorder window.

If later gateways pipeline claims, `deliverySequence` remains the logical
ordering authority and unacknowledged packages must remain recoverable across a
WebSocket disconnect.

## Backward compatibility

A v0.3 gateway may omit `deliveryId`. JS remains compatible and simply does not
emit a gateway delivery ACK/NACK frame for such deliveries.

`QUEUE_PUT_RESULT` is likewise optional unless the JS transport is configured
with `putResultMode: "required"`.
