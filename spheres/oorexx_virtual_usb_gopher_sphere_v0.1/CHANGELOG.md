# v0.1 current-state update (2026-10-27)

- Record dev10 repository/package candidate SHA-256 `e9dc6a1c90e97df563de81a4d64ad53339101cf7b63622aeda853835a303b701`.
- Preserve dev9 as Current Library until clean target-host qualification promotes a successor.
- Record the discovered dev9 qualifier race: USB device sysfs publication can precede HID interface and hidraw publication.
- Record dev10's bounded waits and delayed-binding regression; no FIDO/CTAPHID/Raw-Gadget semantic change.
- Change the immediate host acceptance instruction from dev9 to dev10.

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
