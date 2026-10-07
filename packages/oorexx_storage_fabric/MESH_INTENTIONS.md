# Storage Fabric mesh, socket and intention integration — v0.1-dev19

Storage Fabric remains the authority for **StorageRef, catalogue, namespace, replica safety, transfer verification and media semantics**. dev18 does not move RexxOS failover authority or native socket mechanics into Storage.

## RexxOS / RTO2 mesh boundary

`StorageMeshAuthority` is an authority *projection*, not an election service. It records the logical service, node identity, role, epoch and committed replay sequence supplied by RexxOS/RTO2.

Roles are `ACTIVE`, `SPARE`, `REPLAY`, and `FORENSIC`.

Only `ACTIVE` may mutate or commit Storage authoritative state. A caller may supply the epoch it observed; a changed epoch returns `EPOCH_MISMATCH`. `SPARE`/`REPLAY` may serve verified peer reads and maintain replay/cache state but do not advertise mutation intentions. `FORENSIC` is frozen. Promotion is accepted only as an explicit external epoch transition; Storage does not infer failure and does not self-promote.

This preserves the RTO2 invariant: transport loss is not authority transfer.

## Estate socket boundary

`StoragePeerSocketPort` consumes the established estate seam:

```
logical Storage peer service
        |
        v
SocketAddressProvider
        |
        v
SocketProvider / SocketSelector
        |
        v
SocketStreamAdapter / listener endpoint
        |
        +-- Unix
        +-- TCP / RxSock
        +-- TLS
        +-- XTP
        +-- later provider families
```

Storage stores **logical service identity**, not host/port/path/carrier credentials. Address resolution and native acquisition remain in the socket estate. This means XTP best-connect, TLS material authority, Unix isolation and future multicast-capable transports can evolve without changing StorageRef or replica semantics.

The existing `StoragePeerByteSource` remains the stable semantic byte-movement seam. QueueRexx remains a valid concrete peer control carrier; it is no longer the architectural default or the place where Storage peer identity is defined.

## Comprehensive intention surface

`StorageIntentionPort` and `StorageDynamicIntentionProvider` expose `storage.fabric.intentions/0.1` for dynamic per-turn discovery. They own no NLP, conversational state or static action catalogue. The current Storage/RexxOS/provider capability projection determines what is discoverable *now*.

Read intentions cover:

- fabric status/authority/generation;
- catalogue search, object metadata and locations;
- capacity domains, pools and reservations;
- provider inventory/lifecycle;
- namespace list and resolve;
- mesh peers and resolved logical routes;
- replica safety/durability evidence;
- transfer/checkpoint state.

ACTIVE-only mutation intentions cover:

- namespace bind/unbind and aliases;
- provider attach/detach;
- peer materialisation, replica admission and safe eviction;
- snapshot and generation promotion;
- transfer/start/resume;
- card/paper/tape and virtual-media import/export;
- migratable-job checkpoint movement;
- peer export publish/withdraw.

Every non-read invocation is rechecked against current mesh authority and optional observed epoch before it reaches the resident Storage management surface. Hiding an intention during discovery is therefore a usability property, not the security boundary.

## Native-object rule

The intention port passes native ooRexx objects/directories through to the resident management surface. It does not flatten StorageRef, StorageObject, placement evidence, mesh authority, provider or media objects into a Python/JSON action intermediary. Serialisation belongs only at explicit transport/API edges.

## Qualification

`tests/test_mesh_authority.rex` proves SPARE/ACTIVE/FORENSIC and epoch fencing.

`tests/test_mesh_socket_port.rex` proves Storage resolves and acquires communication only through the estate SocketAddressProvider/SocketProvider boundary.

`tests/test_storage_intentions.rex` proves comprehensive discovery, ACTIVE mutation exposure, SPARE mutation disappearance, epoch recheck and dispatch to the resident management surface.

`tests/environment_test.sh` is the complete environment qualification entrypoint for ooRexx 5.3.0 r13196 plus the current Socket Provider source tree.
