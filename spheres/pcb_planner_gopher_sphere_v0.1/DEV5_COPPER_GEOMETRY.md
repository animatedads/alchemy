# PCB Planner dev5 geometry candidate — 2026-10-29

Architecture: Tom Dyer. Candidate coding and note: ChatGPT.

Source candidate: `oorexx_pcb_planner_v0.1-dev5-candidate.zip`, SHA-256 `36d6d0d06303bbb76cea06b902ee4825d259b287d74f6a890c93a82bab075790`.

Dev4 source was inspected locally. Dev5 adds a `PCBCopperGeometry` helper for finite-segment distances and a same-layer, different-electrical-net clearance check in `PCBBoardVerifier`. Required separation is the externally sourced `PCBManufacturingRules.minClearanceMm` plus half of each trace width. Missing route geometry is reported. The existing endpoint graph is not geometric connectivity proof.

**Not qualified or promoted:** The current execution container has no ooRexx interpreter, and the candidate has not been run. The archive is not yet checked into the repository. Its old manifest and qualification files are inherited from dev4 and MUST NOT be treated as dev5 evidence. Test geometry (crossing, parallel, endpoint touch, zero-length, diagonal, same-net, different layer, absent manufacturing authority), run complete r13196 regression and regenerate manifest before release. Keep pads/vias/keepouts and board-edge checks open.

Programme priority: PCB Planner is not on the website/mail/LDAP/HTTPS/MU–MI critical path; do not divert those component owners. Autobuilder is not running; do not imply automated build acceptance.
