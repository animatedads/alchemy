# Bluetooth as a Device Runtime consumer

Bluetooth provider mechanics remain below the object model:

- Linux: BlueZ D-Bus for managed discovery/pairing/GATT; native RFCOMM/HCI where
  a lower-level provider is justified.
- Windows: Winsock/WinRT provider.
- Other platforms can supply equivalent providers without changing application
  semantics.

Proposed domain objects:

```
BluetoothRuntime
  +-- BluetoothAdapter
  +-- BluetoothDevice
        +-- RfcommService
        +-- GattService
              +-- GattCharacteristic
                    +-- GattDescriptor
```

Discovery, connection and GATT notification are events:

- `BLUETOOTH.DEVICE.DISCOVERED`
- `BLUETOOTH.DEVICE.LOST`
- `BLUETOOTH.DEVICE.CONNECTED`
- `BLUETOOTH.DEVICE.DISCONNECTED`
- `BLUETOOTH.DEVICE.PAIRED`
- `BLUETOOTH.GATT.VALUE.CHANGED`
- `BLUETOOTH.GATT.SERVICES.CHANGED`
- `BLUETOOTH.RSSI.CHANGED`

Reads/writes/pairing remain explicit control operations rather than being hidden
inside observation callbacks.

BLE identity must not be equated blindly with the currently observed MAC
address: resolvable/private/random addresses can change. The provider must expose
a stable device identity when the platform has one and retain address evidence
as observation metadata.

Desired application shape:

```rexx
thermometer = bluetooth~device('kitchen-thermometer')
temperature = thermometer~service(.EnvironmentalSensing)~characteristic(.Temperature)

temperature~when(.ValueChanged)~notify(roomState,'temperatureChanged')
```

Raw HCI opcodes, BlueZ object paths and WinSock structures do not belong in that
application layer.
