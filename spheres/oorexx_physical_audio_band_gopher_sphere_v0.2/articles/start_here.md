# Start here

## Current architecture

```text
ASCII tab / Standard MIDI File
        ↓ performance intent
Guitar / Bass / Drum renderer objects
        ↓ physical excitation
Physics World 0.1-dev50.2
        ↕ generic numerical operations
Maths 0.19
        ↓ electrical observations
Rexx-tronics accepted guitar peer (GATED)
        ↓
Audio / WAV / spectral observation
```

The dev7.5 package is `packages/oorexx_guitar_tab_audio_v0.1-dev7.5`.

Run `run_tests.sh` with current Physics, Maths and Units roots for the physical/numerical smoke. Set `GUITAR_RUN_ELECTRICAL=1` only when the accepted Rexx-tronics source root exists. The runner then verifies the guitar electrical classes and executes the peer smoke; otherwise it fails closed.

Do not claim current-head full-band qualification from the historical dev7.4 WAVs or validation files.
