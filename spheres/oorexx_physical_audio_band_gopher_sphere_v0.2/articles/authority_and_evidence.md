# Authority and evidence

## Ownership

- **Physics World**: masses, stiffness, damping, coupled mechanical topology, body/string/drum state, energy, acoustic medium/path geometry and radiated pressure.
- **Maths**: generic vectors/matrices, oscillators, second-order/state-space integration, continuation/delay and provider acceleration. Maths does not know what a guitar or snare is.
- **Rexx-tronics**: pickup winding/electrical load, amplifier/circuit and transducer electrical semantics.
- **Guitar Tab / MIDI Audio**: parsing, timing, program/channel selection, guitar/bass voicing, GM drum mapping, renderer coordination and WAV publication.
- **Audio**: downstream PCM/spectral/audio-domain representation and observation.

## Evidence discipline

Historical WAVs are demonstrations, not source authority. Current source and tests live in Git. Large copyrighted MIDI files are qualification inputs only and are not redistributed.

The September band candidate proved:
- SMF type 0/1 parsing and deterministic guitar/bass voicing;
- channel-10 drum dispatch into a stateful Physics kit;
- peer-object concurrent rendering;
- real overlap of guitar/bass/drum activities;
- separation of monitor gain from physical pressure.

Those results are not automatically current-head qualification. Re-run them whenever Physics/Maths/Rexx-tronics authority changes materially.
