feedDir = "/tmp/mvs-intention-reference-tso-test"
address system "rm -rf" feedDir
address system "mkdir -p" feedDir
p = feedDir || "/reference_tso_x3270.tsv"
call lineout p, "PROBE" || "09"x || "LOGON_TEST_IDENTITY" || "09"x || "credential omitted"
call lineout p, "FACT" || "09"x || "SESSION" || "09"x || "AUTHENTICATED" || "09"x || "TRUE" || "09"x || "100" || "09"x || "x3270:tso-auth"
call lineout p, "FACT" || "09"x || "SESSION" || "09"x || "TARGET" || "09"x || "ED209Z" || "09"x || "100" || "09"x || "x3270:tso-session"
call lineout p, "FACT" || "09"x || "SESSION" || "09"x || "HOST" || "09"x || "52.146.17.8" || "09"x || "100" || "09"x || "x3270:tso-session"
call lineout p, "FACT" || "09"x || "SESSION" || "09"x || "LU" || "09"x || "00C0" || "09"x || "100" || "09"x || "x3270:tso-session"
call lineout p, "FACT" || "09"x || "TSO" || "09"x || "USER" || "09"x || "HERC03" || "09"x || "100" || "09"x || "x3270:tso-user"
call lineout p, "FACT" || "09"x || "DATASET.HERC03.CLIST" || "09"x || "ROW" || "09"x || "HERC03.CLIST|UNKNOWN|FALSE" || "09"x || "95" || "09"x || "x3270:listcat"
call stream p, "c", "close"

backend = .MvsDiscoveryDirectoryBackend~new(feedDir)
s = backend~discover("ED209Z")
call assert s~factsBySource("REFERENCE_TSO_X3270")~items == 6, "authenticated reference facts retain their provenance"
call assert s~tsoUser == "HERC03", "reference TSO user is projected"
call assert s~datasets~items == 1, "LISTCAT dataset is projected"
call assert s~capability("REFERENCE_TSO_TARGET") == "ED209Z", "target provenance retained"
call assert s~capability("REFERENCE_TSO_HOST") == "52.146.17.8", "host provenance retained"
call assert s~capability("REFERENCE_TSO_LU") == "00C0", "LU provenance retained"
runner = .MvsIntentionRunner~new("ED209Z", backend)
d = runner~input("show my datasets")
call assert d~status == "READY", "dataset intention can use directly observed LISTCAT evidence"
call assert pos("HERC03.CLIST", runner~render(d)) > 0, "render includes observed dataset"
d = runner~input("show jobs")
call assert d~status \== "READY", "authenticated TSO does not invent JES evidence"
d = runner~input("what system am I on")
call assert d~status \== "READY", "authenticated TSO does not invent MVS system identity"

address system "rm -rf" feedDir
say "PASS authenticated reference TSO evidence remains bounded"
exit 0
assert: procedure
  use arg condition, message
  if condition then return
  say "FAIL" message
  exit 1
::requires "MvsIntention.cls"
