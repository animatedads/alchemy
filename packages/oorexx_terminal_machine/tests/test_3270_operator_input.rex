m=.PresentationSpace3270~new; d=.DataStream3270~new(m); cp=d~codepage
/* A protected label followed by one unprotected input field. */
rec=.Command3270~ERASE_WRITE||"02"x||,
    .Order3270~SBA||.Address3270~encode(0)||.Order3270~SF||"20"x||cp~encode("TSO USERID")||,
    .Order3270~SBA||.Address3270~encode(80)||.Order3270~SF||"00"x||.Order3270~IC||,
    .Order3270~SBA||.Address3270~encode(100)||.Order3270~SF||"20"x
r=d~applyHostRecord(rec); call assert r~ok,'host screen'
call assert m~inputFields~items==1,'one input field'
call assert m~linearAddress(2,2)==81,'row column address'
call assert m~rowForAddress(81)==2,'address row'
call assert m~columnForAddress(81)==2,'address column'
call assert m~fieldAtPosition(2,2)==m~fields[2],'field by position'

/* Operator-facing input is coordinate based but preserves native 3270 MDT. */
r=m~setInputTextAt(2,2,"IBMUSER",cp); call assert r~ok,'set input at row column'
call assert m~cursor==81,'input moves cursor to requested position'
call assert m~fields[2]~modified,'input sets MDT'
call assert m~fieldText(m~fields[2],cp)~left(7)=="IBMUSER",'input text stored'
rm=d~buildReadModified(.Aid3270~ENTER)
call assert rm~left(1)==.Aid3270~ENTER,'enter aid'
call assert rm~pos(.Order3270~SBA||.Address3270~encode(81)||cp~encode("IBMUSER"))>0,'modified field wire output'

/* Cursor-relative input uses the containing unprotected field. */
r=m~setCursorPosition(2,5); call assert r~ok,'set cursor position'
r=m~setInputTextAtCursor("TEST",cp); call assert r~ok,'cursor-relative input'
call assert m~fieldText(m~fields[2],cp)~left(4)=="TEST",'cursor input field update'

/* Fail closed for protected, attribute-byte and out-of-range targets. */
call assertCode m~setInputTextAt(1,2,"NO",cp),'3270_PROTECTED_FIELD','protected position'
call assertCode m~setInputTextAt(2,1,"NO",cp),'3270_FIELD_ATTRIBUTE_POSITION','field attribute position'
call assertCode m~setInputTextAt(25,1,"NO",cp),'3270_CURSOR_RANGE','range'

say 'PASS 3270 OPERATOR INPUT'
exit 0
assert: procedure; use arg ok,msg; if \ok then do; say 'FAIL' msg; exit 1; end; return
assertCode: procedure; use arg result,code,msg; if result~ok | result~code<>code then do; say 'FAIL' msg 'expected='code 'actual='result~code; exit 1; end; return
::requires "DataStream3270.cls"
