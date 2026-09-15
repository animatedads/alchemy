# Project component catalogue

`components.json` is the sealed composite catalogue used by MCP Project Service v0.2-dev8. It contains:

- 82 runtime/API artifact entries from `oorexxapis(20260908-080803).zip` (SHA-256 `aa1709f24b4a8473fcfb99f36c11c4bb718b9ce0e30d7a4f439d5df8cbdfeafb`).
- 53 Gopher sphere artifact entries from `sphere(20260908-080803).zip` (SHA-256 `293cd2a62e04965e7c87134902d0509bb453cbe36618f895444a0af7465fc177`).
- 129 unique canonical component IDs across the two sources.

`runtime_components.json` and `sphere_components.json` retain the two source projections separately. `tools/build_sphere_catalog.py` regenerates the sphere projection from a sphere roll-up, and `tools/build_combined_catalog.py` composes the two projections. Those Python utilities are packaging/qualification aids only; the running ooRexx service has no Python dependency.

Runtime component IDs retain their existing names. Sphere components use `sphere:<gopher-sphere-id>`, for example `sphere:oorexx-llm-pitfalls`. This prevents ownership collisions where a runtime component and a sphere share a logical name. Convenience aliases are accepted where unambiguous, but exact component IDs always take precedence and journal events always record the canonical ID.

Ownership, requests, replies, read receipts and component mailboxes operate uniformly on either component kind.
