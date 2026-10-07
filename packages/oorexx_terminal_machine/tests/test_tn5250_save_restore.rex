failures = 0
cp = .CodePage037~new
runtime = .TN5250RuntimeSession~new("SAVE-RESTORE")
auto = runtime~automationPort

/* Build a small screen with one ordinary and one nondisplay input field. */
wtd = "0411"x || "0008"x ||,
      "11"x || d2c(3) || d2c(5) || cp~encode("SAVE TEST") ||,
      "11"x || d2c(8) || d2c(10) || "1D4000200008"x ||,
      "11"x || d2c(9) || d2c(10) || "1D4000270008"x ||,
      "13"x || d2c(8) || d2c(10)
host = .TN5250RecordCodec~encode(.TN5250Opcode~OUTPUT_ONLY, wtd)
call assertTrue runtime~feedNetwork(.TN5250RecordCodec~telnetFrame(host~value))~ok, "initial WTD"
g = auto~snapshot~generation
call assertTrue auto~setField(g, "F0571", "USERA")~ok, "set ordinary field"
call assertTrue auto~setField(g, "F0651", "S3CRET")~ok, "set nondisplay field"
call assertEq auto~snapshot~field("F0651")~value, "<SECRET>", "secret hidden before save"

/* Save Screen request is opcode 04 with workstation command ESC 02.  The wire
 * image is intentionally opaque and must not contain the nondisplay bytes. */
saveReq = .TN5250RecordCodec~encode(.TN5250Opcode~SAVE_SCREEN, "0402"x)
saved = runtime~feedNetwork(.TN5250RecordCodec~telnetFrame(saveReq~value))
call assertTrue saved~ok, "SAVE request"
call assertTrue saved~value~outboundBytes~length > 0, "SAVE response emitted"
call assertTrue pos(cp~encode("S3CRET"), saved~value~outboundBytes) = 0, "secret absent from opaque SAVE wire image"

peer = .TelnetMachine~new(.TN5250TelnetProfile~new)
peer~feed(saved~value~outboundBytes)
ev = peer~drainEvents
call assertEq ev~items, 1, "one SAVE response record"
saveRecord = .TN5250RecordCodec~decode(ev[1]~data)
call assertTrue saveRecord~ok, "SAVE response decodes"
call assertEq saveRecord~value~opcode~c2x, "04", "SAVE response opcode"
call assertEq saveRecord~value~payload~left(6)~c2x, "04124F525831", "RESTORE prefix + ORX1 opaque image"

/* Change both fields after the save. */
call assertTrue auto~setField(g, "F0571", "USERB")~ok, "mutate ordinary field"
call assertTrue auto~setField(g, "F0651", "WRONG")~ok, "mutate secret field"

restoreReq = .TN5250RecordCodec~encode(.TN5250Opcode~RESTORE_SCREEN, saveRecord~value~payload)
restored = runtime~feedNetwork(.TN5250RecordCodec~telnetFrame(restoreReq~value))
call assertTrue restored~ok, "RESTORE request"
s = auto~snapshot
call assertEq s~field("F0571")~value~strip, "USERA", "ordinary field restored"
call assertEq s~field("F0651")~value, "<SECRET>", "restored secret remains hidden"
call assertTrue pos("S3CRET", s~visibleText) = 0, "restored WatchAlong/snapshot has no secret"

/* Prove that the trusted private save actually restored the secret, not merely
 * the redacted display: issue READ MDT and press Enter, then inspect wire only. */
readReq = .TN5250RecordCodec~encode(.TN5250Opcode~INVITE, "04520000"x)
call assertTrue runtime~feedNetwork(.TN5250RecordCodec~telnetFrame(readReq~value))~ok, "READ MDT after restore"
g2 = auto~snapshot~generation
act = auto~press(g2, "ENTER")
call assertTrue act~ok, "Enter after restore"
wire = runtime~drainTerminalOutput
call assertTrue wire~ok, "trusted restored input output"
call assertTrue pos(cp~encode("S3CRET"), wire~value) > 0, "original secret restored only on trusted wire"
call assertTrue pos(cp~encode("WRONG"), wire~value) = 0, "post-save mutation was undone"

if failures > 0 then do
  say "FAIL test_tn5250_save_restore" failures
  exit 1
end
say "PASS test_tn5250_save_restore"
exit 0

assertEq: procedure expose failures
  use arg actual, expected, label
  if actual == expected then return
  failures += 1
  say "ASSERT_EQ FAIL:" label "expected="expected "actual="actual
  return
assertTrue: procedure expose failures
  use arg condition, label
  if condition then return
  failures += 1
  say "ASSERT_TRUE FAIL:" label
  return

::requires "TN5250Automation.cls"
