feedDir = "/tmp/mvs-intention-reference-x3270-test"
address system "rm -rf" feedDir
address system "mkdir -p" feedDir

/* Leave ordinary authority feeds absent on purpose.  Only the reference
 * terminal feed is present, proving it is retained under its own provenance. */
p = feedDir || "/reference_x3270.tsv"
call lineout p, "PROBE" || "09"x || "CONNECT_3270" || "09"x || "safe reference connect"
call lineout p, "FACT" || "09"x || "SESSION" || "09"x || "STATE" || "09"x || "CONNECTED" || "09"x || "100" || "09"x || "x3270:00C0"
call lineout p, "FACT" || "09"x || "SCREEN" || "09"x || "CLASS" || "09"x || "TSO_LOGON" || "09"x || "100" || "09"x || "x3270:screen"
call stream p, "c", "close"

backend = .MvsDiscoveryDirectoryBackend~new(feedDir)
s = backend~discover("ED209Z")
call assert s~factsBySource("REFERENCE_X3270")~items == 2, "reference facts retain REFERENCE_X3270 provenance"
tm = s~factsBySource("TERMINAL_MACHINE")
call assert tm~items == 1, "missing Terminal Machine produces only its unavailable fact"
call assert tm~at(1)~subject == "SOURCE", "reference facts are not relabelled Terminal Machine"
call assert s~terminalState == "TSO_LOGON", "reference screen can fill otherwise unknown terminal scope"
call assert s~capability("REFERENCE_X3270_SCREEN") == "TSO_LOGON", "reference screen class retained"

address system "rm -rf" feedDir
say "PASS reference x3270 evidence remains independently authoritative"
exit 0

assert: procedure
  use arg condition, message
  if condition then return
  say "FAIL" message
  exit 1

::requires "MvsIntention.cls"
