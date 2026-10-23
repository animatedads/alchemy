# Service Video Playout — LLM Gopher sphere v0.1

**Owner: ChatGPT (initial sphere author), 23 October 2026.** This is a documentation sphere; it does not replace Service Video Playout, the ooRexx Foreign Runtime, Intention Service, NotNotes or the browser.

## Exact baseline

- Full media and source candidate: `oorexx_service_video_playout_v0.1-dev3.zip`
- SHA-256: `45108698e6b7166df4181aa4b4008c55479593f1e3a82266542db1029e9c9298`
- Earlier GitHub source-only autobuild submission commit: `cbdbd5c9994ecf889952a83a15ea3a0060ca967a`
- Transport branch: `autobuild-submit/20261023T154600Z-CHATGPT-service-video-playout-dev3-45108698`
- **No accepted receipt/published component on main at sphere authoring time.**

The sphere preserves the difference between the original full dev3 development delivery, its source-only GitHub handoff, and actual successful Autobuild promotion.

## Start here

`gopher --profile service-video-playout context service-video-playout --full`

`gopher --profile service-video-playout search 'hold' --sphere service-video-playout`

`gopher --profile service-video-playout search 'PresentationGrant' --sphere service-video-playout`

Gopher availability and profile loading on the user's machine remain to be qualified. This package contains a dependency-free static structure/provenance validator at `tests/validate_sphere.py`.

## Primary invariants

- ooRexx decides scene sequences and accepts only authorised projections; native media owns output timing and device writing.
- Stable I420 1280x720 at 24 fps and 48 kHz two-channel PCM with separate camera and microphone.
- WAIT/HOLD maintain devices and silence without consuming queued media.
- Fixture `approveMediaDemo` is not a production disclosure grant.
- Dev3 native tests and standards checks passed, but dev3 has no verified live WebRTC/WhatsApp receiver acceptance.

The full executable archive, original clips and third-party bundled NotNotes ZIP are not reproduced in this sphere. Read `qualification/EVIDENCE.json` and `packs/service-video-playout/articles/`.
