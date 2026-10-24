# Start here

## Architecture

```text
ASCII tab / Standard MIDI File
        ↓ performance intent
Guitar / Bass / Drum renderer objects
        ↓ physical excitation
Physics World mechanical state + coupling + acoustic radiation
        ↕ generic numerical operations
Maths
        ↓ electrical observations
Rexx-tronics pickup / amplifier / speaker electronics
        ↓
Audio / WAV / spectral observation
```

Guitar, bass and drum calculation are peer render objects. The coordinator may run independent instruments concurrently using ordinary ooRexx activities (`Object~start`, `Message~result`), then synchronize at the common time/room/mix boundary. Scheduling policy may cap concurrent heavy providers when oversubscription hurts wall time; that does not change object ownership.

## Proven physical lessons

- Guitar strings exchange energy through shared structure; sympathetic resonance is physical state, not a post-effect.
- A drum kit is a connected mechanical structure. A strike must primarily excite the contacted head/plate; shell, resonant head, wires, stands and neighboring voices move through coupling.
- Snare modelling needs batter head → cavity → resonant head → wire-bed coupling. Directly injecting the stick impulse into shell/wire modes produces the wrong “wood block” character.
- Acoustic output must be observed from continuing live state. Sparse observation, stale acceleration caches, or non-truncating WAV publication can make healthy mechanics appear silent.

## ooRexx correctness lessons

- `+0` is forbidden. `+` is a message, not numeric coercion. Validate numeric input instead of manufacturing it through operator dispatch.
- `&`, `|` and `&&` are used only when evaluation of every operand is semantically safe. Prefer nested guards where evaluation depends on prior validation.
- `Array~remove()` is sparse removal; do not assume compaction.
- Avoid ordinary locals named `RESULT`.
- Keep `expose` first and respect inherited object-variable scope through accessors/messages.

## Current open work

1. Requalify the standalone band/MIDI frontend against Physics dev50 + Maths v0.16 + Rexx-tronics dev25.
2. Continue snare/drum contact modelling from the head/cavity/resonant-head/wire-bed physical topology, not from EQ or sampled IR substitution.
3. Move remaining repeated drum/string linear mechanics through generic Maths block APIs only where scalar/native equivalence is proved.
4. Keep instrument renderers independent/concurrent, with the shared room/acoustic boundary explicit.
5. Apply the standards checker as triage plus runtime evidence; never treat regex findings as executable proof.
