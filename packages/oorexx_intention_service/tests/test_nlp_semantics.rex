/* Service-owned NLP derives simple semantics but lets domain owners override it. */
service = .IntentionService~new
registration = service~register("have dinner", .nil)
call assertEq "have", registration~verbTerms, "derived verb"
call assertEq "dinner", registration~nounTerms, "derived noun"
registration~semantics("have|eat", "dinner|meal")
call assertEq "have|eat", registration~verbTerms, "override verbs"
call assertEq "dinner|meal", registration~nounTerms, "override nouns"
say "PASS test_nlp_semantics"
exit 0

assertEq: procedure
  use arg expected, actual, label
  if expected == actual then return
  say "FAIL" label "expected=" expected "actual=" actual
  exit 1

::requires "IntentionService.cls"
