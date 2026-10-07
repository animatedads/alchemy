call rxfuncadd 'SysLoadFuncs','RexxUtil','SysLoadFuncs'; call SysLoadFuncs
p=.TN3270TelnetProfile~new("IBM-3278-2-E")
w=.TN3270Wire~new(.nil,p)
cp=w~stream~codepage

/* RFC 2355 option acceptance. */
w~feed(.TelnetCodec~command(.TelnetByte~DO,.TelnetOption~TN3270E))
out=w~drainOutbound
call assert out==.TelnetCodec~command(.TelnetByte~WILL,.TelnetOption~TN3270E),'TN3270E WILL'
call assert p~tn3270eOffered,'TN3270E offered state'
call assert \p~tn3270eActive,'not active before subnegotiation'

/* Server asks for DEVICE-TYPE; client requests its configured Model-2 type. */
sendDevice=.TelnetCodec~subnegotiation(.TelnetOption~TN3270E,.TN3270ESubcommand~SEND||.TN3270ESubcommand~DEVICE_TYPE)
w~feed(sendDevice); out=w~drainOutbound
expected=.TelnetCodec~subnegotiation(.TelnetOption~TN3270E,.TN3270ESubcommand~DEVICE_TYPE||.TN3270ESubcommand~REQUEST||"IBM-3278-2-E")
call assert out==expected,'DEVICE-TYPE REQUEST'

/* Acceptance triggers the client-required FUNCTIONS REQUEST.  Candidate6
 * intentionally requests a null list: basic TN3270E, no unimplemented funcs. */
isDevice=.TelnetCodec~subnegotiation(.TelnetOption~TN3270E,.TN3270ESubcommand~DEVICE_TYPE||.TN3270ESubcommand~IS||"IBM-3278-2-E"||.TN3270ESubcommand~CONNECT||"TERM0001")
w~feed(isDevice); out=w~drainOutbound
expected=.TelnetCodec~subnegotiation(.TelnetOption~TN3270E,.TN3270ESubcommand~FUNCTIONS||.TN3270ESubcommand~REQUEST)
call assert out==expected,'null FUNCTIONS REQUEST'
call assert p~deviceAccepted,'device accepted'
call assert p~deviceName=="TERM0001",'device name retained'
call assert \p~tn3270eActive,'not active until functions accepted'

isFunctions=.TelnetCodec~subnegotiation(.TelnetOption~TN3270E,.TN3270ESubcommand~FUNCTIONS||.TN3270ESubcommand~IS)
w~feed(isFunctions); call assert w~drainOutbound=="",'FUNCTIONS IS needs no response'
call assert p~functionsAccepted,'functions accepted'
call assert p~tn3270eActive,'basic TN3270E active'

/* Incoming records now require and strip the five-byte message header. */
rec=.Command3270~ERASE_WRITE||"02"x||.Order3270~SBA||.Address3270~encode(0)||cp~encode("MVS READY")
h=.TN3270EHeader~new(.TN3270EDataType~DATA_3270,"00"x,"00"x,0)
rs=w~feed(.TelnetCodec~frameRecord(h~bytes||rec))
call assert rs~items==1 & rs[1]~ok,'header record accepted'
call assert w~model~generation==1,'TN3270E generation'
call assert w~model~text(cp)~left(9)=="MVS READY",'TN3270E data applied'
call assert w~lastHeader~dataType==.TN3270EDataType~DATA_3270,'header retained'

/* Host READ BUFFER receives a TN3270E-headered EOR record. */
readRec=h~bytes||.Command3270~READ_BUFFER
w~feed(.TelnetCodec~frameRecord(readRec)); out=w~drainOutbound
call assert out~right(2)==.TelnetByte~IAC||.TelnetByte~EOR,'TN3270E read EOR'
unframed=out~left(out~length-2)
call assert unframed~left(5)==h~bytes,'TN3270E response header'
call assert unframed~substr(6,1)==.Aid3270~NO_AID,'READ BUFFER AID follows header'

/* Operator AID records are likewise headered only after TN3270E activates. */
input=w~frameInput(w~stream~buildReadModified(.Aid3270~ENTER))
call assert input~left(5)==h~bytes,'operator input header'
call assert input~substr(6,1)==.Aid3270~ENTER,'operator AID after header'
call assert input~right(2)==.TelnetByte~IAC||.TelnetByte~EOR,'operator input EOR'

/* Basic mode refuses to silently pretend support for negotiated functions. */
p2=.TN3270TelnetProfile~new; w2=.TN3270Wire~new(.nil,p2)
w2~feed(.TelnetCodec~command(.TelnetByte~DO,.TelnetOption~TN3270E)); dummy=w2~drainOutbound
w2~feed(sendDevice); dummy=w2~drainOutbound
w2~feed(isDevice); dummy=w2~drainOutbound
reqResponse=.TelnetCodec~subnegotiation(.TelnetOption~TN3270E,.TN3270ESubcommand~FUNCTIONS||.TN3270ESubcommand~REQUEST||"02"x)
w2~feed(reqResponse); out=w2~drainOutbound
expected=.TelnetCodec~subnegotiation(.TelnetOption~TN3270E,.TN3270ESubcommand~FUNCTIONS||.TN3270ESubcommand~REQUEST)
call assert out==expected,'unsupported function countered with null list'
call assert \p2~tn3270eActive,'unsupported function not activated'

/* Once active, non-3270 basic data is surfaced explicitly, never misparsed as
 * a 3270 write command. */
nvt=.TN3270EHeader~new(.TN3270EDataType~NVT_DATA,"00"x,"00"x,0)~bytes||"hello"
rs=w~feed(.TelnetCodec~frameRecord(nvt))
call assert rs~items==1 & rs[1]~ok & rs[1]~value=="TN3270E_NVT_DATA",'NVT explicit result'
call assert w~drainNvtRecords[1]=="hello",'NVT retained separately'

say 'PASS TN3270E WIRE'
exit 0
assert: procedure
  use arg ok,msg
  if \ok then do; say 'FAIL' msg; exit 1; end
  return
::requires "TN3270Wire.cls"
