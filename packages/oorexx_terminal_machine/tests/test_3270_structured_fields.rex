call rxfuncadd 'SysLoadFuncs','RexxUtil','SysLoadFuncs'; call SysLoadFuncs
s=.DataStream3270~new
cp=s~codepage

/* Read Partition Query: WSF + 00 05 + SFID 01 + partition FF + Query 02. */
q=.Command3270~WRITE_STRUCTURED_FIELD||"000501FF02"x
r=s~applyHostRecord(q)
call assert r~ok,'WSF query accepted'
reply=s~drainStructuredReply
call assert reply~substr(1,1)==.Aid3270~STRUCTURED_FIELD,'structured-field AID'
call assert reply~length>1,'query reply emitted'

/* Parse every returned Query Reply and retain advertised QCODEs. */
pos=2; codes=""
do while pos<=reply~length
  call assert pos+3<=reply~length,'query reply header bounded'
  n=x2d(reply~substr(pos,2)~c2x)
  call assert n>=4,'query reply minimum length'
  call assert pos+n-1<=reply~length,'query reply length bounded'
  call assert reply~substr(pos+2,1)==.StructuredField3270~QUERY_REPLY,'query reply SFID'
  codes||=reply~substr(pos+3,1)
  pos+=n
end
call assert codes~pos(.StructuredField3270~QR_SUMMARY)>0,'summary advertised'
call assert codes~pos(.StructuredField3270~QR_USABLE_AREA)>0,'usable area advertised'
call assert codes~pos(.StructuredField3270~QR_COLOR)>0,'color advertised'
call assert codes~pos(.StructuredField3270~QR_HIGHLIGHTING)>0,'highlight advertised'

/* Query List returns only supported requested capabilities. */
ql=.Command3270~WRITE_STRUCTURED_FIELD||"000701FF0300"x||.StructuredField3270~QR_COLOR
r=s~applyHostRecord(ql); call assert r~ok,'query list accepted'
reply=s~drainStructuredReply
call assert reply~substr(1,1)==.Aid3270~STRUCTURED_FIELD,'query-list AID'
call assert reply~substr(5,1)==.StructuredField3270~QR_COLOR,'query-list color only'
call assert x2d(reply~substr(2,2)~c2x)==reply~length-1,'single query-list SF consumes reply'

/* Unsupported requested QCODE produces the protocol Null Query Reply. */
ql=.Command3270~WRITE_STRUCTURED_FIELD||"000701FF0300"x||"95"x
r=s~applyHostRecord(ql); call assert r~ok,'unsupported query list accepted'
reply=s~drainStructuredReply
call assert reply==.Aid3270~STRUCTURED_FIELD||"000481FF"x,'unsupported query gives null reply'

/* Set Reply Mode: only FIELD is claimed; richer modes fail closed. */
srm=.Command3270~WRITE_STRUCTURED_FIELD||"0005090000"x
r=s~applyHostRecord(srm); call assert r~ok & s~replyMode==.StructuredField3270~REPLY_MODE_FIELD,'field reply mode accepted'
srm=.Command3270~WRITE_STRUCTURED_FIELD||"0005090002"x
r=s~applyHostRecord(srm); call assert \r~ok & r~code=="3270_WSF_REPLY_MODE_UNSUPPORTED",'character mode not overclaimed'

/* Erase All Unprotected preserves protected data, erases input and MDT. */
rec=.Command3270~ERASE_WRITE||"02"x||.Order3270~SBA||.Address3270~encode(0)||.Order3270~SF||"20"x||cp~encode("LOCKED")||.Order3270~SBA||.Address3270~encode(20)||.Order3270~SF||"01"x||cp~encode("INPUT")
r=s~applyHostRecord(rec); call assert r~ok,'field screen written'
f=s~model~fieldAt(22); call assert f<>.nil,'input field found'; f~modified=.true
r=s~applyHostRecord(.Command3270~ERASE_ALL_UNPROTECTED); call assert r~ok,'EAU accepted'
call assert s~model~fieldDataBytes(s~model~fieldAt(2))~substr(1,6)==cp~encode("LOCKED"),'protected data preserved'
f=s~model~fieldAt(22)
call assert f~modified==.false,'EAU resets MDT'
call assert s~model~fieldDataBytes(f)~substr(1,5)==copies("00"x,5),'EAU clears unprotected data'

/* Read Modified All is an executable read and uses the normal response boundary. */
r=s~applyHostRecord(.Command3270~READ_MODIFIED_ALL); call assert r~ok,'RMA accepted'
r=s~buildReadResponse(.Command3270~READ_MODIFIED_ALL); call assert r~ok,'RMA response built'
call assert r~value~substr(1,1)==.Aid3270~NO_AID,'RMA response AID'

say 'PASS 3270 STRUCTURED FIELDS'
exit 0
assert: procedure
  use arg ok,msg
  if \ok then do; say 'FAIL' msg; exit 1; end
  return
::requires "DataStream3270.cls"
