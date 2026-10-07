call rxfuncadd 'SysLoadFuncs','RexxUtil','SysLoadFuncs'; call SysLoadFuncs
s=.DataStream3270~new
cp=s~codepage

/* Build one protected and one unprotected field.  Force both MDTs on so
 * Read Modified and Read Modified All can be distinguished. */
rec=.Command3270~ERASE_WRITE||"02"x||,
    .Order3270~SBA||.Address3270~encode(0)||.Order3270~SF||"21"x||cp~encode("PROTECTED")||,
    .Order3270~SBA||.Address3270~encode(40)||.Order3270~SF||"01"x||cp~encode("INPUT")
r=s~applyHostRecord(rec); call assert r~ok,'base field screen'
protected=s~model~fields[1]; input=s~model~fields[2]
protected~modified=.true; input~modified=.true

rm=s~buildReadResponse(.Command3270~READ_MODIFIED)
call assert rm~ok,'RM response built'
call assert rm~value~pos(cp~encode("INPUT"))>0,'RM contains input MDT field'
call assert rm~value~pos(cp~encode("PROTECTED"))==0,'RM excludes protected MDT field'

rma=s~buildReadResponse(.Command3270~READ_MODIFIED_ALL)
call assert rma~ok,'RMA response built'
call assert rma~value~pos(cp~encode("INPUT"))>0,'RMA contains input MDT field'
call assert rma~value~pos(cp~encode("PROTECTED"))>0,'RMA contains protected MDT field'

/* Read Partition uses the implicit partition (00) and returns the same native
 * inbound 3270DS record boundary as the direct read commands. */
rbSf="00050100F2"x
r=s~applyHostRecord(.Command3270~WRITE_STRUCTURED_FIELD||rbSf)
call assert r~ok,'Read Partition Read Buffer accepted'
reply=s~drainStructuredReply
call assert reply~substr(1,1)==.Aid3270~NO_AID,'Read Partition RB AID'
call assert reply~pos(cp~encode("PROTECTED"))>0,'Read Partition RB carries presentation space'

rmSf="00050100F6"x
r=s~applyHostRecord(.Command3270~WRITE_STRUCTURED_FIELD||rmSf)
call assert r~ok,'Read Partition Read Modified accepted'
reply=s~drainStructuredReply
call assert reply~pos(cp~encode("INPUT"))>0,'Read Partition RM input'
call assert reply~pos(cp~encode("PROTECTED"))==0,'Read Partition RM excludes protected'

rmaSf="000501006E"x
r=s~applyHostRecord(.Command3270~WRITE_STRUCTURED_FIELD||rmaSf)
call assert r~ok,'Read Partition Read Modified All accepted'
reply=s~drainStructuredReply
call assert reply~pos(cp~encode("INPUT"))>0,'Read Partition RMA input'
call assert reply~pos(cp~encode("PROTECTED"))>0,'Read Partition RMA protected'

/* Outbound 3270DS wraps an ordinary write-type command for partition 00. */
payload=.Command3270~ERASE_WRITE||"02"x||.Order3270~SBA||.Address3270~encode(160)||cp~encode("OUTBOUND3270DS")
length=4+payload~length
sf=d2c(length%256)||d2c(length//256)||.StructuredField3270~OUTBOUND_3270DS||"00"x||payload
r=s~applyHostRecord(.Command3270~WRITE_STRUCTURED_FIELD||sf)
call assert r~ok,'Outbound 3270DS accepted'
call assert s~model~text(cp)~pos("OUTBOUND3270DS")>0,'Outbound 3270DS updates presentation space'

/* Explicit partitions are not implemented and must not silently alias 00. */
bad=d2c(length%256)||d2c(length//256)||.StructuredField3270~OUTBOUND_3270DS||"01"x||payload
r=s~applyHostRecord(.Command3270~WRITE_STRUCTURED_FIELD||bad)
call assert \r~ok & r~code=="3270_WSF_BAD_PARTITION",'explicit partition rejected'

say 'PASS 3270 PARTITION IO'
exit 0
assert: procedure
  use arg ok,msg
  if \ok then do; say 'FAIL' msg; exit 1; end
  return
::requires "DataStream3270.cls"
