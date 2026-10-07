call rxfuncadd 'SysLoadFuncs','RexxUtil','SysLoadFuncs'; call SysLoadFuncs
m=.PresentationSpace3270~new; d=.DataStream3270~new(m); cp=d~codepage

/* SFE creates a real field and retains extended field attributes. */
rec=.Command3270~ERASE_WRITE||"02"x||,
    .Order3270~SBA||.Address3270~encode(80)||,
    .Order3270~SFE||"03"x||,
      .Attribute3270~BASIC_FIELD||"00"x||,
      .Attribute3270~HIGHLIGHT||"F2"x||,
      .Attribute3270~FOREGROUND||"F1"x||,
    cp~encode("ABC")
r=d~applyHostRecord(rec); call assert r~ok,'SFE host record'
f=m~fieldStartingAt(80); call assert f<>.nil,'SFE field created'
call assert f~attribute=="00"x,'SFE basic field attribute'
call assert f~extendedAttribute(.Attribute3270~HIGHLIGHT)=="F2"x,'SFE highlighting retained'
call assert f~extendedAttribute(.Attribute3270~FOREGROUND)=="F1"x,'SFE foreground retained'
call assert m~fieldText(f,cp)~left(3)=="ABC",'SFE text retained'

/* SA affects following characters, and reset-all terminates the run. */
rec2=.Command3270~WRITE||"02"x||,
     .Order3270~SBA||.Address3270~encode(100)||,
     .Order3270~SA||.Attribute3270~HIGHLIGHT||"F1"x||cp~encode("HI")||,
     .Order3270~SA||.Attribute3270~RESET_ALL||"00"x||cp~encode("X")
r=d~applyHostRecord(rec2); call assert r~ok,'SA host record'
a100=m~characterAttributesAt(100); a101=m~characterAttributesAt(101); a102=m~characterAttributesAt(102)
call assert a100~at(.Attribute3270~HIGHLIGHT~c2x)=="F1"x,'SA first char'
call assert a101~at(.Attribute3270~HIGHLIGHT~c2x)=="F1"x,'SA run continues'
call assert a102~items==0,'SA reset all'

/* MF updates both basic and extended attributes at the selected field address. */
rec3=.Command3270~WRITE||"02"x||,
     .Order3270~SBA||.Address3270~encode(80)||,
     .Order3270~MF||"02"x||,
       .Attribute3270~BASIC_FIELD||"20"x||,
       .Attribute3270~FOREGROUND||"F2"x
r=d~applyHostRecord(rec3); call assert r~ok,'MF host record'
call assert f~protected,'MF basic attribute applied'
call assert f~extendedAttribute(.Attribute3270~FOREGROUND)=="F2"x,'MF extended attribute applied'

/* READ BUFFER reconstructs SFE and character SA orders rather than flattening style. */
rb=d~buildReadBuffer(.Aid3270~NO_AID)
expectedSfe=.Order3270~SFE||"03"x||.Attribute3270~BASIC_FIELD||"20"x||.Attribute3270~HIGHLIGHT||"F2"x||.Attribute3270~FOREGROUND||"F2"x
call assert rb~pos(expectedSfe)>0,'READ BUFFER SFE reconstruction'
call assert rb~pos(.Order3270~SA||.Attribute3270~HIGHLIGHT||"F1"x)>0,'READ BUFFER SA reconstruction'
call assert rb~pos(.Order3270~SA||.Attribute3270~RESET_ALL||"00"x)>0,'READ BUFFER SA reset reconstruction'

/* Truncated extended orders and MF against a data byte fail closed. */
call assertCode d~applyHostRecord(.Command3270~WRITE||"02"x||.Order3270~SFE||"02"x||.Attribute3270~BASIC_FIELD||"00"x),'3270_TRUNCATED_SFE_ATTRIBUTES','truncated SFE'
call assertCode d~applyHostRecord(.Command3270~WRITE||"02"x||.Order3270~SA||.Attribute3270~HIGHLIGHT),'3270_TRUNCATED_SA','truncated SA'
call assertCode d~applyHostRecord(.Command3270~WRITE||"02"x||.Order3270~MF||"01"x||.Attribute3270~FOREGROUND),'3270_TRUNCATED_MF_ATTRIBUTES','truncated MF'
call assertCode d~applyHostRecord(.Command3270~WRITE||"02"x||.Order3270~SBA||.Address3270~encode(90)||.Order3270~MF||"01"x||.Attribute3270~FOREGROUND||"F1"x),'3270_MF_NOT_FIELD_ATTRIBUTE','MF requires field address'

say 'PASS 3270 EXTENDED ATTRIBUTES'
exit 0

assert: procedure
  use arg ok,msg
  if \ok then do; say 'FAIL' msg; exit 1; end
  return
assertCode: procedure
  use arg result,code,msg
  if result~ok | result~code<>code then do; say 'FAIL' msg 'expected='code 'actual='result~code; exit 1; end
  return
::requires "DataStream3270.cls"
