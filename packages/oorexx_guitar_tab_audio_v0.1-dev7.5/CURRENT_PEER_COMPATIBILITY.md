# Current peer compatibility — 2026-10-29

This increment turns the historical dev7.4 integration into an explicit current-peer gate.

Observed GitHub authorities:
- Physics World: `0.1-dev50.2`.
- Maths: `0.19`.
- Rexx-tronics: published source remains dev5/dev15; dev29 is development handoff evidence only.

The Physics API still publishes the band’s required physical surfaces:
`GuitarStringPhysicalModel`, `GuitarMathsModalRenderer`, `GuitarInstrumentFactory`,
`GuitarAcousticFeedbackDriver`, `DrumKitFactory` and `DrumKitPhysics`.

Maths 0.19 retains the generic context, oscillator-bank, second-order continuation and
discrete-state foundations consumed through Physics.

The electrical seam is deliberately not guessed. GitHub main does not currently expose
`RexxTronicsGuitar.cls`, `GuitarMagneticPickup`, `GuitarPickupSelector` or
`GuitarLoadedNetwork` as accepted Rexx-tronics source. Full electrical rendering is
therefore gated until that owner publishes and qualifies its source.

`tests/test_current_peer_contracts.rex` is the native Physics/Maths smoke.
`tests/check_rexxtronics_peer.sh` is the explicit electrical publication gate.
