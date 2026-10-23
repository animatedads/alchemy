# dev11 qualification

Scope: dynamic Speech intention discovery and repository/sphere synchronization.

## Design assertions

- discovery is recomputed from the live `SpeechRuntime` on every call;
- candidates retain the exact live channel objects rather than copied IDs/DTOs;
- busy channels are not advertised as available;
- the duplex-session intention exists only while at least one independent TTS lane and one independent STT lane are available;
- Speech does not absorb Layered Audio or Intention Service authority.

## Execution status

The exact ooRexx 5.3.0 r13196 executable used for prior dev5-dev10 qualification was not present in this execution container on 2026-10-23. `tests/test_speech_intentions.rex` was therefore added but is **NOT_RUN** here. Prior dev10 qualification evidence remains unchanged and is not re-labelled as dev11 execution.

Static standards enforcement is run against the sealed dev11 archive separately and recorded before release.
