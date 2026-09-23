# Virtual USB architecture

## 1. Boundary

The API models the *device side* of USB.  A hardware prototype should look to
application Rexx like a board with semantic interfaces and requests, not like a
collection of setup packets.

```text
Application / board behaviour
           |
   registered semantic events
           |
 VirtualUsbDevice
   |       |       |
interface control endpoint
   |       |       |
     USB Chapter 9
           |
   VirtualUsbProvider
      /          \
Memory host   Linux Raw Gadget
                  |
             Foreign Runtime
                  |
            Linux UDC / USB core
```

## 2. Descriptor authority

`UsbDeviceDefinition` owns the USB identity and configuration graph.  Device,
configuration, interface, endpoint and string descriptors are encoded by the
USB model.  Applications do not manually concatenate descriptor bytes.

The definition also owns a `UsbControlMap`.  Vendor/class setup requests map to
semantic names such as `GET_RANDOM`.  The numeric USB request identity remains
protocol metadata.

## 3. Control requests are synchronous registered events

USB endpoint zero has a request/response deadline, so its semantic event path
is intentionally synchronous.

```text
Host SETUP packet
      |
UsbControlRequest
      |
Chapter 9 standard handler ----> automatic descriptor/config response
      |
implementation map
      |
USB.CONTROL.CRYPTO.GET_RANDOM
      |
registered ooRexx object
      |
UsbControlTransaction~respond(bytes)
```

`RAISE` is not used as an event mechanism.

## 4. Endpoint data

OUT endpoint data is observed and emitted as `USB.ENDPOINT.DATA`.  IN endpoint
content is written through the semantic endpoint object.  The provider owns the
actual kernel transfer operation.

```rexx
device~crypto~commandOut~on('data', commandProcessor, 'received')
device~crypto~randomIn~write(bytes)
```

## 5. Linux Raw Gadget

The first physical provider uses `/dev/raw-gadget` and the Linux
`USB_RAW_IOCTL_*` contract through Foreign Runtime.  No structure size or ioctl
constant is guessed at runtime.  The supplied bridge is qualified specifically
for `linux-x86_64-le-lp64`; other ABIs require their own qualified profile.

Raw Gadget handles:

- UDC binding and RUN
- CONNECT / CONTROL / SUSPEND / RESUME / RESET / DISCONNECT events
- EP0 READ/WRITE/STALL
- endpoint enable
- configuration transition
- endpoint READ/WRITE primitives

## 6. Local virtual hardware loop

With `dummy_hcd`, a device presented by Raw Gadget can be enumerated by the same
Linux host as if hardware had appeared.  This is intended for tests where the
future physical board does not exist yet.

The host side can therefore be exercised through the existing Device Runtime,
USB host API, ADB client, or another consumer without changing the emulated
firmware behaviour.

## 7. Deliberate dev1 limits

- one active configuration is the qualified path;
- alternate settings are represented but only alternate zero is handled;
- no isochronous scheduling engine yet;
- no resident background endpoint reader in Raw Gadget provider yet;
  `readEndpointOnce()` supplies the native primitive;
- USB string descriptor encoder accepts ASCII in dev1;
- declarative JSON personality loading is planned; dev1 device definitions are
  programmatic so the object/event contract could be qualified first.
