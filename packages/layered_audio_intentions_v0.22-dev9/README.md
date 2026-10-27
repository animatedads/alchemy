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

The full candidate is retained in the ChatGPT Library as
`layered_audio_oorexx_v0.22-dev9.zip`, SHA-256
`97c74f998d2daafac3a0c68dcd8d50f883b1ce1379c4a7d09ed46262176ed6b8`.

Because the earlier dev8 GitHub source projection was incomplete, this directory
records the exact dev8->dev9 source delta plus the new regression rather than
pretending that the partial dev8 projection is a complete build tree.
