# ooRexx Device Runtime v0.1-dev1

Linux-first, provider-neutral device observation and trigger substrate for ooRexx.

This is deliberately **not** a USB library, serial library or IoT framework disguised as one class. It separates:

- device identity and current metadata;
- provider-specific discovery/event acquisition;
- local event publication/subscription;
- deterministic trigger matching and firing;
- read-only Observation compatibility;
- native ABI crossing through ooRexx Foreign Runtime.

The first provider is `LinuxUdevProvider`. It talks directly to `libudev.so.1` and `libc poll(2)` through Foreign Runtime v0.22.6 metadata. There is no shelling out, Python, Java, libusb wrapper extension, or package-specific C shim.

## Core classes

- `DeviceIdentity` — stable provider key plus subsystem/sysname/syspath/devnode/devtype and detached properties.
- `DeviceEvent` — ordered ADD/REMOVE/CHANGE/etc event with device identity and metadata.
- `DeviceEventFilter` — kind/subsystem/provider/property matching.
- `DeviceEventBus` / `DeviceSubscription` — local observers implementing `onDeviceEvent(event)`.
- `DeviceTrigger` — filter + action object implementing `onDeviceTrigger(trigger,event)`.
- `DeviceMonitor` — provider lifecycle, event sequencing, retained snapshots, trigger/event dispatch.
- `DeviceMonitorSnapshot` — detached read-only event snapshot.
- `LinuxUdevProvider` — enumeration and live hotplug/change monitoring through Foreign Runtime.

## Observation seam

`DeviceMonitor` intentionally implements the method surface required by Observation v0.5: `sessionId`, `terminalType`, `deviceName`, `snapshot`, `current`, `back`, `history`, and the known-state methods. It can therefore be passed directly to `ObservationStream` without making Observation a compile-time dependency of Device Runtime.

## Why this shape

Hardware notification is a capability, not an authority to mutate hardware. Observation and triggering are separate from future `/dev`-style control operations. A trigger action is explicit ooRexx behaviour; provider code does not silently execute arbitrary actions merely because the kernel emitted a device event.

Future providers can cover Linux input/evdev, GPIO/gpiod, serial/termios, USB usbfs, Bluetooth, mDNS/Chromecast discovery, and MQTT session events while preserving the same device/event/trigger surface.

## Qualification in this development cut

Qualified against the supplied ooRexx 5.3.0 r13196 debug runtime and Foreign Runtime v0.22.6. Core synthetic event/trigger qualification passes, Linux libudev enumeration/monitor startup passes, and the optional Observation v0.5 integration test proves that `ObservationProtocol` accepts `DeviceMonitor` and `ObservationStream` publishes a retained device event snapshot.
