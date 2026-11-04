# RPC HTTPS ingress — authority and interface map

```
Accepted HTTPS connection + verified HttpExchangeContext
  -> trusted platform LDAP/session authority: authenticate request context
  -> RpcHttpsJsonGateway: POST, type/encoding/byte gate
  -> existing JsonRpcDispatcher / JsonRpcCodec: JSON-RPC 2.0 envelopes
  -> RpcHttpsPublishedRegistry: public name -> registered service+operation
  -> trusted authority: authorizeOperation per invocation / batch item
  -> existing RpcServiceDispatcher: invoke registered ooRexx object method
  -> JsonRpcDispatcher: result/fault/notification envelope
  -> existing HttpsServer HttpResponse: HTTP reply on original connection
```

**No new generic selector.** Connect Selector dev8 owns remote transport and its own authenticated route admission. Serialisation Selector owns configurable representations; JSON-RPC protocol's existing `json.cls` codec is unchanged in this cut. This binding does not implement SOAP XML, gRPC protobuf, HTTP/2 server, XTP, LDAP or private-CA provisioning.

An inbound caller never passes a raw target object or ooRexx receiver-method name. It supplies one published JSON-RPC method name, resolved exactly to an already-registered RPC Core operation. For callback registration this gateway refuses publication; gRPC owns those stateful, backpressured HTTP/2 sessions.

The adapter is independently distributable and leaves HTTPS/LDAP/RPC core packages unmodified; integration occurs by `server~route()` and registry injection.
