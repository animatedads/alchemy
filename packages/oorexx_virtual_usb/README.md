# ooRexx Virtual USB v0.1-dev9

Device-side USB emulation for ooRexx, now with generic HID descriptor support and a development FIDO2 / CTAP2 authenticator.

## Core rule

The application models the device. USB descriptor packing, endpoint mechanics and CTAPHID framing stay below the application boundary.

```rexx
profile = .UsbDeviceProfileLoader~loadFile('maps/virtual_fido2_authenticator.json')
provider = .VirtualUsbMemoryProvider~new
device = .VirtualUsbDevice~fromProfile(profile, provider)
auth = .Fido2Authenticator~new(device)

auth~on(.Fido2Events~CREDENTIAL_CREATED, audit, 'created')
auth~on(.Fido2Events~ASSERTION_CREATED, audit, 'asserted')

device~present
```

On a Raw Gadget-capable host, the same semantic device can be presented through `LinuxRawGadgetProvider`. dev4 adds the blocking-I/O event/endpoint activity model needed for a real Raw Gadget host path and a dedicated live presenter. The supplied qualification container has no `/dev/raw-gadget`, so live host enumeration remains a target-environment qualification step rather than a claim of this package build.



## dev9 generation-safe live qualification

The dev8 target log revealed that the live qualifier could accept a USB device
left behind by an earlier presenter.  The qualifier printed `5-1 CAFE:F1D0`,
but the current dev8 presenter PID later failed `USB_RAW_IOCTL_RUN` with
`EBUSY` because `dummy_udc.0` was already occupied.  That means the dev8
HID-interface failure was not valid evidence about the dev8 provider.

dev9 makes presenter ownership and USB generation identity explicit:

- the selected UDC must be idle before launch;
- the presenter writes a ready marker only after its own Raw Gadget
  `INIT`/`RUN` succeeds;
- pre-existing `CAFE:F1D0` devices are snapshotted as
  `<sysfs-path>:<devnum>`;
- only a generation not present in that baseline may satisfy enumeration;
- cleanup escalates to `SIGKILL` if a blocked presenter survives INT/TERM;
- Raw Gadget trace lines can be written directly to a trace file so a blocked
  ioctl cannot hide the last completed setup/configuration step behind stdout
  buffering.

`tests/test_live_generation_guard.sh` exercises this logic without Raw Gadget:
it deliberately starts with stale `5-1`/devnum 2, reuses path `5-1` as devnum 3,
and proves that only the new generation can reach HID/hidraw PASS.

## dev8 live enumeration repair

dev8 fixes the first real host-enumeration defect exposed by dev7.  Raw Gadget
uses `USB_RAW_IOCTL_EP0_WRITE` for host-IN control requests and
`USB_RAW_IOCTL_EP0_READ` for host-OUT control requests.  The dev7 provider
incorrectly answered zero-length OUT requests such as `SET_CONFIGURATION` with
EP0_WRITE.  Linux could therefore create the CAFE:F1D0 device node after the
device/configuration descriptor phase but could not complete configuration and
bind the HID interface.

The provider now completes zero-length OUT requests with `EP0_READ(0)`, does not
issue a second EP0 operation after an OUT data-stage read, and emits opt-in
`RAWGADGET TRACE` control/endpoint/configuration diagnostics.  The live qualifier
enables that trace and prints it automatically if interface binding fails.

## dev7 host-preparation fixes

dev7 repairs the privilege-escalation handoff introduced with host reconstruction: both host scripts accept their private `--as-root` continuation before parsing public options, and the live wrapper now preserves the real failing return code after diagnostics.


### Running-kernel Raw Gadget host preparation

`tests/prepare_raw_gadget_host.sh` makes the Raw Gadget test substrate reproducible after a machine reinstall or kernel update.  It loads the in-tree `raw_gadget` module, prefers a loadable kernel-provided `dummy_hcd`, otherwise checks the retained `dummy_hcd.ko` vermagic and rebuilds it against `/lib/modules/$(uname -r)/build` when required.  When the running kernel source tree is available its `drivers/usb/gadget/udc/dummy_hcd.c` is the source authority, so a stale source file from an older kernel is not silently reused.

The rebuilt module is installed under `/lib/modules/<running-kernel>/extra/oorexx-vusb/`, followed by `depmod`, and then loaded normally with `modprobe`.  `tests/bringup_live_raw_gadget_fido.sh` invokes this preparation before the real host-enumeration test.  `--install-build-deps` may be supplied on openSUSE to install the required kernel-devel/source, compiler and make packages when the matching build tree is absent.

## dev5 additions

### One-command Raw Gadget host restoration + qualification

`tests/bringup_live_raw_gadget_fido.sh` resolves the caller's exact ooRexx executable and dependency roots before privilege escalation, so `sudo` PATH filtering cannot silently select a different interpreter. dev6 extends that path with running-kernel rebuild/install support rather than assuming an old out-of-tree module remains valid.

### Native presentation diagnostics

`LinuxRawGadgetProvider` now retains `lastPresentationError` for OPEN, INIT and RUN failures.  The live FIDO presenter reports the failing native operation, errno and message instead of collapsing all three failure points into `provider presentation failed`.

## dev4 additions

### Live Raw Gadget execution

`LinuxRawGadgetProvider~run` now owns the blocking Raw Gadget control/event loop. After a successful `SET_CONFIGURATION`, the provider starts one ooRexx activity for each enabled OUT endpoint so blocking `USB_RAW_IOCTL_EP_READ` calls do not prevent control/reset events from being serviced. IN endpoint writes remain synchronous with the CTAPHID response path.

`examples/virtual_fido2_authenticator_raw.rex` is the real-host presenter. It deliberately does **not** use `FidoTestHost`: Linux is the USB host. UDC driver/device, speed and raw-gadget path can be supplied through `OOREXX_VUSB_UDC_DRIVER`, `OOREXX_VUSB_UDC_DEVICE`, `OOREXX_VUSB_SPEED` and `OOREXX_VUSB_RAW_GADGET_PATH`.

`tests/live_raw_gadget_fido.sh` is the target-machine qualification script. It checks the exact ooRexx baseline and dependency closure, validates `/dev/raw-gadget` and the selected UDC, launches the presenter, then requires host enumeration as `CAFE:F1D0`, HID class binding and a matching `hidraw` node. If `fido2-token` is installed it also reports libfido2 discovery.

### Package requirements

`PACKAGE_LOAD_REQUIREMENTS.json` records package-load requirements, the qualified runtime/artifacts, and exported Rexx/native paths without pretending that filenames or marketing versions are semantic authority. This is intentionally resolver-facing: package launchers no longer need to discover dependencies with arbitrary filesystem `find | head -1` selection. `run_tests.sh` now reconstructs package-owned paths itself and accepts resolved dependency roots through `OOREXX_EVENT_RUNTIME_ROOT`, `OOREXX_CRYPTO_ROOT` and `OOREXX_FOREIGN_RUNTIME_ROOT`.

## dev3 additions

### Generic HID support

`oorexx.virtual.usb.device/0.3` adds an optional `hid` block to an interface. The loader creates both:

- the HID class descriptor embedded in the configuration descriptor;
- the HID report descriptor returned through standard interface `GET_DESCRIPTOR`.

This is generic Virtual USB functionality, not FIDO-specific special casing.

### FIDO USB personality

`maps/virtual_fido2_authenticator.json` presents:

- USB HID interface class `0x03`;
- one 64-byte interrupt OUT endpoint;
- one 64-byte interrupt IN endpoint;
- FIDO Alliance usage page `0xF1D0` and CTAPHID usage `0x01`;
- semantic function name `authenticator` with `hidIn`, `hidOut` and `SET_IDLE` objects.

### CTAPHID

Implemented in ooRexx:

- fixed 64-byte report framing;
- initialization and continuation packet assembly;
- channel allocation through `CTAPHID_INIT`;
- `CTAPHID_PING`;
- `CTAPHID_CBOR`;
- HID-layer error responses;
- multi-packet requests and responses.

### CTAP2 development authenticator

Implemented commands:

- `authenticatorGetInfo` (`0x04`);
- `authenticatorMakeCredential` (`0x01`);
- `authenticatorGetAssertion` (`0x02`).

The dev authenticator advertises `FIDO_2_0`, USB transport, discoverable credentials, user presence, and COSE algorithm `-8` (EdDSA/Ed25519).

Credentials are real Ed25519 keypairs and assertion signatures use ooRexx Crypto v0.8.3. **Credential seed derivation is deterministic for repeatable development tests and is not suitable for production security.**

Attestation is the development `none` form. No production attestation key is embedded.

### Registered semantic events

FIDO operations are ordinary Event Runtime events:

```text
FIDO2.HID.CHANNEL.ALLOCATED
FIDO2.AUTHENTICATOR.GET_INFO
FIDO2.AUTHENTICATOR.MAKE_CREDENTIAL
FIDO2.AUTHENTICATOR.CREDENTIAL.CREATED
FIDO2.AUTHENTICATOR.GET_ASSERTION
FIDO2.AUTHENTICATOR.ASSERTION.CREATED
FIDO2.AUTHENTICATOR.USER_PRESENCE
```

User-presence behavior is provider/policy-shaped (`FidoAlwaysPresent` is the development default), so a future board button, biometric component or UI approval does not change CTAP application semantics.

## Application-facing object path

```text
VirtualUsbDevice
    |
    +-- authenticator             VirtualUsbFunction
          |
          +-- fidoHid             VirtualUsbInterface
          |     +-- hidOut
          |     `-- hidIn
          |
          `-- SET_IDLE

Fido2Authenticator
    +-- store
    +-- userPresence
    +-- CTAPHID channel state
    `-- semantic FIDO2 events
```

## Dependencies

- ooRexx 5.3.0 r13196 qualification baseline
- Event Runtime `event.runtime/0.1`
- Crypto v0.8.3
- Foreign Runtime v0.22.6 for Linux Raw Gadget provider
- ooRexx distribution `json.cls`

## Deliberate boundaries

This cut is a development authenticator, not a FIDO certification claim. It does not yet implement:

- CTAP1/U2F `CTAPHID_MSG`;
- PIN/UV protocols;
- credential management;
- large blobs / extensions;
- authenticator reset/configuration;
- multi-assertion continuation (`getNextAssertion`);
- production entropy, secure key storage or production attestation;
- FIDO conformance/certification testing.

The implementation reports only the capability it actually implements (`FIDO_2_0`) rather than claiming CTAP 2.1/2.2/2.3 feature coverage.
