parse arg root
policy = root || '/policy/ourladyair_safety_policy.txt'
legal = .ShannonLegalPolicy~new(policy)
call assertTrue legal~generation~sealed, 'legal generation sealed'
call assertTrue legal~generation~publicationEligible, 'legal generation publication eligible'
call assertEqual 'OURLADYAIR-SHANNON-LEGAL-G3', legal~generation~generationId, 'generation id'
call assertTrue legal~semanticIdentity~length > 0, 'semantic identity present'
call assertEqual .LegalEffectBuild~API_VERSION, legal~legalApiVersion, 'loaded legal api retained'
call assertEqual .LegalEffectBuild~VERSION, legal~legalBuildVersion, 'loaded legal build metadata retained'
say 'PASS test_shannon_legal_policy'
exit 0

assertTrue: procedure
  use arg conditionValue, label
  if \conditionValue then do; say 'FAIL:' label; exit 1; end
  return
assertEqual: procedure
  use arg expected, actual, label
  if expected \== actual then do; say 'FAIL:' label 'expected=' expected 'actual=' actual; exit 1; end
  return

::requires 'ShannonLegalPolicy.cls'
