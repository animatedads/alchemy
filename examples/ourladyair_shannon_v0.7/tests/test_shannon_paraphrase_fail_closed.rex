parse arg root
policy = root || '/policy/ourladyair_safety_policy.txt'

/* One full governed turn proves the fail-closed path reaches Legal Effect. */
session = .ShannonChatSession~new('test-paraphrase-governed', policy)
turn = session~respond('my allergy pen is in the 10 kg bag')
call assertEqual 'NEEDS_INFORMATION', turn~mode, 'recognised paraphrase enters information state'
call assertFalse turn~salesAllowed, 'recognised paraphrase blocks sales'
call assertTrue turn~world~isKnownTrue('SAFETY_RELEVANCE_DETECTED'), 'safety relevance detected'
call assertTrue turn~world~isKnownTrue('SAFETY_RELEVANCE_UNRESOLVED'), 'safety relevance unresolved'
call assertEqual 'BLOCKED', turn~legalAssessments['SELL_PRODUCT']~status, 'Legal Effect fail-closed'

/* Additional paraphrases exercise the deterministic extractor and HardWorld
   without recompiling the same byte-pinned policy for every lexical case. */
extractor = .ShannonFactExtractor~new
phrases = .array~of('the injector the doctor gave me is in there', 'my heart tablets are in that bag')
i = 0
do phrase over phrases
  i += 1
  world = .RYTAWorldState~new('PARAPHRASE-' || i)
  ignored = extractor~apply(phrase, world)
  call assertTrue world~isKnownTrue('SAFETY_RELEVANCE_DETECTED'), 'paraphrase relevance detected'
  call assertTrue world~isKnownTrue('SAFETY_RELEVANCE_UNRESOLVED'), 'paraphrase relevance unresolved'
  call assertEqual .RYTAConstant~KNOWLEDGE_UNKNOWN, world~knowledgeOf('ESSENTIAL_MEDICATION'), 'identity remains epistemically unknown'
  run = .VirtualRYTA~new~evaluate(world)
  call assertEqual .RYTAConstant~STATE_NEEDS_INFORMATION, run~state, 'HardWorld fails closed on paraphrase uncertainty'
end

ordinaryWorld = .RYTAWorldState~new('PAPERBACK')
ignored = extractor~apply('I have a paperback in the bag.', ordinaryWorld)
ordinaryRun = .VirtualRYTA~new~evaluate(ordinaryWorld)
call assertEqual .RYTAConstant~STATE_NORMAL, ordinaryRun~state, 'ordinary item does not trigger safety block'
say 'PASS test_shannon_paraphrase_fail_closed'
exit 0

assertTrue: procedure
  use arg value, label
  if \value then do; say 'FAIL:' label; exit 1; end
  return
assertFalse: procedure
  use arg value, label
  if value then do; say 'FAIL:' label; exit 1; end
  return
assertEqual: procedure
  use arg expected, actual, label
  if expected \== actual then do; say 'FAIL:' label 'expected=' expected 'actual=' actual; exit 1; end
  return
::requires 'ShannonChatbot.cls'
