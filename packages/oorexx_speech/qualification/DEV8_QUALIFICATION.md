# ooRexx Speech v0.1-dev8 qualification

Runtime: ooRexx 5.3.0 r13196 Internal Test Version from the user-supplied debug DEB.

## Executed

The following regressions were executed against r13196:

- `test_contracts.rex` — PASS
- `test_optional_defaults.rex` — PASS
- `test_multi_channel.rex` — PASS, peak concurrency 4
- `test_streaming_tts.rex` — PASS, peak concurrency 4
- `test_audio_profiles.rex` — PASS
- `test_streaming_stt.rex` — PASS, peak concurrency 4, telephony-8k profile
- `test_audio_bridge.rex` — PASS

The dev8 bridge regression proves bounded raw-PCM source chunking; chunk release
and aggregate PCM sink output; exact PCM format checks; authoritative execution
binding `localPath()` consumption; durable `identityKey()` preservation in
Speech artifact metadata; preservation of the original authority object by
object identity; release returning to the execution/materialisation binding;
output binding `markWriting()`; and local PCM source -> streaming STT pumping.

No Layered Audio, RTP or SIP package is required by Speech.

## Standards gate

The final ZIP was scanned directly with the Library
`oorexx_standards_enforcer.py` in strict mode: errors 0, warnings 0, PASS.
