# ooRexx Virtual USB v0.1-dev1

Device-side USB emulation for ooRexx.

This is not USB discovery.  It models a USB peripheral which is *presented to a
host*.  Application code owns the semantic behaviour of the emulated board;
USB descriptors, Chapter 9 enumeration, endpoint plumbing and Linux Raw Gadget
ioctls stay below the application boundary.

## Application model

```rexx
provider = .LinuxRawGadgetProvider~new('dummy_udc','dummy_udc.0')
device   = .VirtualUsbDevice~new('board:crypto-prototype', definition, provider)

crypto = .CryptoPrototype~new
device~crypto~onRequest('GET_RANDOM', crypto, 'randomRequested')
device~crypto~commandOut~on('data', crypto, 'commandReceived')

device~present
```

`crypto`, `commandOut` and `randomIn` are semantic interface/endpoint names in
the device definition.  They are resolved by the object model; application
code does not know endpoint descriptor bytes or ioctl numbers.

A synchronous control request handler receives an Event whose data is a
`UsbControlTransaction` and completes the USB request with `respond(bytes)` or
`stall`.

## Included layers

- `UsbDeviceDescriptor`, `UsbConfigurationDefinition`,
  `UsbInterfaceDefinition`, `UsbEndpointDefinition`
- `UsbControlRequest`, `UsbControlTransaction`, `UsbControlMap`
- `UsbChapter9` enumeration/control engine
- `VirtualUsbDevice`, `VirtualUsbInterface`, `VirtualUsbEndpoint`
- Event Runtime integration for semantic control and endpoint events
- `VirtualUsbMemoryProvider` for deterministic host-side qualification
- `LinuxRawGadgetProvider` using Foreign Runtime v0.22.6

## Linux presentation path

For arbitrary USB-device emulation Linux Raw Gadget is the right low-level
provider.  It binds a userspace device implementation to a USB Device
Controller (UDC).

For local development, Linux `dummy_hcd` can supply a virtual host controller
and `dummy_udc.N`.  This creates an especially useful loop:

```text
ooRexx VirtualUsbDevice
        |
   Raw Gadget
        |
   dummy_udc
        |
   dummy_hcd host side
        |
 Linux USB core / udev
        |
 ooRexx Device Runtime
```

On gadget-capable physical hardware the same provider can instead bind to the
real UDC and appear to another machine over the USB cable.

The kernel-facing path needs `/dev/raw-gadget`, a suitable UDC, and permissions
to use it.  The package does not shell out to `modprobe`, configfs tools or a C
helper.

## Dependencies

- ooRexx 5.3.0 r13196 qualification baseline
- Event Runtime `event.runtime/0.1`
- Foreign Runtime v0.22.6 for Linux Raw Gadget

## Qualification boundary

The supplied execution environment has no `/dev/raw-gadget` / UDC, so live
host enumeration is not claimed.  The device model, Chapter 9 engine, semantic
request/event path and endpoint I/O contract are executable and qualified with
the memory host.  The x86_64 Linux Raw Gadget bridge is ABI-qualified against
the installed Linux userspace headers and loads through Foreign Runtime.

See `VALIDATION.txt` and `ARCHITECTURE.md`.
