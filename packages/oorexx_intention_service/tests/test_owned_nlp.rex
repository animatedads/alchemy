/* Qualify every NLP engine owned by IntentionService. */
call assertTrue .IntentionNLPRegistry~available~items = 11, "owned engine count"

names = .IntentionNLPRegistry~available
do i = 1 to names~items
  service = .IntentionService~new
  service~registerBucket("COMMANDS", .IntentionBucketPolicy~new("FLEXIBLE", 1, 0, .false, .false))
  registration = service~register("list directory", .nil, "COMMANDS")
  registration~alias("show files")
  registration~semantics("list|show", "directory|files")
  service~useNlp(names[i])

  decision = service~input("list directory")
  call assertTrue decision \== .nil, names[i] "decision exists"
  call assertTrue decision~status \== "UNKNOWN", names[i] "recognises exact phrase"
end

say "PASS test_owned_nlp"
exit 0

assertTrue: procedure
  use arg condition, label
  if condition then return
  say "FAIL" label
  exit 1

::requires "IntentionService.cls"
::requires "IntentionProviders.cls"
