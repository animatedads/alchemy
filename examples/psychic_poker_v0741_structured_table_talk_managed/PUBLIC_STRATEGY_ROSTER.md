# HardWorld Casino — publishable deterministic strategy roster

The live API agents (`GROK`, `GEMINI`) receive only the blind public game view.
They are not given these internal strategy identities.

Deterministic ordinary players:

- Ada / Grace — `STANDARD`
- Hugo — `AGGRESSIVE`
- Noah — `AI_GEMINI_EMULATED`
- Rosa — `RESOURCE_AWARE`
- Apex — `APEX`
- Paladin — `PALADIN`

Privileged internal players:

- Eve / Frank — `PSYCHIC_TEAM`
- Maya — `PSYCHIC_AGGRESSIVE`

The deterministic strategy source may be published/shared without changing the
AI prompt contract. During play, GROK and GEMINI see ordinary player names and
public table state, not strategy class names or role metadata.

- Benny — `BLIND_PSYCHIC` (independent psychic; cannot see own cards; no team)

- The_Oracle — `THE_ORACLE` (ordinary player; empirical policy weighted from prior profitable ordinary-player actions stored in NoSQLServer)
