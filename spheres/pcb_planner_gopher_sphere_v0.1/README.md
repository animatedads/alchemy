# PCB Planner sphere v0.1

## Authority and scope
PCB Planner is an independent ooRexx package, not a Rexx-tronics module. Rexx-tronics owns electrical circuits, pins and nets. Common Parts owns package and pin identity; Materials owns material properties; Physics World owns physical simulation; Physical Manufacturing owns process capability. PCB Planner owns board geometry, placement, copper candidates, routing, DRC, and qualification evidence.

## Current implementation evidence
The last delivered standalone baseline is `oorexx_pcb_planner_v0.1-dev4.zip` (SHA-256 `7d178d461aff2b0921b311b433b2807859aa593f07dd1f19d657f95a5c96b09b`). It includes identity/orientation verification, a board graph, a deterministic routing candidate, manufacturing projection, and Intention Service discovery surfaces. The prior qualification was on ooRexx 5.3.0 r13196; it is not evidence of qualification against newer Library heads.

## Intentions contract
Discover capabilities afresh from the retained live board, circuit, parts, manufacturing, and physical evidence. Intention Service controls meaning, evidence sufficiency, ambiguity, and READY/COMMIT. An intention is not a permanent command catalogue. Withdrawn authority must remove stale surfaces. Preserve actual ooRexx objects across boundaries; no flattened model state. Discovery does not itself mutate the board.

## Work to implement
1. Reinspect current Intention Service contract and requalify the adapter before claiming compatibility.
2. Add specialist discovery surfaces for placement, routing, clearance, thermal, manufacturing, and test access, each with explicit evidence provenance and revocation.
3. Add geometry-aware copper clearance/keepouts and collision-aware routing; fail closed on missing fabrication capability.
4. Preserve deterministic candidates, board/circuit/parts/manufacturing revisions, and independent verification evidence.
5. Run real ooRexx r13196 regression and package a separate PCB Planner release. Do not modify Rexx-tronics authority to host PCB classes.

## Repository admission
This sphere records architecture and backlog only. It does not claim that the dev4 binary/source archive was committed or that new runtime tests passed in this commit.
