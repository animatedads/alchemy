call assertEqual .QueueShellQuoteCodec~decodeScalar("hello\ world"), "hello world", "backslash scalar"
call assertEqual .QueueShellQuoteCodec~decodeScalar("$'tab\tval'"), "tab" || "09"x || "val", "ansi c scalar"
r = .QueueRecord~new("fixtures/root/pending/p0999999990/example.job", "pending")
call assertEqual r~qid, "example", "qid"
call assertEqual r~name, "hello world", "name"
call assertEqual r~priority, 10, "priority"
call assertEqual r~field("UNKNOWN_FUTURE_FIELD"), "future value", "unknown field preserved for read"
call assertEqual r~commandLine, "/bin/echo a\ b semi\;colon $'tab\tval'", "raw compatible command line"
a = r~arrayField("COMMAND")
call assertEqual a~items, 4, "command argc"
call assertEqual a[2], "a b", "decoded argv space"
call assertEqual a[3], "semi;colon", "decoded argv semicolon"
call assertEqual a[4], "tab" || "09"x || "val", "decoded argv tab"
store = .QueueStateStore~new("fixtures/root")
call assertEqual store~records("pending")~items, 1, "pending scan"
/* Missing COMMAND is a legal damaged/incomplete record for inspection. */
missingPath = testDir || "/missing-command.job"
call lineout missingPath, "JOB_ID=missing"
call lineout missingPath
r2 = .QueueRecord~new(missingPath, "pending")
if r2~commandLine \= "" then do; say "FAIL missing command"; exit 1; end

say "PASS test_core"
exit 0

assertEqual:
  use arg actual, expected, label
  if actual \== expected then do
    say "FAIL" label "expected=" expected "actual=" actual
    exit 1
  end
  return

::requires "../src/QueueRexxCore.cls"
