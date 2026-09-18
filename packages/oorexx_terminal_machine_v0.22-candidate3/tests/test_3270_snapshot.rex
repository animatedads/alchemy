m=.PresentationSpace3270~new; d=.DataStream3270~new(m)
r=.Command3270~ERASE_WRITE||"02"x||.Order3270~SBA||.Address3270~encode(0)||.Order3270~SF||"20"x||.CodePage3270Registry~forName(37)~encode("LOGON ===>")||.Order3270~SBA||.Address3270~encode(80)||.Order3270~SF||"0C"x||.Order3270~IC
x=d~applyHostRecord(r); call assert x~ok,'host'
f=m~fields[2]; x=m~setFieldText(f,"SECRET",d~codepage); call assert x~ok,'stage'
s=.Terminal3270SnapshotFactory~fromPresentationSpace(m,d~codepage)~value
call assert s~terminalType=="IBM3270",'type'
call assert s~generation==1,'generation'
call assert s~fields~items==2,'fields'
call assert s~fields[1]~protected,'protected'
call assert s~fields[2]~inputCapable,'input'
call assert s~fields[2]~nonDisplay,'nondisplay'
call assert s~fields[2]~value=="",'secret not detached'
call assert s~fields[2]~displayValue~pos("SECRET")==0,'secret not displayed'
say 'PASS 3270 SNAPSHOT'
exit 0
assert: procedure; use arg ok,msg; if \ok then do; say 'FAIL' msg; exit 1; end; return
::requires "Terminal3270Snapshot.cls"
::requires "DataStream3270.cls"
