call testParser
call testDifferential
say "PASS S3270 REFERENCE DIFFERENTIAL"
exit 0

testParser:
  dump="data: SF(c0=20) 54 53 4F 20 20 20 20 20"||"0a"x||,
       "data: SF(c0=01) 41 42 00 20 SF(c0=2c) 53 45"
  p=.S3270ReferenceParser~parse(dump,2,8,1,3)
  call assert p~ok,"parse"
  s=p~value
  call assertEq s~rows,2,"rows"
  call assertEq s~columns,8,"columns"
  call assertEq s~cursorRow,2,"cursor row"
  call assertEq s~cursorColumn,4,"cursor col"
  call assertEq s~fields~items,3,"field count"
  call assert s~fields[1]~protected,"field1 protected"
  call assert s~fields[2]~modified,"field2 MDT"
  call assert s~fields[3]~nonDisplay,"field3 nondisplay"
  call assertEq s~rowText(1)~substr(2,3),"TSO","visible row"
  call assert pos("SE",s~rowText(2))==0,"nondisplay masked"
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
  dump="data: SF(c0=20) 54 53 4F 20 20 20 20 20"||"0a"x||,
       "data: SF(c0=01) 41 42 20 20 SF(c0=2C) 53 45"
  ref=.S3270ReferenceParser~parse(dump,2,8,1,3); call assert ref~ok,"reference snapshot"
  d=.S3270Differential~compare(projected~value,ref~value)
  call assert d~equivalent,"equivalent fixture: "||join(d~mismatches)
  bad=.S3270ReferenceParser~parse(dump,2,8,0,0)
  d2=.S3270Differential~compare(projected~value,bad~value)
  call assert \d2~equivalent,"cursor mismatch detected"
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
