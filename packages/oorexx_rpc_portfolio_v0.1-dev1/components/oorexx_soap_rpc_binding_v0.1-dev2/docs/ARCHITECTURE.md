# SOAP binding: independent authorities

1. **ConnectSelector** decides how bytes or an invocation travel. Nothing in SOAP selects a queue, opens a socket, retries, or infers durability. `SoapConnectAdapter` is optional; it requires the actual ConnectSelector v0.1-dev2 classes. SOAP document/literal request/reply only supports REQUEST; an operation being named `notify` does not make it a JSON-RPC notification.
2. **SerializationSelector** owns explicit codec selection. `SoapEnvelopeCodec` is a new SOAP XML codec with separate request/response direction constraints. The existing `SerializationBuiltin.cls` maps JSON-typed objects into XML and is expressly insufficient for native namespace-aware SOAP envelopes. Registration is optional and namespaced; SOAP does not override `xml` or `json`.
3. **RpcServiceDispatcher** owns operation authorization via an explicit `(service,operation)` allowlist and calls one handler signature `invoke(operation,args,context)`. It returns a protocol-neutral `RpcServiceResult` or `RpcServiceFault`. `RpcJsonServiceBridge` and `SoapRpcServer` are binding-specific translations into this shared framework. Service exception detail is not disclosed across envelopes.
4. **SOAP envelope** owns namespace validation, SOAP 1.1 vs 1.2 differences, SOAP faults, headers and document/literal encoding. Use a real libxml2 parser; never regex-parse XML, invoke arbitrary `~send` method names, or use `jsonToXml` as a SOAP substitute. SOAPAction will be HTTP binding metadata only, not dispatch authority.
5. **Queue and JMS semantics** remain with ConnectSelector and their own bridge. Serialization never confers acknowledgement, persistence, transactionality, ordering or exactly-once guarantees.

## Deliberate v0.1 restrictions

Only one body child (operation), local scalar named parameters and a single scalar `return` child in replies. Reject nested graphs, SOAP encoded style, entity expansion, DTDs, all `mustUnderstand` headers (until approved handlers exist), unknown type coercion and unexpected operation namespaces. SOAP version mismatch yields a VersionMismatch fault. The output writer escapes values and emits namespace-qualified SOAP operations and XML Schema-typed boolean/nil responses.

No live SOAP-over-HTTP binding was qualified. Authentication, HTTP status and transport-level TLS remain deliberately outside this package. Later deployments may inject a real HTTP transport into client `exchange(requestXml)` and pass HTTP metadata through a separate binding; transport selection must still be made by ConnectSelector.

## Service-error classification

- `NOT_FOUND` => SOAP Sender / SOAP 1.1 Client, "Operation not found".
- `INVALID_ARGUMENT` => SOAP Sender / SOAP 1.1 Client, explicit validated argument reason from the service.
- All other generic faults and unhandled exceptions => SOAP Receiver / SOAP 1.1 Server, "Service execution failure"; no exception text leaks.

JSON-RPC keeps its own JSON-RPC 2.0 message/error envelopes and uses the same neutral dispatcher through `RpcJsonServiceBridge` (faults map to -32601/-32602/-32603 respectively). This is **not** SOAP transformed into JSON or a single combined wire protocol.

Future versions need WSDL/XSD contract validation and service identity/authorization independently of method names, scoped authentication context, HTTP Content-Type/SOAPAction handling, XML Signature/WS-Security verification if required, complex/array value model and interop probes against third-party SOAP implementations.


## Dev2 dependency split
`RpcServiceCore.cls` has been extracted as the authoritative `oorexx_rpc_service_core_v0.1-dev1` package. SOAP dev2 does not ship this class. Configure `RPC_CORE_ROOT` and add its `src` directory to `REXX_PATH`; unresolved dependency is an error. `registerMethod` publishes explicit service-object methods while SOAP retains XML envelope authority.
