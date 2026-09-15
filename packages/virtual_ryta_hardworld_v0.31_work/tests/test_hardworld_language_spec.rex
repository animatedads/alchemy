say 'HARDWORLD LANGUAGE SPEC START'

language = .HardWorldLanguageSpec~new
call assertEqual 'ALL allowed', .true, language~isAllowedCombinator('ALL')
call assertEqual 'ANY allowed', .true, language~isAllowedCombinator('ANY')
call assertEqual 'AND rejected', .false, language~isAllowedCombinator('AND')
call assertEqual 'OR rejected', .false, language~isAllowedCombinator('OR')
call assertEqual 'NOT structurally banned', .true, language~isBannedStructuralToken('NOT')
call assertEqual 'UNLESS structurally banned', .true, language~isBannedStructuralToken('UNLESS')
call assertEqual 'DEFAULT structurally banned', .true, language~isBannedStructuralToken('DEFAULT')
call assertEqual 'UNKNOWN epistemic predicate allowed', .true, language~isAllowedEpistemicPredicate('UNKNOWN')
call assertEqual 'CONFLICT epistemic predicate allowed', .true, language~isAllowedEpistemicPredicate('CONFLICT')
call assertEqual 'NOT epistemic predicate rejected', .false, language~isAllowedEpistemicPredicate('NOT')
call assertEqual 'MUST hard obligation', 'HARD_OBLIGATION', language~normativeClass('MUST')
call assertEqual 'MUST NOT hard prohibition', 'HARD_PROHIBITION', language~normativeClass('MUST_NOT')
call assertEqual 'MAY permission', 'PERMISSION', language~normativeClass('MAY')
call assertEqual 'CAN capability only', 'CAPABILITY_FACT_ONLY', language~normativeClass('CAN')
call assertEqual 'CANNOT capability only', 'CAPABILITY_FACT_ONLY', language~normativeClass('CANNOT')
call assertEqual 'SHOULD banned soft norm', 'BANNED_SOFT_NORM_V1', language~normativeClass('SHOULD')
call assertEqual 'MIGHT banned uncertainty', 'BANNED_UNCERTAIN_NORM_V1', language~normativeClass('MIGHT')

say 'HARDWORLD LANGUAGE SPEC: OK'
exit 0

assertEqual: procedure
  use arg label, expected, actual
  if expected == actual then return .true
  say 'ASSERT FAILED:' label
  say '  expected:' expected
  say '  actual:  ' actual
  exit 1

::requires '../HardWorld.cls'
