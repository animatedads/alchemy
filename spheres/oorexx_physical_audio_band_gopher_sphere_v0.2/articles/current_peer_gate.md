# Current peer gate

The dev7.5 consumer gate separates three independent questions.

1. **Physics API present?** The current Physics tree must expose the guitar string/model, Maths modal renderer, instrument mechanics, acoustic feedback and drum-kit classes used by the band.
2. **Maths API present?** The current Maths tree must retain the context/oscillator/dynamics contracts consumed through Physics.
3. **Electrical authority admitted?** Full rendering is only admitted when the Rexx-tronics owner publishes `src/RexxTronicsGuitar.cls` containing `GuitarMagneticPickup`, `GuitarPickupSelector` and `GuitarLoadedNetwork`.

Failure of (3) does not make MIDI parsing or Physics-only mechanics invalid, but it blocks any claim that the complete current-head electric-guitar signal chain is runnable.

Never substitute the dev29 handoff note, a historical ZIP, or a copied class for owner-published authority.
