parse source . . here
base = filespec("L", here)
call value "REXX_PATH", base || "/../src:" || value("REXX_PATH", , "ENVIRONMENT"), "ENVIRONMENT"

corpus = .IntentionCorpus~new
commandPolicy = .IntentionBucketPolicy~new("FLEXIBLE", 55, 12, .true, .false)
policyPolicy = .IntentionBucketPolicy~new("FLEXIBLE", 60, 12, .true, .false)

command = .IntentionCorpusMaterial~new("list directory", .DemoEvent~new, "COMMANDS", commandPolicy)
command~alias("show files")
corpus~add(command)
corpus~addEvidence(.IntentionCorpusEvidence~new("POLICY", -
    "Formatting removable media requires an explicit target device.", -
    "storage-policy.conf", .nil, policyPolicy))

service = .IntentionService~new
service~loadCorpus(corpus)
call assertEquals 1, service~bucket("COMMANDS")~entries~items, "command material loaded into command bucket"
call assertEquals 1, service~bucket("POLICY")~evidence~items, "policy evidence loaded into policy bucket"
call assertContains service~bucket("POLICY")~evidence~at(1)~content, "explicit target", "policy text retained"
say "PASS test_corpus_buckets"
exit 0

assertEquals: procedure
  use arg expected, actual, label
  if expected == actual then return
  say "FAIL" label "expected=" expected "actual=" actual
  exit 1

assertContains: procedure
  use arg haystack, needle, label
  if pos(needle, haystack) > 0 then return
  say "FAIL" label
  exit 1

::class DemoEvent public
::method invoke
  use arg decision
  return "OK"

::requires "IntentionService.cls"
