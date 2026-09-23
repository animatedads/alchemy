# Device Runtime v0.1 architecture

```text
 kernel / native service
       |
       | Foreign Runtime v0.22.6
       v
 DeviceProvider ----------------------+
       |                               |
       v                               | enumerate
 DeviceMonitor                         v
       |                         DeviceIdentity[]
       +--> retained DeviceMonitorSnapshot
       |
       +--> DeviceEventBus --> subscriptions
                    |
                    +--> DeviceTrigger --> explicit action object
       |
       +--> Observation-compatible read-only surface
```

## Authority boundary

A provider may observe native device state and acquire native event records. It does not gain application authority merely by doing so. Triggers are separately registered objects with an explicit action. Future device-control classes should sit behind the common `/dev`-style explicit control convention and Access Control / Permissions / Security Effect rather than being methods hidden on read-only snapshots.

## Foreign Runtime boundary

ABI-sensitive structures (`pollfd` here; later `termios`, `usbdevfs_*`, `input_event`, GPIO structures) belong in ABI-qualified Foreign Runtime bridge metadata. They must not be packed using guessed byte offsets in Rexx application code.

## Initial provider

`LinuxUdevProvider` uses libudev for device enumeration and netlink-backed device notifications, with `poll(2)` used as the blocking boundary. Device property lists are copied into Rexx directories before the native device object is released.
