# ooRexx Bluetooth v0.1-dev1 architecture

The application model is object/event first. Bluetooth wire/platform details are provider mechanics.

```text
OS / BlueZ / WinRT / native Bluetooth sockets
              |
          provider SPI
              |
       BluetoothRuntime
              |
       BluetoothDevice
       /             \
 RfcommService      GattService
                         |
                  GattCharacteristic
                         |
                registered events
```

## Rules

1. A Bluetooth address is observation evidence, not automatically durable identity. BLE private/random addresses may change.
2. Discovery/connection/pairing/RSSI/GATT notification are observations and become semantic events.
3. Reads, writes, pairing, connection and notification enable/disable are explicit control operations.
4. Raw UUIDs remain available but application code may use semantic aliases through `UNKNOWN`.
5. Platform APIs are replaceable providers. No BlueZ object path, HCI opcode, WinSock structure or ioctl belongs in application Rexx.
6. Native ABI layouts belong in Foreign Runtime bridge metadata.

The first native provider surface is Linux RFCOMM transport. Managed BLE/GATT discovery is deliberately provider-neutral in dev1; a BlueZ D-Bus provider can be added without changing the object API.
