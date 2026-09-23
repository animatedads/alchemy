# Wire3D 0.1-dev6

Dev6 establishes live-projection plumbing without making Wire3D authoritative for domain state.

* `Wire3DQuaternion` corrects the wire transform rotation to x/y/z/w.
* `Wire3DSceneDelta` and `Wire3DDeltaOperation` define revision-fenced projection changes (`WIRE-3D-DELTA/0.1`). A consumer must reject a delta whose `baseRevision` does not equal its current scene revision and request a fresh snapshot; this prevents silent divergence.
* Delta operations carry projection facts only. They do not constitute domain commands.
* `Wire3DClientView` makes camera state explicitly client-local. A phone and auditorium display may share semantic selection while navigating independently.
* The browser renderer can apply revision-fenced deltas and exposes SHOW EVIDENCE as a passive viewer when an evidence envelope is present in node metadata.

The next transport adapter may deliver snapshots/deltas over the existing Wire UI/HTTPS/WebSocket edge. The core deliberately does not define a second network authority.
