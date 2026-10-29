# Alchemy for Python v0.1-dev5 — Source-qualified integration

## Sources and authority

The hashes of the exact examined source archives are in `SOURCE_REVIEW.json`.

- **Connect Selector 0.1-dev5** owns mode/provider/destination/requirement routing. Python invokes its actual `ConnectIntent` through a *live* externally supplied native projection; no new router, socket selector or Queue Fabric implementation is created. Modes: REQUEST, NOTIFY, ENQUEUE, local CALLBACK; requirements IMMEDIATE, BEST_EFFORT, DURABLE (ENQUEUE only), CONTINUITY (REQUEST only, RTO2 provider). The eight-field ConnectResult remains preserved.
- **RPC Service Core 0.1-dev1** owns the allowlist, object-method registration, and local callback sink contract. Python does not dynamically expose arbitrary object attributes. CALLBACK needs a native-visible callbackSink, via native bridge construction. This is **local only**, never gRPC server-streaming or a network callback.
- **gRPC RPC Binding 0.1-dev3** introduces external outbound HTTP/2 unary + server-streaming and keeps protobuf codecs in Serialization Selector v0.4. Python's *optional* independent grpcio client reuses normal gRPC wire behavior, while app-supplied serialize/deserialize functions remain authoritative. This SDK does not implement a protobuf codec or protocol-to-service method reflection. Explicit method registry is required before calls.
- **Serialization Selector** remains the authority for ooRexx-side bytes/encoding; Python callables can be from generated protobuf classes. Neither transport chooses codecs by payload inference.
- **Python macrospace 0.31.9-candidate** has a Python-first interpreter initialization race fix but explicitly lacks host runtime qualification. Do not upgrade the native dependency from accepted v0.31.7 based on this candidate.

## Qualification actually executed

`python -m unittest discover -s tests -q` tests all inherited service, identity, framed TCP and job cases, plus Connect Selector dev5 exact-shape Python projection and real grpcio HTTP/2 unary/server-streaming with Python gRPC server and Google protobuf StringValue. Tests include partial streaming failure after onNext, bounded counts, local-only callbacks, RTO2 non-downgrade, observation injection, registry validation, no auto retry. No actual Python-to-ooRexx native execution is claimed, because this host has no `rexx` executable / matching binary extension.

**Integration remains open:** passing native ConnectSelector/ConnectIntent/RpcServiceCore/JsonRpcFabric values through the compiled Python macrospace; distributed RTO2 continuity (including epochs, estate guard and failure uncertainty); live Queue Fabric; gRPC against the *ooRexx* HTTP/2 implementation; production TLS/authentication. Do not claim any of these are qualified by Python-only test doubles or a grpcio server.

## Security and failure guarantees

- Connection selection is performed by the native Connect Selector route policy. The Python facade never retries on a different provider after execution begins.
- Native `callback(...)` permits only DIRECT or AUTO, with sink methods onNext/onComplete/onFault/isCancelled. The embedder controls conversion of the sink to a live Rexx object and its lifetime. Use `LocalRpcCallbackSink` only when its native proxy qualifies.
- Native `continuity_request(...)` permits only RTO2 or AUTO and preserves ConnectOutcome acceptance, completion, durability, code and detail. Runtime fencing and estate-membership permissions are not granted by this SDK.
- Native `set_observer(...)` delegates to Connect Selector dev5's observer interface; native selector catches observer failures and does not give observation routing authority. For the actual Mesh instrumentation, use the existing ConnectInstrumentation integration instead of inventing new dimensional metrics.
- `GrpcClient` needs an externally supplied channel, explicit method paths, explicit protobuf serializers. `grpc.insecure_channel` is for opt-in local testing only; use `grpc.secure_channel` with valid trust when remote. No fallback, retry, reflection or completion inference from a single streamed value. Its server-stream iterator has a bounded count and retains earlier messages when a later error occurs.

## Native integration gates

1. Build the accepted Python macrospace bridge against exact Python and ooRexx 5.3 ABI, and test interpreter/bootstrap concurrency, object retention and revocation. Do not adopt unqualified candidate 0.31.9 as a release dependency.
2. Provision the actual Connect Selector dev5, RPC Core dev1, JSON-RPC Fabric dev3 and optionally Queue Fabric dev6 in the ooRexx host. Bind exact method registrations and route policies.
3. Exercise `NativeConnectSelectorPort.callback`, `.continuity_request`, and `.set_observer` end-to-end using *real* native objects. Include negative tests for forbidden routes, callback sink shape, stale runtime identity and in-flight estate changes.
4. Exercise JSON-RPC hex8 TCP with a real ooRexx server, then gRPC unary/streaming against the *real* ooRexx binding. Test independent certificate validation, cancellations and partial-effects reporting.
5. Verify immutable source hashes, frozen allowlists, bound payloads, secure channels and governance before publication.
