call test
exit 0
test: procedure
  trace=.CliUiSemanticTrace~new
  r=.CliUiHeadlessRenderer~new(24,80)
  ev=r~resize(40,120); trace~record(ev,"viewport")
  r~beginFrame~drawText(1,1,"NewShell","status")~setCursor(2,1); r~endFrame
  if r~rows<>40 | r~cols<>120 then raise syntax 88.900 array("resize failed")
  if r~cell(1,1)<>"status:NewShell" then raise syntax 88.900 array("draw failed")
  doc=.CliUiDocument~new("one"||"0a"x||"two"||"0a"x||"three","plain")
  doc~setCaret(2); doc~moveLine(1,.true); sel=doc~selection
  if sel[2]<=sel[1] then raise syntax 88.900 array("shift selection failed")
  trace~record(.CliUiSemanticEvent~new("SelectionChanged","editor","document","range",sel[1]||":"||sel[2]),"selection")
  if trace~entries~items<>2 then raise syntax 88.900 array("trace failed")
  say "PASS semantic trace headless resize shift-selection"
  return
::requires "CliUiDocument.cls"
::requires "CliUiSemantic.cls"
::requires "CliUiHeadlessRenderer.cls"
