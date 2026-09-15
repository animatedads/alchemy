/* FlyLo structured-runtime compatibility probe.
 * This runs behind ./flylo; users/Codex do not start it separately. */
signal on syntax name failed
d = .directory~new
d["ok"] = .JSON~true
encoded = .JSON~toJSON(d)
if encoded~pos('"ok":true') = 0 then exit 3
parsed = .JSON~fromJSON('{"flag":true,"text":"ok"}')
if parsed == .nil | \parsed~isa(.Directory) then exit 4
flag = parsed["flag"]
if flag == .nil then exit 5
if \selfTestTruth(flag) then exit 6
say "FLYLO_RUNTIME_PROBE_OK"
exit 0

selfTestTruth: procedure
  use arg valueArg
  if valueArg == .nil then return .false
  if valueArg~hasMethod("VALUE") then do
    logicalValue = valueArg~value
    if logicalValue == .true then return .true
    if logicalValue == .false then return .false
  end
  text = translate(strip(valueArg~string))
  return text = "TRUE" | text = "1" | text = "YES"

failed:
  signal off syntax
  exit 7

::requires "json.cls"
