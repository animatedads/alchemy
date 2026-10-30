call directory rxqueue
here = filespec("location", sourceLine(1))
root = filespec("drive", here) || filespec("path", here) || ".."
tmp = value("TMPDIR",, "ENVIRONMENT")
if tmp == "" then tmp = "/tmp"
dir = tmp || "/mvs-intention-dev10-pre23"
address system "rm -rf" dir
address system "mkdir -p" dir

call lineout dir || "/mvs_alchemy.tsv", "PROBE"||"09"x||"JES_JOB_CATALOG"||"09"x||"PRE23 completion gate fixture"
call lineout dir || "/mvs_alchemy.tsv", "FACT"||"09"x||"SYSTEM"||"09"x||"NAME"||"09"x||"ED209Z"||"09"x||"100"||"09"x||"fixture"
call lineout dir || "/mvs_alchemy.tsv", "FACT"||"09"x||"JES"||"09"x||"STATE"||"09"x||"READY"||"09"x||"100"||"09"x||"fixture"
call lineout dir || "/mvs_alchemy.tsv", "FACT"||"09"x||"JOB.JOB00077"||"09"x||"ROW"||"09"x||"JOB00077|MASLIVE|HERC01|RUN|ENDED|CC 0000|2026-10-27T16:00:00|"||"09"x||"100"||"09"x||"fixture"
call lineout dir || "/mvs_alchemy.tsv", "FACT"||"09"x||"JOB.JOB00077"||"09"x||"JES_ACCEPTED"||"09"x||"TRUE"||"09"x||"100"||"09"x||"HASP100"
call lineout dir || "/mvs_alchemy.tsv", "FACT"||"09"x||"JOB.JOB00077"||"09"x||"JES_STARTED"||"09"x||"TRUE"||"09"x||"100"||"09"x||"HASP373"
call lineout dir || "/mvs_alchemy.tsv", "FACT"||"09"x||"JOB.JOB00077"||"09"x||"FACILITY_PASS"||"09"x||"TRUE"||"09"x||"100"||"09"x||"MASLIVE PASS ALL"
call lineout dir || "/mvs_alchemy.tsv", "FACT"||"09"x||"JOB.JOB00077"||"09"x||"JES_ENDED"||"09"x||"FALSE"||"09"x||"100"||"09"x||"no HASP395"
call lineout dir || "/mvs_alchemy.tsv", "FACT"||"09"x||"JOB.JOB00077"||"09"x||"SPOOL_RETAINED"||"09"x||"FALSE"||"09"x||"100"||"09"x||"no final spool"
call stream dir || "/mvs_alchemy.tsv", "c", "close"
call lineout dir || "/terminal_machine.tsv", "PROBE"||"09"x||"SCREEN_STATE"||"09"x||"fixture"
call stream dir || "/terminal_machine.tsv", "c", "close"
call lineout dir || "/hercules_services.tsv", "PROBE"||"09"x||"GUEST_STATE"||"09"x||"fixture"
call stream dir || "/hercules_services.tsv", "c", "close"

backend=.MvsDiscoveryDirectoryBackend~new(dir)
snap=backend~discover("ED209Z")
job=snap~job("JOB00077")
call assert job<>.nil, "job discovered"
call assert job~outcome=="INCOMPLETE", "facility PASS before HASP395/spool is incomplete"

call lineout dir || "/mvs_alchemy.tsv", "PROBE"||"09"x||"JES_JOB_CATALOG"||"09"x||"PRE23 completed fixture"
call lineout dir || "/mvs_alchemy.tsv", "FACT"||"09"x||"SYSTEM"||"09"x||"NAME"||"09"x||"ED209Z"||"09"x||"100"||"09"x||"fixture"
call lineout dir || "/mvs_alchemy.tsv", "FACT"||"09"x||"JES"||"09"x||"STATE"||"09"x||"READY"||"09"x||"100"||"09"x||"fixture"
call lineout dir || "/mvs_alchemy.tsv", "FACT"||"09"x||"JOB.JOB00077"||"09"x||"ROW"||"09"x||"JOB00077|MASLIVE|HERC01|RUN|ENDED|CC 0000|2026-10-27T16:00:00|"||"09"x||"100"||"09"x||"fixture"
call lineout dir || "/mvs_alchemy.tsv", "FACT"||"09"x||"JOB.JOB00077"||"09"x||"JES_ACCEPTED"||"09"x||"TRUE"||"09"x||"100"||"09"x||"HASP100"
call lineout dir || "/mvs_alchemy.tsv", "FACT"||"09"x||"JOB.JOB00077"||"09"x||"JES_STARTED"||"09"x||"TRUE"||"09"x||"100"||"09"x||"HASP373"
call lineout dir || "/mvs_alchemy.tsv", "FACT"||"09"x||"JOB.JOB00077"||"09"x||"FACILITY_PASS"||"09"x||"TRUE"||"09"x||"100"||"09"x||"MASLIVE PASS ALL"
call lineout dir || "/mvs_alchemy.tsv", "FACT"||"09"x||"JOB.JOB00077"||"09"x||"JES_ENDED"||"09"x||"TRUE"||"09"x||"100"||"09"x||"HASP395"
call lineout dir || "/mvs_alchemy.tsv", "FACT"||"09"x||"JOB.JOB00077"||"09"x||"SPOOL_RETAINED"||"09"x||"TRUE"||"09"x||"100"||"09"x||"final spool"
call stream dir || "/mvs_alchemy.tsv", "c", "close"

snap=backend~discover("ED209Z")
job=snap~job("JOB00077")
call assert job~outcome=="SUCCESS", "HASP395 plus retained spool permits success"
say "PASS MAS PRE23 JES completion gate"
exit 0

assert: procedure
  use arg ok,label
  if \ok then do
    say "FAIL" label
    exit 1
  end
  return

::requires "MvsIntention.cls"
