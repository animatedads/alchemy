# Object Queue Fabric engineering sphere v0.2
Source-qualified continuity and optional XTP integration design; not an executable Queue Fabric adapter.
Historical v0.1 articles retain their v0.9-dev5 provenance.
Current Library source heads: Queue Fabric v0.9-dev6, XTP v0.1-dev25, Operational Planner v0.1-dev5, Service Descriptors v0.1-dev2.
No distributed XA, Queue Fabric-over-XTP runtime pass, multicast durable commit or ED209 field acceptance is claimed.

Run: gopher --profile queue-fabric context queue-fabric --full
Search: gopher --profile queue-fabric search xtp --sphere queue-fabric
Static check: bash tests/check_xtp_contract.sh

See docs/XTP_IMPLEMENTATION_HANDOFF.md and contracts/queue-fabric-xtp-integration-v0.1.json.
XTP's independently maintained sphere owns transport, route and secure-provisioning semantics. Queue Fabric owns application durability.
