# Early deployment path

`web/preview.html` is a non-authoritative visual fixture and is the default for
`./start.sh`. It has no transport and cannot submit a banking action.

The live projection is `web/index.html`. It expects a browser-safe bootstrap
record containing an exact Wire UI JS module URL, Queue Fabric WebSocket
Gateway URL/outbound queue, and server-issued application/session/access-point
ownership. `./start.sh --live` can proxy an authoritative bootstrap URL or serve
a supplied browser-safe bootstrap JSON file.

`FederationBankStaffWireWebGatewayService` is the ooRexx-side seam between the
Staff Wire application and `WireUIServer`/Queue Fabric. A host creates the
existing Staff Channel Service, Staff Method Permission boundary and
`FederationBankStaffWireApplication`, then passes the application plus its
Queue Fabric manager/topic fabric into this service. The Queue Fabric Web
Gateway v0.2 bridges `WIREUI.IN.<accessPoint>` and `WIREUI.OUT.<accessPoint>` to
the browser transport.

The browser is never given a Staff Authority envelope or method-permission
bearer capability. It sends semantic intent; the server reconstructs and binds
the exact staff/session/branch/desk/action identity and performs each authority
decision independently.
