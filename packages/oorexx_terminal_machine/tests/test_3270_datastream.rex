call rxfuncadd 'SysLoadFuncs','RexxUtil','SysLoadFuncs'; call SysLoadFuncs
m=.PresentationSpace3270~new; d=.DataStream3270~new(m)
/* EW: protected label at 0, input field at 80, cursor at 81. */
r=.Command3270~ERASE_WRITE||"02"x||.Order3270~SBA||.Address3270~encode(0)||.Order3270~SF||"20"x||.CodePage3270Registry~forName(37)~encode("READY")||.Order3270~SBA||.Address3270~encode(80)||.Order3270~SF||"00"x||.Order3270~IC
x=d~applyHostRecord(r); call assert x~ok,'host record'; call assert m~generation=1,'generation'; call assert m~cursor=81,'cursor'
fs=m~fields; call assert fs~items=2,'fields'; call assert fs[1]~protected,'protected'; call assert \fs[2]~protected,'input'
x=m~setFieldText(fs[2],"LOGON TEST",d~codepage); call assert x~ok,'set field'
in=d~buildReadModified(.Aid3270~ENTER); call assert in~left(1)==.Aid3270~ENTER,'aid'; call assert in~pos(.Order3270~SBA)>0,'sba'
/* Read Buffer reconstructs field attributes rather than leaking placeholder NULs. */
rb=d~buildReadBuffer(.Aid3270~NO_AID); call assert rb~left(1)==.Aid3270~NO_AID,'rb aid'; call assert rb~substr(4,2)==.Order3270~SF||"20"x,'rb protected sf'; call assert rb~pos(.Order3270~SF||"00"x)>0,'rb input sf'
/* Host READ BUFFER/READ MODIFIED are accepted as read commands. */
call assert d~applyHostRecord(.Command3270~READ_BUFFER)~ok,'read buffer command'; call assert d~buildReadResponse(.Command3270~READ_BUFFER)~ok,'read buffer response'
call assert d~applyHostRecord(.Command3270~READ_MODIFIED)~ok,'read modified command'; call assert d~buildReadResponse(.Command3270~READ_MODIFIED)~ok,'read modified response'
/* WCC reset-MDT clears modified state. */
r2=.Command3270~WRITE||"40"x; call assert d~applyHostRecord(r2)~ok,'reset mdt write'; call assert \fs[2]~modified,'mdt reset'
/* A field may wrap from the bottom of the presentation space to the top. */
m2=.PresentationSpace3270~new; d2=.DataStream3270~new(m2); cp=d2~codepage
r3=.Command3270~ERASE_WRITE||"02"x||.Order3270~SBA||.Address3270~encode(1900)||.Order3270~SF||"00"x||.Order3270~SBA||.Address3270~encode(10)||.Order3270~SF||"20"x
y=d2~applyHostRecord(r3); call assert y~ok,'wrap fields'; wf=m2~fields[1]; call assert m2~fieldDataBytes(wf)~length==29,'wrap field capacity'
y=m2~setFieldText(wf,"WRAPS",cp); call assert y~ok,'wrap set'; rm=d2~buildReadModified(.Aid3270~ENTER); call assert rm~pos(cp~encode("WRAPS"))>0,'wrap read modified'
say 'PASS 3270 DATASTREAM'
exit 0
assert: procedure; use arg ok,msg; if \ok then do; say 'FAIL' msg; exit 1; end; return
::requires "DataStream3270.cls"
