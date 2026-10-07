# Virtual USB dev9 architecture

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

## Raw Gadget concurrency boundary

Raw Gadget transfer ioctls are blocking. dev4 therefore separates control-plane and data-plane activities:

```text
main ooRexx activity
    USB_RAW_IOCTL_EVENT_FETCH
    control requests / reset / disconnect
              |
              +---- SET_CONFIGURATION ----+
                                           |
                                  OUT endpoint reader activity
                                  USB_RAW_IOCTL_EP_READ
                                           |
                                  VirtualUsbEndpoint~_receive
                                           |
                                  Fido2Authenticator
                                           |
                                  hidIn~write
                                           |
                                  USB_RAW_IOCTL_EP_WRITE
```

Endpoint-reader generations are retired on reconfiguration/reset/disconnect. A reset is expected to wake blocked endpoint transfers with a kernel error; the control activity remains available to process re-enumeration. The current provider still uses the endpoint addresses declared by the profile; dynamic `USB_RAW_IOCTL_EPS_INFO` endpoint assignment for UDCs with fixed endpoint restrictions remains future portability work.


## Raw Gadget host preparation boundary

`dummy_hcd` is test-host substrate, not part of the Virtual USB semantic device.  A machine reinstall or kernel update invalidates any assumption that an older out-of-tree `.ko` remains loadable.  `tests/prepare_raw_gadget_host.sh` therefore treats the running kernel as native-module authority: use an installed loadable module when available, otherwise rebuild from the running-kernel source/API and install only into that kernel's module tree.  The FIDO/USB objects remain unchanged by this host preparation.


## dev9 live-evidence generation boundary

A live USB observation is authoritative only when it can be tied to the
presenter process created by that qualification run.

The qualifier therefore treats these as separate facts:

```text
presenter process exists
    != presenter owns requested UDC
    != matching VID:PID exists in sysfs
    != matching VID:PID belongs to this presenter generation
    != HID interface bound
    != hidraw bound
```

The presenter emits an out-of-band ready marker only after
`LinuxRawGadgetProvider~present` has completed Raw Gadget `INIT` and `RUN`.
Before launch, the qualifier snapshots every matching `CAFE:F1D0` device as a
`sysfs-name:devnum` token.  A later match is accepted only when that generation
token was absent from the baseline.  This deliberately handles Linux reusing a
stable path such as `5-1` across separate USB device numbers.

The selected UDC must also be idle before launch.  An already-active UDC is a
qualification failure, not an invitation to inspect whatever device happens to
be present on the dummy host bus.

## dev8 Raw Gadget control-transfer invariant

Raw Gadget exposes the host direction directly at endpoint zero. A control
request whose bmRequestType direction is IN is answered with EP0_WRITE. A
control request whose direction is OUT is answered with EP0_READ, including the
zero-length SET_CONFIGURATION status path. OUT requests with a data stage use a
single EP0_READ for that stage and are not followed by EP0_WRITE.

This provider rule is distinct from the semantic USB Chapter 9 model. The same
VirtualUsbDevice remains provider-neutral; LinuxRawGadgetProvider owns the
native Raw Gadget completion mechanics.
