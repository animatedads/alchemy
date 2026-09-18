call rxfuncadd 'SysLoadFuncs','RexxUtil','SysLoadFuncs'; call SysLoadFuncs
m=.PresentationSpace3270~new; d=.DataStream3270~new(m)
/* EW: protected label at 0, input field at 80, cursor at 81. */
r=.Command3270~ERASE_WRITE||"02"x||.Order3270~SBA||.Address3270~encode(0)||.Order3270~SF||"20"x||.CodePage3270Registry~forName(37)~encode("READY")||.Order3270~SBA||.Address3270~encode(80)||.Order3270~SF||"00"x||.Order3270~IC
x=d~applyHostRecord(r); call assert x~ok,'host record'; call assert m~generation=1,'generation'; call assert m~cursor=81,'cursor'
fs=m~fields; call assert fs~items=2,'fields'; call assert fs[1]~protected,'protected'; call assert \fs[2]~protected,'input'
x=m~setFieldText(fs[2],"LOGON TEST",d~codepage); call assert x~ok,'set field'
in=d~buildReadModified(.Aid3270~ENTER); call assert in~left(1)==.Aid3270~ENTER,'aid'; call assert in~pos(.Order3270~SBA)>0,'sba'; say 'PASS 3270 DATASTREAM'
exit 0
assert: procedure; use arg ok,msg; if \ok then do; say 'FAIL' msg; exit 1; end; return
::requires "DataStream3270.cls"
