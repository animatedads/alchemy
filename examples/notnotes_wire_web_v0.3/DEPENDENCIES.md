# NotNotes Wire Web v0.3 — exact source/runtime dependencies

The files in this directory are **consumer-owned sources** only. The runnable qualification ZIP includes the pinned runtime dependencies, ooRexx installer and source tests. Reusing this example requires the same source closure; do not fabricate an alternate provider or silently substitute a newer core release.

| Library artifact | SHA-256 |
|---|---|
| `notnotes_mini_approval_app_v0.1-dev13.zip` | `c8efcfd1090555aabeecae6cf693ea518695f78bf9d601170a485c2dc5dc5ace` |
| `wire_ui_server_v0.17.zip` | `82c3a9d270d123dcbedabed1b57ed5e0944b828b1a184a5b71d47d9f9f188441` |
| `oorexx_queue_fabric_web_gateway_v0.2.zip` | `83118442d7c734e4a194598b0709311de7a055ae33fb4e094cccf3686b7ffcf8` |
| `oorexx_queue_fabric_v0.9-dev6.zip` | `4477733b121dc540b3325a834cd99a2665b07dc468e09181dd7aa8f01b728d40` |
| `alchemy_wire_ui_js_v0.4-dev6.zip` | `67cc8fd08172e3efa45f9eb6bbecadaa576b3c713508b7f5d5c902208f40ebcc` |
| `alchemy_objects_v0.8.zip` | `7683ed56ea99097226ea2f13f73305fb49919ba2ec822df2253ccfff59c6c073` |
| `oorexx_crypto_v0.8.3.zip` | `5ebcab81493287499719f98920cb190d37afc79992cb34c7772d5392f63b9b49` |
| `oorexx_intention_service_v0.1-dev11.zip` | `f935dda3740db7a79add3ccd85dfdbabf7bc4c70a5b727d8773e5eb5bd49cc96` |
| `ooRexx-r13196.deb` | `8add57fd2463403c9e91f3f49856e3f61b34753938abab3a617fc8063d2df4ae` |

The consumer uses recovered `AlchemyNotNotesIntentions.cls` dev15 alongside the dev13 MiniNotesApp. The version-pinned, local correctness test *does not establish interoperability with the current Mini NotNotes dev18 Git version*.

**Evidence:** local release `notnotes_wire_web_v0.3_20261111.zip` SHA-256 `0187ea35a47f8055bdf4ff046aeb5afce28b29ec620dec9fe0235a1794af66ed`, clean manifest 206/206 PASS; native WebSocket + real ooRexx application / browser-renderer integration PASS; retained reference/report reload PASS; six expected explicit refusals, zero unexpected errors. Production deployment, auth, SSL/TLS and real Chromium user acceptance are NOT_QUALIFIED.
