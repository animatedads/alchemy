p=.TN3270TelnetProfile~new("IBM-3278-2-E"); w=.TN3270Wire~new(.nil,p)
/* negotiation and a complete EW record in one fragmented stream */
cp=.CodePage3270Registry~forName(37)
rec=.Command3270~ERASE_WRITE||"02"x||.Order3270~SBA||.Address3270~encode(0)||cp~encode("HELLO")
wire=.TelnetByte~IAC||.TelnetByte~DO||.TelnetOption~BINARY||.TelnetCodec~frameRecord(rec)
w~feed(wire~left(4)); w~feed(wire~substr(5)); call assert w~model~generation=1,'record generation'; call assert w~drainOutbound~length>0,'negotiation response'; say 'PASS TN3270 WIRE'; exit 0
assert: procedure; use arg ok,msg; if \ok then do; say 'FAIL' msg; exit 1; end; return
::requires "TN3270Wire.cls"
