# Provenance

Design authority: user-supplied `Pasted markdown(20260910-161854).md`, General ooRexx Deployment Component.

Current implementation review inputs:
- `audio_v9_voice_recovery_v0.1-dev1(1).zip` SHA-256 `a6e1db23f0b4f9e44230738896e64bbd375708d930ba08c7e8a58c11f8580e35`.
- `oorexx_mcp_service_v0.2-dev8(1).zip` SHA-256 `56a38180ae1d2f712ba9afc3f9f2aa5bd528bc04a5c976510167faf6f98287d3`.
- `oorexxapis(20260910-161939).zip` SHA-256 `aa1709f24b4a8473fcfb99f36c11c4bb718b9ce0e30d7a4f439d5df8cbdfeafb`, including HTTPS Server v0.4.4 and Wire UI Server v0.17.

The hosted-module contract preserves the live MCP lesson: direct HTTPS package dependency is required in the module package, and a module is not deployed until a real host generation has activated it and a live endpoint probe succeeds.
