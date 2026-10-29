# ooRexx Guitar Tab / MIDI Audio v0.1-dev7.5

dev7.5 is a current-peer compatibility increment over the published dev7.4 physical guitar/bass/drum frontend.

The score is still not the synthesizer: ASCII tab and MIDI are performance/control inputs; Physics owns mechanical state and acoustic radiation; Maths owns generic numerical acceleration; Rexx-tronics owns the electrical pickup/network seam.

## What changed

- Pins the qualification target to Physics World 0.1-dev50.2 and Maths 0.19.
- Adds a native current Physics/Maths contract smoke covering guitar modal rendering, instrument feedback and the stateful drum kit.
- Adds an explicit Rexx-tronics publication gate. Full electrical rendering is refused when the accepted peer does not provide `src/RexxTronicsGuitar.cls` with the required guitar classes.
- Removes the old runner assumption that a historical Rexx-tronics root is always available.
- Preserves dev7.4 MIDI, voicing, concurrency and standards fixes unchanged.

## Current evidence boundary

The current GitHub Physics and Maths trees expose the physical/numerical APIs consumed by this package. Rexx-tronics dev29 is still candidate/handoff evidence and is not silently treated as accepted source. Therefore this branch does **not** claim a complete current-head band runtime PASS until the electrical owner publishes and qualifies that seam.

Historical dev7.4 runtime records remain in the copied `VALIDATION*.txt` files and remain dependency-scoped.
