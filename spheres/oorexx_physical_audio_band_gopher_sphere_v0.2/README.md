# ooRexx Physical Audio Band Gopher Sphere v0.2

Authoritative continuity for the physical guitar/bass/drum band integration.

Current consumer target on 2026-10-29:
- Physics World 0.1-dev50.2;
- Maths 0.19;
- Units 0.1-dev4;
- Rexx-tronics electrical source: **not yet admitted at the dev29 handoff line**.

The central rule remains: the score is not the synthesizer. MIDI/tab provide performance intent, Physics owns mechanical/acoustic truth, Maths owns generic numerical operations, Rexx-tronics owns electrical state, and Audio owns downstream signal representation.

v0.2 adds an explicit current-peer admission rule: physical/numerical qualification may proceed independently, but full electrical rendering must fail closed unless the Rexx-tronics owner publishes the required guitar source and it passes the package’s electrical peer smoke.

See `articles/current_peer_gate.md` and `articles/start_here.md`.
