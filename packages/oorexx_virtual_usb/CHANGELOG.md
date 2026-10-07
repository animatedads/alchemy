# v0.1-dev9

- Correct the live qualification boundary after the dev8 run exposed a stale-generation false positive: the script reported `5-1 CAFE:F1D0`, but the current presenter process later logged `usb_gadget_register_driver returned -16` because the selected UDC was already busy.
- Refuse to qualify when the requested UDC is already active before presenter launch; report processes holding `/dev/raw-gadget` when possible instead of silently testing against somebody else's generation.
- Snapshot pre-existing `CAFE:F1D0` devices as `<sysfs-path>:<devnum>` and require a new generation token before USB enumeration can pass, even when Linux reuses a path such as `5-1`.
- Add a presenter-owned ready marker written only after `USB_RAW_IOCTL_RUN` succeeds, so sysfs discovery cannot race ahead of proof that the current presenter actually owns the UDC.
- Strengthen presenter cleanup through INT -> TERM -> KILL escalation so a blocked development presenter cannot silently survive a failed qualification and poison the next run.
- Add file-backed `RAWGADGET TRACE` diagnostics to bypass stdio buffering during a blocked control transfer.
- Add `tests/test_live_generation_guard.sh`, which reproduces a stale `5-1` baseline and proves that only a new `devnum` generation plus HID/hidraw binding can pass.
- Correct package release metadata and stale source headers to `0.1-dev9`; public API versions remain unchanged.

# v0.1-dev8

- Fix Raw Gadget EP0 completion direction: IN control requests use `EP0_WRITE`; OUT control requests use `EP0_READ`.
- Complete zero-length OUT requests such as `SET_CONFIGURATION` and HID `SET_IDLE` with `EP0_READ(0)` instead of the dev7 `EP0_WRITE('')` path.
- Avoid issuing a second EP0 operation after an OUT request data stage has already been received with `EP0_READ`.
- Add live `RAWGADGET TRACE` diagnostics for setup packets, endpoint enable, configure and EP0 completion results; the live qualifier prints them automatically on HID-interface failure.
- Add a control-direction regression and update package build release constants to dev8 while retaining the existing API versions.

# v0.1-dev7

- Fix the sudo self-handoff in both Raw Gadget host scripts: the private `--as-root` marker is now parsed before public CLI options, so privilege escalation no longer rejects its own argument.
- Preserve the public `--install-build-deps` option across the corrected root handoff.
- Fix `bringup_live_raw_gadget_fido.sh` failure propagation so a failed live qualification returns the actual non-zero status after printing kernel diagnostics rather than accidentally returning success from the completed `if` statement.
- Keep dev6 running-kernel vermagic validation, rebuild/install behavior, dependency-root preservation and live FIDO enumeration gate unchanged.

# v0.1-dev6

- Add `tests/prepare_raw_gadget_host.sh` for deterministic Raw Gadget test-host reconstruction after OS reinstall or kernel update.
- Validate retained `dummy_hcd.ko` vermagic against the running kernel and rebuild automatically when it does not match.
- Prefer `dummy_hcd.c` from the running kernel source tree when available, preventing stale kernel-source reuse.
- Install the rebuilt module under the running kernel's `/lib/modules/.../extra/oorexx-vusb/`, run `depmod`, and load it with normal `modprobe`.
- Extend `tests/bringup_live_raw_gadget_fido.sh` to call host preparation before the live FIDO qualification and preserve all resolved ooRexx/dependency paths across sudo.
- Add optional `--install-build-deps` support for openSUSE host preparation.

# v0.1-dev5

- Add complete root-aware `tests/bringup_live_raw_gadget_fido.sh` target-host bring-up/qualification script.
- Preserve the caller's exact ooRexx executable and resolved dependency roots across sudo instead of depending on root PATH/environment policy.
- Restore `raw_gadget` and `dummy_hcd` after reboot; validate out-of-tree `dummy_hcd.ko` vermagic before loading.
- Add `lastPresentationError` diagnostics for Raw Gadget OPEN/INIT/RUN failures and surface them in the live presenter; add a missing-node regression proving OPEN errno retention.
- Record live Raw Gadget target requirements in `PACKAGE_LOAD_REQUIREMENTS.json`.
- Clarify the non-live unit gate message when `/dev/raw-gadget` is absent.
- Remove `result~...` use from the touched Raw Gadget diagnostics and configuration-state regression; `RESULT` remains an ooRexx special variable and is not used as an object carrier.

# Changelog

## v0.1-dev4

- added a real Raw Gadget blocking event loop (`LinuxRawGadgetProvider~run`);
- added concurrent OUT-endpoint reader activities after `SET_CONFIGURATION`;
- endpoint reader generations are retired across reset, disconnect and reconfiguration;
- added Raw Gadget errno diagnostics for event and endpoint operations;
- added `examples/virtual_fido2_authenticator_raw.rex`, with Linux as the real USB host rather than `FidoTestHost`;
- added end-to-end target environment qualifier `tests/live_raw_gadget_fido.sh`;
- added `PACKAGE_LOAD_REQUIREMENTS.json` for deterministic version/path resolution;
- fixed `run_tests.sh` so package-owned `src/`, `tests/` and the active ooRexx runtime directory are reconstructed automatically;
- added explicit resolved-root hooks for Event Runtime, Crypto and Foreign Runtime;
- preserved all dev3 semantic FIDO/CTAPHID/credential qualification tests.


## v0.1-dev3

- added generic interface descriptor model;
- added HID profile shorthand to `oorexx.virtual.usb.device/0.3`;
- standard interface-recipient `GET_DESCRIPTOR` now serves class/report descriptors;
- added FIDO2 USB HID development profile;
- added CTAPHID 64-byte packet framer/reassembler and channel allocation;
- added CTAPHID PING and CBOR paths;
- added minimal deterministic CBOR codec for CTAP2 values;
- added CTAP2 GetInfo, MakeCredential and GetAssertion;
- added Ed25519 credential/signature path through ooRexx Crypto v0.8.3;
- added discoverable development credential store;
- added user-presence policy seam;
- added semantic FIDO2 Event Runtime events;
- retained dev2 crypto-generator example and Raw Gadget provider behavior.

## v0.1-dev2

- declarative `/0.2` device profiles via `json.cls`;
- semantic USB function grouping;
- first-class mapped control objects;
- provider-confirmed configuration state and reconfiguration handling.
