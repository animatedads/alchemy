# Vision dev20 keyframe ownership — publication status

The working source archive is `oorexx_vision_v0.1-dev20-keyframe-ownership.zip`.

## Semantic change

`V5VTemporalCodec.decodeRecord` must return a detached snapshot for KEYFRAME records, not the mutable `record~payload` object. This complements producer-to-encoder and encoder-to-record snapshot isolation from dev19.

The complete dev20 source archive contains the regression tests:
- `tests/test_v5v_keyframe_record_tamper.rex`
- `tests/test_v5v_record_ownership.rex`
- `tests/test_v5v_snapshot_isolation.rex`

Prior local qualification reported 14/14 test files passing under ooRexx 5.3.0 r13196 and standards enforcer PASS with 0 hard findings / 53 warnings. These are historical results, not a new GitHub CI run.

## Publication caution

This commit records the handoff and version marker. It does **not** assert that the complete dev20 source archive has been synchronized to the GitHub working tree. Compare the archive against `packages/oorexx_vision` and publish changed source and tests before considering the repository caught up. In particular, do not claim a runtime-qualified integration with Camera Behaviour.

Vision owns reconstructed spatial evidence; Camera Behaviour owns temporal tracks, containment, and motion interpretation.
