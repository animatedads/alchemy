feedDir = "/tmp/mvs-intention-evidence-gates"
address system "rm -rf" feedDir
address system "mkdir -p" feedDir
p = feedDir || "/reference_x3270.tsv"
call lineout p, "PROBE" || "09"x || "CONNECT_3270" || "09"x || "safe reference connect"
call lineout p, "FACT" || "09"x || "SESSION" || "09"x || "STATE" || "09"x || "CONNECTED" || "09"x || "100" || "09"x || "x3270:00C0"
call lineout p, "FACT" || "09"x || "SCREEN" || "09"x || "CLASS" || "09"x || "TSO_LOGON" || "09"x || "100" || "09"x || "x3270:screen"
call stream p, "c", "close"

runner = .MvsIntentionRunner~new("ED209Z", .MvsDiscoveryDirectoryBackend~new(feedDir))
call notReady runner, "what system am I on", "system identity requires MVS evidence"
call notReady runner, "show jobs", "job listing requires JES evidence"
call notReady runner, "show datasets", "dataset listing requires discovered dataset evidence"
d = runner~input("what can I see")
call assert d~status == "READY", "scope discovery remains READY from safe terminal evidence"
call assert pos("terminal=TSO_LOGON", runner~render(d)) > 0, "scope includes observed TSO logon state"

address system "rm -rf" feedDir
say "PASS false READY is blocked when MVS/JES evidence is absent"
exit 0

notReady: procedure
  use arg runner, utterance, message
  d = runner~input(utterance)
  if d~status == "READY" then do
    say "FAIL" message
    exit 1
  end
return
assert: procedure
  use arg condition, message
  if condition then return
  say "FAIL" message
  exit 1
::requires "MvsIntention.cls"
