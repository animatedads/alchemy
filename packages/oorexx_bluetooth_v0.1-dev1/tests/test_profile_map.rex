loader=.BluetoothProfileMapLoader~new
map=loader~loadFile('../maps/standard_gatt.json')
if map==.nil then do; say 'FAIL: map load'; exit 1; end
if map~serviceUuid('environmentalSensing')<>_btUuid('181a') then do; say 'FAIL: service alias'; exit 1; end
if map~characteristicUuid('environmentalSensing','temperature')<>_btUuid('2a6e') then do; say 'FAIL: char alias'; exit 1; end
say 'BLUETOOTH PROFILE MAP: OK'
::requires '../src/Bluetooth.cls'
