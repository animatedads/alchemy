call testSnapshot
say "PASS 3270 SNAPSHOT"
exit 0

testSnapshot:
  model=.PresentationSpace3270~new(24,80)
  stream=.DataStream3270~new(model)
  cp=stream~codepage

  /* protected label, ordinary input field, NONDISPLAY input field */
  record=.Command3270~ERASE_WRITE || "02"x || -
         .Order3270~SBA || .Address3270~encode(0) || .Order3270~SF || "20"x || cp~encode("Logon ===>") || -
         .Order3270~SBA || .Address3270~encode(90) || .Order3270~SF || "00"x || cp~encode("FRED") || -
         .Order3270~SBA || .Address3270~encode(170) || .Order3270~SF || "0C"x || cp~encode("SECRET") || .Order3270~IC
  r=stream~applyHostRecord(record)
  call assert r~ok, "host record"

  profile=.TN3270TelnetProfile~new
  wire=.TN3270Wire~new(stream,profile)
  projected=.TN3270Snapshot~fromWire(wire)
  call assert projected~ok, "projection result"
  s=projected~value
  call assert s~generation=1, "generation"
  call assert s~rows=24 & s~columns=80, "dimensions"
  call assert s~capabilities~has("IBM_3270"), "3270 capability"
  call assert s~fields~items=3, "field count"
  f=s~field("A00AA")
  call assert f \== .nil, "secret field id"
  call assert f~nonDisplay, "secret nondisplay"
  call assert f~value="<SECRET>", "secret masked"
  call assert s~visibleText~pos("SECRET")=0, "secret absent from visible text"
  call assert s~visibleText~pos("Logon ===>")>0, "visible logon prompt"
  call assert s~layoutFingerprint<>"", "layout fingerprint"
  call assert s~contentDigest<>"", "content digest"
  return

assert: procedure
  use arg ok,msg
  if ok then return
  say "FAIL 3270 SNAPSHOT:" msg
  exit 1

::requires "TN3270Snapshot.cls"
::requires "TN3270Wire.cls"
