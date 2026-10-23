# ooRexx SOAP RPC Binding 0.1-dev2

**API:** `oorexx.soap_rpc_binding/0.1`  
**Qualification:** ooRexx 5.3.0 r13196 debug, Linux x86_64, libxml2 2.9.14.  
**Status:** Executable SOAP document/literal baseline, NOT a complete SOAP/WS-* stack.

SOAP, JSON-RPC, connection selection and serialization are separate concerns:

```
Application/service method (allowlisted)
       |
RpcServiceDispatcher  -> RpcServiceRegistry -> registeredObject~registeredMethod(args,context)
       ^                                ^
       |                                |
SOAP binding                      JSON-RPC 2.0 adapter
       |                                |
SOAP XML codec                    JSON-RPC json.cls
       |                                |
SerializationSelector (optional, explicit codecs for SOAP)
       |
ConnectSelector (optional, sole transport selection authority)
```

- **External required** `oorexx_rpc_service_core_v0.1-dev1/src/RpcServiceCore.cls` owns service registry and method dispatch. SOAP has no duplicate copy of that class.
- `SoapRpcBinding.cls` owns SOAP 1.1/1.2 document/literal envelopes, fault mapping, namespace-scoped service binding, and request/reply. It does NOT own connection choice or queue semantics.
- `SoapEnvelopeCodec.cls` uses libxml2 native parsing/writing, NOT the `SerializationBuiltin` JSON-mapped XML converter.
- `SoapSerializationRegistration.cls` installs **opt-in** named `soap-xml-request` and `soap-xml-response` providers in the existing `SerializationSelector` API.
- `RpcJsonServiceBridge.cls` optionally installs a handler within JSON-RPC Fabric's existing allowlisted method registry against the **same** RpcServiceDispatcher. Existing JSON-RPC Fabric is unchanged.
- `SoapConnectAdapter.cls` is an optional ConnectSelector connector SPI, supports immediate REQUEST only, rejects NOTIFY/ENQUEUE/durable semantics rather than fabricating confirmations.

## Executable scope

- SOAP 1.1 and 1.2 XML envelopes, namespace-qualified operation dispatch, document/literal wrapped requests and replies, SOAP Faults (1.1 Client/Server, 1.2 Sender/Receiver, VersionMismatch, MustUnderstand), SOAP header mustUnderstand checking (all mandatory headers refused; no header handlers installed).
- Request argument Directory of named **scalar XML values only**; optional `xsi:nil`, XML Schema boolean, and XML Schema string. Plain scalar values remain strings, including leading-zero numeric-looking text. A scalar return value is supported; complex graphs fail closed. The XML Schema namespace must be valid for typed primitives.
- Native libxml2 parsing with a 1 MiB limit, depth guard, disabled network access, explicit DTD/entity/encodingStyle rejection, and prevention of embedded NUL bytes, invalid XML control characters, duplicate parameters, mixed nested argument elements and unsupported `xsi:type` values.
- SOAP fault messages never include unexpected implementation exception text.
- No automatic request retries, no hidden provider selection, and no guarantee of notification delivery or durability.

## Build and test

Install a C++17 compiler, libxml2 headers/pkg-config. Pass the **specific** ooRexx headers (including for Termux/nonstandard installs):

```sh
make -C native OOREXX_INCLUDE=/exact/oorexx/include

OOREXX_RUNTIME_ROOT=/exact/extracted/runtime \
RPC_CORE_ROOT=/exact/oorexx_rpc_service_core_v0.1-dev1 \
SERIALIZATION_SELECTOR_ROOT=/exact/serialization_selector_v0.1 \
JSONRPC_ROOT=/exact/oorexx_json_rpc_fabric_v0.1-dev3 \
CONNECT_SELECTOR_ROOT=/exact/oorexx_connect_selector_v0.1-dev2 \
sh tests/run.sh
```

The included `native/libsoapxml.so` is built for **Linux x86_64 ooRexx 5.3.0 r13196 debug only**. Rebuild for any other platform/ABI; this binary is not a general-purpose portable artifact. `tests/run.sh` uses the supplied runtime root rather than guessing `rexx` or recursively choosing a duplicate package. Optional integrations are skipped when their exact paths are unset; partially configured integrations fail closed.

## Minimal usage

```rexx
registry = .RpcServiceRegistry~new
ignored = registry~registerMethod('catalog','echo',myServiceObject,'echoMethod')
dispatcher = .RpcServiceDispatcher~new(registry)
soapServer = .SoapRpcServer~new(dispatcher,'catalog','urn:alchemy:catalog:v1')
soapClient = .SoapRpcClient~new(.SoapLoopbackTransport~new(soapServer), -
                               'catalog','urn:alchemy:catalog:v1','1.2')
params = .directory~new
params['message'] = 'hello'
answer = soapClient~request('catalog.echo',params)
::requires 'SoapRpcBinding.cls'
```

An explicitly registered object method receives `(arguments,context)` and returns its result or `.RpcServiceFault~new('INVALID_ARGUMENT','reason')`. The earlier `register()` generic handler form remains supported by the external core. Unexpected handler exceptions are caught and masked. The same handler is projected to JSON-RPC through the optional `RpcJsonServiceBridge` and can be routed by the existing ConnectSelector without a SOAP-owned selector.

To use the serialization registry, explicitly import `SoapSerializationRegistration.cls`, call `registerSoapSerialization`, then inject `.SerializationSelector~new('soap-xml-request')` into the server and `.SerializationSelector~new('soap-xml-response')` into the client. SOAP never silently falls back to the generic XML provider.

## Not implemented / not claimed

- HTTP server/client, TLS, authentication, Authorization policy enforcement beyond the method/namespace allowlist, or live network interoperability (transport injection is present, not a network binding).
- WSDL 1.1 / WSDL 2, UDDI, SOAPAction / SOAP 1.2 HTTP action parameter bindings, HTTP Content-Type enforcement or HTTP response status mapping. SOAPAction is not authority for service dispatch.
- WS-Security, XML Signature / Encryption, WS-Addressing, WS-ReliableMessaging, WS-Policy, attachments/MTOM/XOP, SOAP encoding, array/complex types, full XSD validation and typed numbers, streaming XML, full SOAP header role/relay actor processing, or multi-language interop tests.
- Compatibility with SOAP rpc/encoded or a general arbitrary XML document model.

These are explicitly future increments; they must not be implied from the limited document/literal baseline. See `docs/ARCHITECTURE.md` and `QUALIFICATION.txt`.

Dev2 dependency change: this package requires the standalone RPC service core; no core classes are bundled. New RPC object/method registration is tested by the core package against SOAP and JSON-RPC.
