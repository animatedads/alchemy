# Alchemy for Python — v0.1-dev6

**27 October 2026 — additive integration, Python-side qualified.** The service SDK and the **independent** bidirectional ooRexx Macrospace bridge remain separate. Service selection belongs to ConnectSelector; protocol dispatch/registry belongs to RPC Service Core; encoding belongs to Serialization Selector. The separate JosepMariaBlasco/oorexxpython upstream code and its Alchemy adapter are **not** drop-in replacements for our independent Macrospace bridge.

## Delivered

- `RexxSelectorProjection` maps `ConnectSelector~execute`, `~explain` and `~setObserver` directly to a **retained** native `RexxObject.send()` message. It does not serialize an ooRexx object or create a second handle table.
- `rexx_result_field` dispatches the eight published ConnectResult getters through the retained object; `rexx_logical` explicitly decodes known `0`/`1` scalar representations, never Python truthiness. Hosts with different native logical representations must supply their own decoder.
- `NativeConnectSelectorPort` now accepts an explicit `default_destination` for RPC REQUEST and NOTIFY; the selector's own route policy remains authoritative, including strict destination matching. `enqueue` remains a distinct explicit operation, not a silent translation of a service job request.
- `decode_bool` remains injection-based; no guessed native bridge ABI and no default conversion of arbitrary Python truthy values.

## Qualification

`PYTHONPATH=src python -m unittest discover -s tests -q` — **87 passed** on Python 3.13. 79 inherited tests plus eight new Python projection contract tests. Executed optional local grpcio/protobuf HTTP/2 tests where installed. The existing subprocess round-trip test was given a longer 8-second *test* deadline for loaded build hosts; the independent timeout negative test remains.

**Not qualified:** live ooRexx r13196 native Macrospace integration; ConnectSelector dev7 end-to-end against an installed interpreter; actual Queue Fabric, JMS broker, or RTO2 failover; remote gRPC against ooRexx. Library snapshot `oorexx_connect_selector_v0.1-dev7.zip` is exact-source evidence for API review, not an executing runtime in this environment.

See [dev6 design and gaps](docs/DEV6_INTEGRATION.md) and prior documentation.

---

# Alchemy for Python — v0.1-dev5

**Source review: 15 October 2026.** This is an additive Python SDK delivery against the new Connect Selector v0.1-dev5 and gRPC RPC Binding v0.1-dev3 contracts. Existing JSON-RPC Fabric hex8 TCP, independent virtual ooRexx classes, explicit job contracts and protocol-neutral services are preserved.

### Delivered

- Native selector projection: new `callback(...)` restricted to **local DIRECT** RPC Core callbacks; `continuity_request(...)` restricted to **RTO2**; `set_observer(...)` for optional Connect Selector observation. No new provider/route selector and no unqualified promise of RTO2 runtime continuity.
- Optional `GrpcClient` with explicit published `GrpcMethod` registry, protobuf encode/decode functions supplied by the application, grpcio unary + server-streaming, bounded incremental reads, cancellation and structured uncertain-outcome error handling. This is **not** ConnectSelector CALLBACK: remote gRPC HTTP/2 streaming is a distinct protocol path.
- Source revisions with SHA-256, real grpcio loopback interoperability tests, native contract tests and exact remaining runtime qualification gates.

### Install

```sh
python -m pip install .
# Optional: python -m pip install '.[grpc]'
python -m unittest discover -s tests -v
```

The core package remains Python 3.10+ with no mandatory third-party runtime dependencies. The gRPC extension requires `grpcio` and `protobuf`, and accepts a caller-configured channel (TLS required by deployment for nonlocal use). The source/manifest and full qualification detail are under `docs/DEV5_INTEGRATION.md`.

**Qualification scope:** Python tests and real grpcio loopback HTTP/2 only. No actual ooRexx interpreter was present on this build host, so a Python/native ooRexx end-to-end result is **not** claimed. Python macrospace 0.31.9 is still only a candidate, not automatically adopted.

---

## Previous architecture and examples

# Alchemy for Python — v0.1-dev4

**Source-reviewed integration increment (9 October 2026).** Added a real Python implementation of the private JSON-RPC Fabric TCP **hex8 length-framed** transport (`FramedSocketTransport`), and a bounded local callback sink matching the new protocol-neutral RPC Service Core API. Reviewed Connect Selector `0.1-dev2` (strict optional route policy, per-destination registrations), JSON-RPC Fabric `0.1-dev3`, RPC Service Core `0.1-dev1` and Serialization Selector `0.5-sint32`.

**Qualification boundary:** Python-to-Python TCP framing and unit tests have passed; this is **not yet a native Python-to-ooRexx network test**, a Queue Fabric gateway, an RPC server, or a gRPC implementation. Real ooRexx runtime was unavailable in the build environment. Loopback-only raw TCP is enforced by default because JSON-RPC Fabric's demo server is not authenticated. For details, see [dev4 interoperation](docs/DEV4_INTEROP.md).

```python
from alchemy_python import FramedSocketTransport, JsonRpcClient
# Requires a running *length-framed* JSON-RPC Fabric TCP server on loopback.
client = JsonRpcClient(FramedSocketTransport("127.0.0.1", 19192))
# client.request("catalog.lookup", ["item-7"])
```

For published service calls, use `ServiceContract` and `AlchemySession` as below. For native `ConnectSelector~execute`, retain the injected `NativeConnectSelectorPort`: Python never manufactures its own routing policy. For local, live object access continue to use the existing Python macrospace bridge, not RPC serialization.

## Development tests

```sh
python -m pip install -e .
python -m unittest discover -s tests -v
```

---

> **ConnectSelector status (dev3):** The actual `oorexx.connect_selector/0.1`
> source package has been located. `NativeConnectSelectorPort` maps the published
> `ConnectIntent` / `ConnectResult` contract through injected live native objects.
> See [Native Connect Selector](docs/NATIVE_CONNECT_SELECTOR.md). No end-to-end
> native interpreter/queue test is claimed by this Python release.

# Prior client architecture and samples (dev3)

**Status: development SDK, with protocol unit/stdio harness qualification, NOT a delivered Queue Fabric gateway.**

A small, dependency-free Python 3.10+ package that gives the Python community a natural client for published Alchemy services while keeping a **separate optional** native ooRexx-object surface.

This client retains the JSON-RPC 2.0 message contract and now implements the JSON-RPC Fabric dev3 private TCP framing profile. That ooRexx project has an actual JSON-RPC dispatcher and local/stdin/stdout example, but does **not** yet have a production HTTP JSON-RPC server nor a Queue Fabric adapter. This Python package must not silently pretend those exist. The existing separate `oorexx_python_macrospace_poc_v0.31.7` is the authoritative live-object bridge; it is *not* forked or reimplemented here.

## Install and test

```sh
cd alchemy_python_v0.1-dev4
python -m pip install -e .
python -m unittest discover -s tests -v
```

The package has no external Python runtime dependencies. `HttpTransport` is a **client only** for a separately configured and qualified HTTPS gateway. `SubprocessTransport` starts a new child per exchange, with a timeout; its intended use is the actual JSON-RPC Fabric `examples/stdio_server.rex` once ooRexx and `json.cls` are present. `CallableTransport` lets users inject their own host/wire connector.

## A native-feeling Python service

```python
from alchemy_python import (
    HttpTransport, JsonRpcClient, AlchemySession,
    ServiceContract, Operation, VirtualServiceClassFactory,
)

# HTTPS endpoint supplied by deployment. The ooRexx JSON-RPC v0.1-dev1
# distribution alone does NOT create this gateway.
transport = HttpTransport("https://your-authorised-gateway.example/rpc", token="from-secret-provider")
client = JsonRpcClient(transport)
contract = ServiceContract("catalog", "1.0", (
    Operation("lookup", "catalog.lookup"),
))
Catalog = VirtualServiceClassFactory.make("Catalog", contract)
catalog = Catalog(client, contract)
entry = catalog.lookup({"key": "SKU-123"})
```

Published operation contracts are explicit allowlists; the SDK does not discover arbitrary methods or infer permissions from host names. The service implementation can use Queue Fabric or direct execution, selected **server-side by semantics and governance**. JSON-RPC notifications do not confirm processing. Any queue submission must be a request that returns a meaningful server-assigned job receipt and has a separate status API.

## The distinct live-object surface

```python
from alchemy_python import Macrospace
import _rexxpython_poc as native  # separately built and qualified v0.31.7

# Native bridge bootstrap, package-path registry resolution, construction and
# retention are performed by the existing Python/ooRexx macrospace project.
# `retained` must be an existing native RexxProjectedObject, not a JSON dict.
macro = Macrospace(native)
Animal = macro.virtual_class("Animal", {"describe": "describe"})
animal = macro.adopt(Animal, retained)
print(animal.describe())
```

A `VirtualRexxClassFactory` produces a Python-facing class facade, **not** an independent Rexx class. Its declared methods resolve on the live native target each time. The bridge retains authority over actual Rexx class identity, MRO, lifetime, exception translation, concurrency and re-entry; no JSON-RPC serialization or duplicate handle registry is introduced. `send_exact()` uses the native projection's explicit send escape when available; supported argument combinations are governed by the native extension.

## Transport and service caveats

- `SubprocessTransport`: one subprocess per message, newline framing, no shell invocation, bounded JSON frames; intended for development and constrained local service use. Not a production daemon or a hardened multiparty server.
- `HttpTransport`: `POST` and JSON payload; TLS (HTTPS) enforced except opt-in unauthenticated loopback; no automatic retries, discovery or credential persistence. A tested network gateway is needed separately.
- `JsonRpcClient`: unique opaque string IDs, strict response matching, refusal of duplicate keys, oversized documents, unsafe JSON integers and nonfinite floats. On transport failure a mutation may *already have happened*. Application keys and server deduplication must handle that.
- Live object bridge: no native extension bundled; no claim of tested native invocation on this host. Real ooRexx integration requires qualification using the exact runtime and bridge binary.

See `docs/ARCHITECTURE.md`, `docs/CONNECT_SELECTOR_INTEGRATION.md` and `docs/GATEWAY_CONTRACT.md` for the intended server-side placement and acceptance gates.

## Durable job clients (explicit server contract required)

```python
from alchemy_python import AlchemySession, JobServiceClient, JsonRpcClient, Operation, ServiceContract

job_contract = ServiceContract("jobs", "1.0", tuple(
    Operation(name, f"jobs.{name}", semantics="job" if name == "submit" else "immediate")
    for name in ("submit", "status", "result", "cancel")
))
# Configure `client = JsonRpcClient(transport)` against an actual authorised
# published gateway; the sample API below is a PROPOSED contract, not deployed.
jobs = JobServiceClient(AlchemySession(client).service(job_contract))
receipt = jobs.submit({"task": "reindex", "target": "catalog"}, idempotency_key="operator-request-001")
print(receipt.job_id, receipt.state)   # Service-confirmed acceptance ONLY.
print(jobs.status(receipt.job_id))    # Separately query authoritative job status.
```

`JobServiceClient` is a contract consumer, **not** a Queue Fabric binding. Its versioned example schema is specified in `docs/GATEWAY_CONTRACT.md`; actual Queue Fabric/authorization persistence and idempotency enforcement must be delivered by the separately qualified gateway. It will refuse unaccepted or malformed job receipts.


## Connect Selector integration (v0.1-dev3)

Alchemy's **Connect Selector**, under development, is intended to select local
direct invocation, JSON-RPC Fabric or Queue Fabric for published services.
`SelectorClient` is a deliberately narrow Python adapter to that future
selector authority; the Python package **does not implement another policy
engine or invent the unpublished native selector API**. The existing
`JsonRpcClient` remains available for standalone JSON-RPC service calls.

```python
from alchemy_python import AlchemySession, SelectorClient, ServiceContract, Operation

contract = ServiceContract("catalog", "1.0", (Operation("lookup", "catalog.lookup"),))

# selector_adapter is supplied by the deployment and bound to the *accepted*
# Connect Selector native API; not bundled or implemented in this package.
# service = AlchemySession(SelectorClient(selector_adapter)).service(contract)
# result = service.lookup({"key": "SKU-123"})
```

The adapter receives pinned service/version, operation name, immediate/job
intent and request/notification kind. It does not assume that an RPC success
proves durable queue admission, or that a live Rexx object is serializable.
See `examples/connect_selector_adapter_demo.py` for a **mock-only** illustration,
and `docs/CONNECT_SELECTOR_INTEGRATION.md` for required native integration gates.

JSON-RPC Fabric `0.1-dev3` retains the private length-prefixed socket profile, now implemented by Python `FramedSocketTransport`. Do not point `HttpTransport` at its TCP socket. Real Python-to-ooRexx interop for this profile remains unqualified.
