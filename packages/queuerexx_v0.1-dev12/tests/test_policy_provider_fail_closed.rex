root = "/mnt/data/queuerexx-dev11-policy-failclosed"
address system "rm -rf " || root
call SysMkDir root
call SysMkDir root || "/running"
call SysMkDir root || "/logs"

qid = "policy-failclosed"
path = root || "/running/" || qid || ".job"
s = .Stream~new(path)
if s~open("WRITE REPLACE") \= "READY:" then call fail "open record"
s~lineOut('JOB_ID="' || qid || '"')
s~lineOut('JOB_NAME="policy failclosed"')
s~lineOut('PRIORITY="10"')
s~lineOut('JOB_CLASS="DEFAULT"')
s~lineOut('RUNNER="direct"')
s~lineOut('COMMAND=( "/bin/true" )')
s~close

record = .QueueStateStore~new(root)~findOne(qid)
if record == .nil then call fail "record missing"

missing = .QueueBashClassPolicyProvider~new(root, root || "/no-such-queuebash.sh")
a = missing~assess(record)
if a~allowed then call fail "missing provider allowed"
if a~decision \= .QueuePolicyAssessment~ERROR then call fail "missing provider not error"
if a~code \= .QueueBashPolicyCode~PROVIDER_UNAVAILABLE then call fail "missing provider code"

fake = root || "/fake-queuebash.sh"
fs = .Stream~new(fake)
if fs~open("WRITE REPLACE") \= "READY:" then call fail "fake source"
fs~lineOut('QUEUEBASH_VERSION="0.18.143"')
fs~close

mismatch = .QueueBashClassPolicyProvider~new(root, fake)
b = mismatch~assess(record)
if b~allowed then call fail "version mismatch allowed"
if b~decision \= .QueuePolicyAssessment~ERROR then call fail "version mismatch not error"
if b~code \= .QueueBashPolicyCode~VERSION_MISMATCH then call fail "version mismatch code " || b~code

say "PASS QueueBash policy provider fails closed on missing source and compatibility-version mismatch"
exit 0

fail: procedure
  parse arg m
  say "FAIL" m
  exit 1

::requires "QueueRexxPolicy.cls"
