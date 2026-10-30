call testParser
call testActionEnvelope
call testDifferential
call testAttributeMasks
call testExtendedAttributeDifferential
call testRowWidthGuards
say "PASS S3270 REFERENCE DIFFERENTIAL"
exit 0

testParser:
  dump="data: SF(c0=20) 54 53 4F 20 20 20 20"||"0a"x||,
       "data: SF(c0=01) 41 42 00 20 SF(c0=2c) 53 45"
  p=.S3270ReferenceParser~parse(dump,2,8,1,3)
  call assert p~ok,"parse"
  s=p~value
  call assertEq s~rows,2,"rows"
  call assertEq s~columns,8,"columns"
  call assertEq s~cursorRow,2,"cursor row"
  call assertEq s~cursorColumn,4,"cursor col"
  call assertEq s~keyboardState,"UNKNOWN","plain-buffer keyboard unknown"
  call assertEq s~fields~items,3,"field count"
  call assert s~fields[1]~protected,"field1 protected"
  call assert s~fields[2]~modified,"field2 MDT"
  call assert s~fields[3]~nonDisplay,"field3 nondisplay"
  call assertEq s~rowText(1)~substr(2,3),"TSO","visible row"
  call assert pos("SE",s~rowText(2))==0,"nondisplay masked"
  return

testActionEnvelope:
  data="data: SF(c0=20) 54 53 4F 20 20 20 20"||"0a"x||,
       "data: SF(c0=01) 41 42 20 20 SF(c0=2C) 53 45"||"0a"x
  response=data||"U F U C(ed209z) I 2 2 8 1 3 0 0.004"||"0a"x||"ok"||"0a"x
  p=.S3270ReferenceParser~parseActionResponse(response)
  call assert p~ok,"action response"
  s=p~value
  call assertEq s~keyboardState,"UNLOCKED","keyboard state"
  call assertEq s~rows,2,"status rows"
  call assertEq s~columns,8,"status columns"
  call assertEq s~cursorRow,2,"status cursor row"
  call assertEq s~cursorColumn,4,"status cursor col"
  call assert s~status~formatted,"formatted status"
  call assertEq s~status~emulatorMode,"I","3270 mode"
  bad=data||"L F U C(ed209z) I 2 2 8 0 0 0 0.001"||"0a"x||"error"||"0a"x
  b=.S3270ReferenceParser~parseActionResponse(bad)
  call assert \b~ok & b~code=="S3270_ACTION_ERROR","error completion"
  return

testDifferential:
  model=.PresentationSpace3270~new(2,8)
  stream=.DataStream3270~new(model)
  cp=stream~codepage
  rec=.Command3270~ERASE_WRITE||"02"x||,
      .Order3270~SBA||.Address3270~encode(0)||.Order3270~SF||"20"x||cp~encode("TSO    ")||,
      .Order3270~SBA||.Address3270~encode(8)||.Order3270~SF||"01"x||cp~encode("AB  ")||,
      .Order3270~SBA||.Address3270~encode(13)||.Order3270~SF||"2c"x||cp~encode("SE")
  a=stream~applyHostRecord(rec); call assert a~ok,"host record"
  model~cursor=11
  projected=.TN3270Snapshot~fromModel(model,cp); call assert projected~ok,"terminal snapshot"
  data="data: SF(c0=20) 54 53 4F 20 20 20 20"||"0a"x||,
       "data: SF(c0=01) 41 42 20 20 SF(c0=2C) 53 45"||"0a"x
  response=data||"U F U C(ed209z) I 2 2 8 1 3 0 0.004"||"0a"x||"ok"||"0a"x
  ref=.S3270ReferenceParser~parseActionResponse(response); call assert ref~ok,"reference snapshot"
  d=.S3270Differential~compare(projected~value,ref~value)
  call assert d~equivalent,"equivalent fixture: "||join(d~mismatches)
  locked=data||"L F U C(ed209z) I 2 2 8 1 3 0 0.004"||"0a"x||"ok"||"0a"x
  l=.S3270ReferenceParser~parseActionResponse(locked); call assert l~ok,"locked reference"
  d2=.S3270Differential~compare(projected~value,l~value)
  call assert \d2~equivalent,"keyboard mismatch detected"
  return

testAttributeMasks:
  attrs=.array~of("00","20","10","01","2C","31")
  wantProtected=.array~of(0,1,0,0,1,1)
  wantNumeric=.array~of(0,0,1,0,0,1)
  wantModified=.array~of(0,0,0,1,0,1)
  wantSecret=.array~of(0,0,0,0,1,0)
  do i=1 to attrs~items
    f=.S3270ReferenceField~new(0,1,1,1,attrs[i])
    call assertEq f~protected,wantProtected[i]==1,"protected "||attrs[i]
    call assertEq f~numeric,wantNumeric[i]==1,"numeric "||attrs[i]
    call assertEq f~modified,wantModified[i]==1,"modified "||attrs[i]
    call assertEq f~nonDisplay,wantSecret[i]==1,"nondisplay "||attrs[i]
  end
  return

testExtendedAttributeDifferential:
  model=.PresentationSpace3270~new(2,8)
  stream=.DataStream3270~new(model)
  cp=stream~codepage
  rec=.Command3270~ERASE_WRITE||"02"x||,
      .Order3270~SBA||.Address3270~encode(0)||,
      .Order3270~SFE||"03"x||,
        .Attribute3270~BASIC_FIELD||"20"x||,
        .Attribute3270~HIGHLIGHT||"F2"x||,
        .Attribute3270~FOREGROUND||"F1"x||,
      cp~encode("ABC")||,
      .Order3270~SA||.Attribute3270~HIGHLIGHT||"F1"x||cp~encode("HI")||,
      .Order3270~SA||.Attribute3270~RESET_ALL||"00"x||cp~encode("X ")||,
      .Order3270~SBA||.Address3270~encode(8)||.Order3270~SF||"00"x||cp~encode("       ")
  a=stream~applyHostRecord(rec); call assert a~ok,"extended host record"
  projected=.TN3270Snapshot~fromModel(model,cp); call assert projected~ok,"extended terminal snapshot"
  data="data: SF(c0=20,41=f2,42=f1) 41 42 43 SA(41=f1) 48 49 SA(00=00) 58 20"||"0a"x||,
       "data: SF(c0=00) 20 20 20 20 20 20 20"||"0a"x
  response=data||"U F U C(ed209z) I 2 2 8 0 0 0 0.004"||"0a"x||"ok"||"0a"x
  ref=.S3270ReferenceParser~parseActionResponse(response); call assert ref~ok,"extended reference snapshot"
  f=ref~value~fields[1]
  call assertEq f~attributes~at("x41"),"F2","reference field highlight"
  call assertEq f~attributes~at("x42"),"F1","reference field foreground"
  d=.S3270Differential~compare(projected~value,ref~value)
  call assert d~equivalent,"extended equivalent fixture: "||join(d~mismatches)

  badField=data~changestr("42=f1","42=f2")
  badResponse=badField||"U F U C(ed209z) I 2 2 8 0 0 0 0.004"||"0a"x||"ok"||"0a"x
  bad=.S3270ReferenceParser~parseActionResponse(badResponse); call assert bad~ok,"bad field reference parse"
  mismatch=.S3270Differential~compare(projected~value,bad~value)
  call assert \mismatch~equivalent,"field extended attribute mismatch detected"

  badChar=data~changestr("SA(41=f1)","SA(41=f2)")
  badResponse=badChar||"U F U C(ed209z) I 2 2 8 0 0 0 0.004"||"0a"x||"ok"||"0a"x
  bad=.S3270ReferenceParser~parseActionResponse(badResponse); call assert bad~ok,"bad character reference parse"
  mismatch=.S3270Differential~compare(projected~value,bad~value)
  call assert \mismatch~equivalent,"character attribute mismatch detected"
  return


testRowWidthGuards:
  over="data: SF(c0=20) 54 53 4F 20 20 20 20 20"||"0a"x||,
       "data: SF(c0=01) 41 42 20 20 SF(c0=2C) 53 45"
  r=.S3270ReferenceParser~parse(over,2,8,0,0)
  call assert \r~ok & r~code=="S3270_ROW_WIDTH", "overfilled row rejected"
  under="data: SF(c0=20) 54 53 4F 20 20 20"||"0a"x||,
        "data: SF(c0=01) 41 42 20 20 SF(c0=2C) 53 45"
  r=.S3270ReferenceParser~parse(under,2,8,0,0)
  call assert \r~ok & r~code=="S3270_ROW_WIDTH", "underfilled row rejected"
  return

join: procedure
  use arg a
  s=""
  do x over a
    if s<>"" then s||=","; s||=x
  end
  return s

assertEq: procedure
  use arg got,want,msg
  if got==want then return
  say "FAIL S3270 REFERENCE:" msg "got="got "want="want
  exit 1
assert: procedure
  use arg ok,msg
  if ok then return
  say "FAIL S3270 REFERENCE:" msg
  exit 1

::requires "S3270Reference.cls"
::requires "TN3270Snapshot.cls"
