# RPC Invocation — LLM Gopher engineering sphere v0.1

This sphere documents the **RPC invocation authority** shared by the Alchemy ooRexx RPC Service Core, JSON-RPC Fabric, SOAP RPC Binding and gRPC RPC Binding. It is documentation/continuity, **not a replacement implementation** and not a claim of full gRPC support.

The source baseline is the RPC portfolio v0.1-dev1 submitted to GitHub Autobuild on 23 October 2026. Its Git submission branch carries 84 package files and a final ready marker, but **receiver acceptance has not been established**. Package-specific version labels are retained. The `SOURCE_ARCHIVES.json` ledger pins locally examined ZIP bytes and representative class members; it does not confer runtime acceptance.

## Four independent authorities

1. **Connect Selector** selects and authorizes direct, remote RPC or Queue Fabric invocation. Routing never originates in a protocol envelope or serializer.
2. **Serialisation Selector** selects schema-bound codecs, including protobuf where the installed provider supports it. No shadow protobuf implementation inside gRPC.
3. **RPC Service Core** owns service registration and invocation: an exact published service/operation maps to an explicit local object/method or callback method.
4. **Protocol bindings** own their individual envelopes, framing and fault/status translations: JSON-RPC 2.0, SOAP 1.1/1.2, gRPC HTTP/2.

Local direct calls and Queue Fabric remain genuine alternatives, not disguised JSON-RPC transports. Different durability/ordering/notification semantics must remain visible.

## Start / navigation

- `gopher --profile rpc-invocation context rpc-invocation --full`
- `gopher --profile rpc-invocation search registerMethod --sphere rpc-invocation`
- `gopher --profile rpc-invocation search streaming --sphere rpc-invocation`

Documentation nodes: `rpc.start`, `rpc.registry`, `rpc.boundaries`, `rpc.callbacks`, `rpc.grpc`, `rpc.json`, `rpc.soap`, `rpc.security`, `rpc.qualification`, `rpc.continuation`.

## What has and has not been qualified

- **Package historical qualification:** RPC Core, SOAP and JSON-RPC had ooRexx r13196 test evidence in their source deliveries. gRPC dev3 has native HTTP/2 streaming fixture evidence. See `qualification/QUALIFICATION.md` for the exact breakdown.
- **This sphere:** JSON integrity, structural relationships, source archive member hashes and negative architecture assertions are checked locally. This is **not** a full Gopher validate/lint execution unless separately recorded.
- **Not yet qualified:** inbound gRPC HTTP/2 service hosting, client/bidirectional streaming, target-runtime gRPC observer callback bridge, production TLS/identity, end-to-end backpressure, live SOAP authentication/WSDL/WS-Security.

## Source and publication

This sphere is a standalone package for Alchemy Autobuild, with a root `integration.json` and versioned publication target `spheres/oorexx_rpc_gopher_sphere_v0.1`. `tests/verify_sphere.py` is its self-contained structural/contract check. Gopher semantic acceptance remains an external gate. Do not claim acceptance of the earlier RPC source submission until the Autobuild receipt exists.
