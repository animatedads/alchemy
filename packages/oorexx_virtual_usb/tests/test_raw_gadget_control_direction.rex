/* Raw Gadget control-transfer direction regression. */
inReq=.UsbControlRequest~new(x2d('80'),6,x2d('0100'),0,18)
outReq=.UsbControlRequest~new(x2d('00'),9,1,0,0)
classOut=.UsbControlRequest~new(x2d('21'),x2d('0A'),0,0,0)
call ok inReq~direction='IN','GET_DESCRIPTOR is IN / EP0_WRITE response path'
call ok outReq~direction='OUT','SET_CONFIGURATION is OUT / EP0_READ response path'
call ok outReq~length=0,'SET_CONFIGURATION has zero-length OUT data stage'
call ok classOut~direction='OUT' & classOut~length=0,'SET_IDLE is zero-length OUT'
say 'VIRTUAL USB RAW GADGET CONTROL DIRECTION: OK'
exit 0
ok: procedure
  use arg condition,label
  if \condition then do; say 'FAIL:' label; exit 1; end
  return
::requires 'UsbModel.cls'
