# Architecture

The package is an adapter/planning domain between electrical intent and physical board realization.

`Rexx-tronics Pin/ElectricalNet -> PCBPinPadBinding -> PCBPlacement -> PCBNetEndpoint -> PCBTrack/PCBVia -> PCBBoardVerifier`

The electrical object references remain authoritative.  A board candidate fails closed when pin/pad identity, placement bounds, track net identity, or physical connectivity disagrees with that authority.

## Intention control plane (dev3)

Planning is discovery-first, not stage-first. Each refresh observes the current board/circuit state and derives the operations that are presently meaningful and feasible. Intention Service owns recognition, evidence records, READY/CLARIFY and dispatch state; PCB Planner owns discovery predicates and PCB operation implementations. External authorities remain external.

No LLM or UI is allowed to manufacture PCB capability facts. A future LLM provider may propose meaning, but feasibility remains evidence-bound to discovered objects and peer-authority projections.
