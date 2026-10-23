# v0.1

- Create the first Virtual USB continuity sphere around the current dev9 executable baseline.
- Record the provider-neutral VirtualUsbDevice / FIDO2 / CTAPHID / Raw Gadget layering.
- Preserve the Raw Gadget EP0 direction invariant: host-IN -> EP0_WRITE, host-OUT -> EP0_READ, including zero-length SET_CONFIGURATION.
- Preserve the dev8 stale-generation lesson and dev9 presenter-ownership/generation guard.
- Record current-kernel dummy_hcd reconstruction as host-test substrate rather than semantic device behavior.
- Record dependency authority: PACKAGE_LOAD_REQUIREMENTS is resolver-facing; ambient REXX_PATH and arbitrary filesystem first-match selection are not version authority.
- Record the development FIDO2 boundary and the requirement not to claim certification, production key security, browser enrollment or whole-device trust without separate evidence.
- Record defensive whole-device qualification doctrine: FIDO correctness and physical USB peripheral trust are separate claims.
- Record the next live-host, libfido2, browser/WebAuthn and powered-SoC continuation steps.
