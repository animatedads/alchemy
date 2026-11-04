# Git publication boundary — Media Methodologies v0.1-dev9

Qualified artifact: `oorexx_media_methodologies_v0.1-dev9.zip`

SHA-256: `f8d191fcf45316ce18c081f527037fead412a26000b77334c625f7c27b419dde`

Library path: `/oorexx_media_methodologies_v0.1-dev9.zip`

Dev9 is published as a source overlay on the already-published dev8 projection (`packages/oorexx_media_methodologies_v0.1-dev8`, dev8 publication commit `a724e19203886a1109e164b4faf12270222b1786`). Apply `DEV9_SOURCE_OVERLAY.patch` to that tree to obtain the dev9 source/spec/test surface.

The full qualified ZIP remains the distribution authority. It includes generated qualification material that is deliberately unsuitable for Git. The blind-control `PRIVATE_KEY.json` was mode 0600 during qualification, its audit SHA-256 was recorded, and the key was destroyed/excluded before release. Synthetic/generated WAV/FLAC provider fixtures are not Git publication authority.

Qualification summary:

- 183 methodologies / 183 work shapes;
- 28/28 ooRexx package tests PASS on ooRexx 5.3.0 r13196;
- 5/5 examples PASS;
- Audio Spectral Integrity v0.3 upstream: 17 tests PASS plus sphere JSON syntax;
- strict ooRexx standards: 60 files, 0 errors, 0 warnings;
- exact final fresh extraction: 440/440 manifest entries PASS and 28/28 runtime tests PASS.

Dev9 adds three bounded v0.3 falsification/qualification methods: local WOLA bucket views, exact-known-reference oracle template projection, and a blinded four-condition control trial. None acquires source-separation, source-count, transcript-truth, playback-location or intent authority.