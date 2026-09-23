# Wire3D v0.1-dev8 — existing live gateway integration

Dev8 deliberately does **not** add a WebSocket server or a second Queue Fabric browser gateway.

The integration boundary is the already-qualified stack:

`WireUIServer -> Queue Fabric -> Queue Fabric Web Gateway v0.2 -> Alchemy Wire UI JS QueueFabricGatewayTransport -> Wire3DLiveClient -> Wire3DRenderer`

## ooRexx publisher

`Wire3DWireUIPublisher` is a thin adapter around the existing `WireUIServer~enqueueToAccessPoint()` method. It publishes semantic `WIRE3D_SNAPSHOT` and `WIRE3D_DELTA` messages. The server continues to own queue naming/provisioning and Queue Fabric continues to own package identity and delivery.

## Browser

`Wire3DLiveClient` accepts the existing `QueueFabricGatewayTransport`; it does not know WebSocket framing, queue-manager credentials, claim tokens or Queue Fabric package disposition details.

A delivery is ACKed only after the Wire3D semantic snapshot/delta has been successfully applied. A revision-fence or semantic failure is NACKed through the existing transport. Thus a bad delta cannot be acknowledged merely because it reached the browser.

The convenience `connectWire3DThroughExistingGateway()` dynamically imports the deployment-provided Alchemy Wire UI JS module. Wire3D does not vendor that package.

## Authority

This is a projection channel. Browser delivery does not grant authority over the projected domain object. Interactive commands remain a separate future adapter and must pass through the owning subsystem's authority checks.
