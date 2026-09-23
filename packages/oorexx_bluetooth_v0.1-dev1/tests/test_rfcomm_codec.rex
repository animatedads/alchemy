bytes=.BluetoothAddressCodec~bdaddr('AA:BB:CC:DD:EE:FF')
if bytes==.nil then do; say 'FAIL: codec nil'; exit 1; end
if c2x(bytes)<>'FFEEDDCCBBAA' then do; say 'FAIL: codec' c2x(bytes); exit 1; end
sock=.LinuxRfcommSocket~new
opened=sock~open
if opened then do
  say 'BLUETOOTH RFCOMM NATIVE SOCKET: OK fd='sock~fd
  sock~close
end
else say 'BLUETOOTH RFCOMM NATIVE SOCKET: UNAVAILABLE errno='sock~errno '(codec/ABI still qualified)'
say 'BLUETOOTH RFCOMM CODEC: OK'
::requires '../src/LinuxRfcomm.cls'
