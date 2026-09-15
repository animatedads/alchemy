doc = .EdiFactDocumentContext~new("fixtures/ourladyair_pnrgov_demo.edi")
call assert doc~segments~items = 187, "all EDIFACT segments retained"
call assert doc~messages~items = 16, "all UNH messages retained including deliberately bad outer message"
call assert doc~groups~items = 7, "seven UNG functional groups"
call assert doc~annotations~items = 17, "seventeen source annotations retained"
call assert doc~select("SEGMENT:SSR")~count = 28, "SSR count"
call assert doc~select("SEGMENT:TIF")~count = 25, "passenger count"
call assert doc~select("SEGMENT:TKT")~count = 25, "ticket count"
expected = .array~of("G01","G02","G03","G04","G05","G06","G07")
do i=1 to expected~items
  call assert doc~groups[i]~reference = expected[i], "functional group order/reference"
end
report=doc~validateEnvelope
call assert report~status = "INVALID", "deliberately malformed demo envelope reported invalid"
call assert report~findings~items = 17, "all deliberate envelope/count defects retained"
call assert hasCode(report~findings, "EDIFACT.MESSAGE.UNT.MISSING"), "outer UNH missing UNT surfaced"
call assert hasCode(report~findings, "EDIFACT.INTERCHANGE.MESSAGE_COUNT"), "UNZ grouped control count mismatch surfaced"
say "OURLADYAIR PNRGOV SOURCE SMOKE: OK"
exit 0

hasCode: procedure
  use arg findings, wanted
  do f over findings
    if f~code = wanted then return .true
  end
  return .false

assert: procedure
  use arg condition, message
  if condition then return
  say "ASSERTION FAILED:" message
  exit 1

::requires "../src/EdiFactNativeSource.cls"
