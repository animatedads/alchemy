# Virtual USB dev3 architecture

## Device-side boundary

```text
                 ooRexx behavior
                       |
              Fido2Authenticator
                       |
             CTAP2 semantic engine
                       |
              CTAPHID framing
                       |
             VirtualUsbEndpoint
                       |
              provider-neutral SPI
                 /             \
      Memory qualification   Linux Raw Gadget
                                  |
                            USB Device Controller
                                  |
                               USB host
```

The FIDO engine does not call Raw Gadget, `ioctl()`, HID kernel APIs or USB endpoint handles. It writes and observes semantic Virtual USB endpoints.

## HID descriptor ownership

HID support belongs to Virtual USB core. An interface can carry descriptors which are either included in its configuration encoding or served separately by interface-recipient `GET_DESCRIPTOR`.

The profile loader's `hid` shorthand creates:

```text
HID descriptor (0x21)      included in configuration
HID report descriptor      served as descriptor 0x22
```

This is reusable for non-FIDO HID devices.

## FIDO layering

```text
USB HID report
    |
CTAPHID packet assembler
    |
CTAPHID message
    |
CTAP2 command dispatcher
    |
CBOR model
    |
Authenticator objects / credential store / presence policy
    |
Event Runtime
```

The application sees credential and assertion events, not CTAPHID sequence numbers or CBOR map offsets.

## Security boundary

The development credential factory intentionally derives Ed25519 seeds deterministically. It exists to make qualification repeatable and must never be confused with a production authenticator key-generation provider.

A production implementation should replace the credential factory and store with capabilities backed by hardware entropy, protected key storage / secure element semantics and an appropriate attestation authority. That replacement does not alter the USB, CTAPHID or application event model.
