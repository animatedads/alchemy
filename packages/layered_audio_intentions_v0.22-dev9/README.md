# Layered Audio intentions overlay v0.22-dev9

This increment activates the authority and feasibility seams already carried by
`AudioIntentionContext`.

Audio still owns Audio truth. Authority and feasibility are external live gates
over that truth:

- discovery still reports the semantic capability that exists;
- a denied capability becomes `UNAVAILABLE` rather than disappearing;
- denied candidates retain the original ooRexx Audio objects and explicit gate
  evidence;
- composite selection rechecks the gates before READY;
- malformed gate objects fail closed.

A gate may be a Directory keyed by exact intention id, feature kind, or `*`,
or an object implementing:

    allowIntention(candidate, target, context)

The complete candidate is retained in the ChatGPT Library as
`layered_audio_oorexx_v0.22-dev9.zip`, SHA-256
`97c74f998d2daafac3a0c68dcd8d50f883b1ce1379c4a7d09ed46262176ed6b8`.

## Exact Git candidate

Autobuilder is currently not running, and independent qualification workers
cannot read ChatGPT Library bytes directly. The exact candidate is therefore
also committed under `exact_candidate/` as five deterministic base64 chunks.

Use:

    exact_candidate/reconstruct.sh /tmp/layered_audio_oorexx_v0.22-dev9.zip

to reconstruct and verify the exact ZIP, or:

    exact_candidate/hydrate.sh /tmp/layered-audio-dev9

to reconstruct, verify, unpack, check the package manifest and expose the full
source/test tree.

This removes the previous dev9 qualification blocker without pretending that
the older partial dev8 Git projection is complete.
