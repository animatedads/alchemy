# ooRexx Bluetooth v0.1-dev1

An event-first, provider-neutral Bluetooth object model for ooRexx.

The design rejects the common "C calls wrapped in classes" model. Applications deal with devices, services, characteristics and registered events; providers deal with BlueZ/WinRT/native sockets.

Example application shape:

```rexx
thermometer = bluetooth~device('kitchen')
temperature = thermometer~environmentalSensing~temperature

temperature~on(.BluetoothEvents~GATT_VALUE_CHANGED, roomState, 'temperatureChanged')
temperature~notify(.true)
```

`environmentalSensing` and `temperature` are not hand-written methods. They are resolved by `UNKNOWN` through a semantic Bluetooth profile map.

## Included

- `BluetoothRuntime`, `BluetoothDevice`, `BluetoothAdapter`
- `GattService`, `GattCharacteristic`, `GattDescriptor`, `RfcommService`
- first-class device/address evidence (BLE addresses are not treated as permanent identity)
- registered event delivery via Event Runtime
- semantic service/characteristic profile maps loaded with ooRexx `json.cls`
- deterministic `BluetoothMemoryProvider`
- native Linux RFCOMM transport using Foreign Runtime v0.22.6 ABI-qualified metadata

## Current native boundary

Dev1 qualifies the RFCOMM socket/ABI boundary but does not claim a BlueZ GATT implementation. BLE/GATT platform access belongs behind `BluetoothProvider`; Linux BlueZ D-Bus is the natural next provider.
