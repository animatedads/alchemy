call rxfuncadd 'SysLoadFuncs','RexxUtil','SysLoadFuncs'; call SysLoadFuncs
w=.TN3270Wire~new
q=.Command3270~WRITE_STRUCTURED_FIELD||"000501FF02"x
rs=w~feed(.TelnetCodec~frameRecord(q))
call assert rs~items==1 & rs[1]~ok,'wire WSF query accepted'
out=w~drainOutbound
call assert out~length>3,'wire query reply emitted'
call assert out~right(2)==.TelnetByte~IAC||.TelnetByte~EOR,'query reply EOR framed'
call assert out~substr(1,1)==.Aid3270~STRUCTURED_FIELD,'query reply starts with SF AID'

/* Traditional TN3270 RMA is framed too. */
w~feed(.TelnetCodec~frameRecord(.Command3270~READ_MODIFIED_ALL)); out=w~drainOutbound
call assert out~substr(1,1)==.Aid3270~NO_AID,'RMA wire response'
call assert out~right(2)==.TelnetByte~IAC||.TelnetByte~EOR,'RMA EOR'

say 'PASS TN3270 WSF WIRE'
exit 0
assert: procedure
  use arg ok,msg
  if \ok then do; say 'FAIL' msg; exit 1; end
  return
::requires "TN3270Wire.cls"
