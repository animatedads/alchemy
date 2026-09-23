# ooRexx Virtual USB v0.1-dev3

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

On a Raw Gadget-capable host, the same semantic device can be presented through `LinuxRawGadgetProvider`; the qualification environment used for this cut has no `/dev/raw-gadget`, so live host enumeration is not claimed.

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
