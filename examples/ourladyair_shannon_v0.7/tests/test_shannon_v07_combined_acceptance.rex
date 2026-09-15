parse arg root
policyPath = root || '/policy/ourladyair_safety_policy.txt'
policy = .ShannonLegalPolicy~new(policyPath)
feed = .ShannonPnrGovParser~parseFile(root || '/examples/ourladyair_shannon_ticket_groups_v1.edi')

/* G07: profitable seat + bar path remains available. */
booking = feed~booking('G07')
session = .ShannonChatSession~new('v05-g07', policyPath, .nil, booking, policy)
turn = session~respond('What extras can you sell us?')
call assertEqual 9000, turn~commercialPlan~modelGrossCents, 'G07 model gross EUR90'
call assertEqual 9000, turn~commercialPlan~governedGrossCents, 'G07 governed gross EUR90'
call assertEqual 6000, turn~commercialPlan~governedGrossFor('SEAT_RESERVATION'), 'G07 seat revenue EUR60'
call assertEqual 3000, turn~commercialPlan~governedGrossFor('BAR_BUNDLE'), 'G07 bar revenue EUR30'

/* G02: scattered does not mean unpurchased. */
booking = feed~booking('G02')
session = .ShannonChatSession~new('v05-g02', policyPath, .nil, booking, policy)
turn = session~respond('Can you make us sit together?')
call assertEqual 0, turn~commercialPlan~governedGrossFor('SEAT_RESERVATION'), 'G02 no seat double-sell'
call assertNotContains turn~finalText, '€20 per passenger', 'G02 no seat fee emitted'

/* G03: teen bar target is removed, adults remain commercially available. */
booking = feed~booking('G03')
session = .ShannonChatSession~new('v05-g03', policyPath, .nil, booking, policy)
turn = session~respond('Drinks?')
call assertEqual 3000, turn~commercialPlan~modelGrossCents, 'G03 model tries EUR30'
call assertEqual 2000, turn~commercialPlan~governedGrossCents, 'G03 two adult bundles only'
call assertNotContains turn~finalText, 'Ife Okafor', 'G03 teen removed from bar emission'

/* G04: safety/custody state suppresses the entire commercial flow. */
booking = feed~booking('G04')
session = .ShannonChatSession~new('v05-g04', policyPath, .nil, booking, policy)
turn = session~respond('What can you sell us?')
call assertEqual 'NEEDS_INFORMATION', turn~mode, 'G04 custody uncertainty mode'
call assertEqual 0, turn~commercialPlan~governedGrossCents, 'G04 governed revenue zero while custody unresolved'
call assertContains turn~modelProposal~text, 'Beer + Crisps', 'G04 feral proposal retained'
call assertNotContains turn~finalText, 'Beer + Crisps is €10', 'G04 bar sale does not leave gate'
medFact = turn~world~fact('ESSENTIAL_MEDICATION')
call assertTrue medFact~evidence \== .nil, 'G04 structured evidence retained'
call assertTrue medFact~evidence[1]~isA(.EdiFactProjectedRow), 'G04 evidence remains Structured Relation row'

/* G01: contradictory raw PTC/DOB remains fail-closed. */
booking = feed~booking('G01')
session = .ShannonChatSession~new('v05-g01', policyPath, .nil, booking, policy)
turn = session~respond('Drinks and snacks for the family?')
call assertEqual 5000, turn~commercialPlan~modelGrossCents, 'G01 model targets all five'
call assertEqual 1000, turn~commercialPlan~governedGrossCents, 'G01 only unambiguous adult survives'
call assertNotContains turn~finalText, 'Sean Murphy', 'G01 contradictory role fails closed'

/* Queue + NoSQL management projection using the same verified
   policy generation: no second cryptographic compilation is required. */
queueSession = .ShannonChatSession~new('v05-audit', policyPath, .nil, .nil, policy)
service = .ShannonQueueService~new(queueSession)
putOperation = service~submit('What extras can you sell me?')
call assertTrue putOperation~ok, 'Queue Fabric submit succeeds'
call assertEqual .QueueFabricBuild~VERSION, service~queueFabricVersion, 'loaded Queue Fabric active'
call assertEqual .NoSQLServerBuild~RELEASE, service~noSQLServerVersion, 'loaded NoSQLServer active'
turnQuery = service~queryAudit("SELECT model_gross_cents,governed_gross_cents,legal_api_version FROM shannon_turns")
call assertEqual .Error~SUCCESS, turnQuery~status, 'v0.6 Shannon audit SQL succeeds'
call assertEqual 1, turnQuery~rows~items, 'one v0.6 audit turn projected'
call assertEqual policy~legalApiVersion, turnQuery~rows[1]['legal_api_version'], 'audit SQL retains loaded Legal API identity'
auditOperation = service~getAudit
call assertTrue auditOperation~ok, 'rich audit remains in Queue Fabric'
call assertEqual 'DERIVED_INDEX_ONLY', auditOperation~value~payload['queue']['projectionAuthority'], 'NoSQL row is explicitly derived only'

call assertEqual .LegalEffectBuild~API_VERSION, policy~legalApiVersion, 'loaded Legal Effect engine identity retained'
say 'PASS test_shannon_v07_combined_acceptance legal=' || policy~legalApiVersion || ' queue=' || .QueueFabricBuild~API || ' nosql=' || .NoSQLServerBuild~RELEASE
exit 0

assertTrue: procedure
  use arg value, label
  if \value then do; say 'FAIL:' label; exit 1; end
  return
assertEqual: procedure
  use arg expected, actual, label
  if expected \== actual then do; say 'FAIL:' label 'expected=' expected 'actual=' actual; exit 1; end
  return
assertContains: procedure
  use arg text, needle, label
  if text~pos(needle) = 0 then do; say 'FAIL:' label 'missing=' needle; exit 1; end
  return
assertNotContains: procedure
  use arg text, needle, label
  if text~pos(needle) > 0 then do; say 'FAIL:' label 'unexpected=' needle; exit 1; end
  return

::requires 'ShannonPnrGovParser.cls'
::requires 'ShannonQueueService.cls'
