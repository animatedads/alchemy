/* ooRexx native acceptance: active questions, replanning, policy, closure,
 * feature trace, provenance, cost, resolved vs unresolved authority. */
cat = .ArchitectureCatalog~fromFile('catalog/architecture_catalog.json')
planner = .ArchitecturePlanner~new(cat)
p = planner~project('test-p','Test Project')
plan = planner~plan(p)
call assert plan['state'] == 'NEEDS_DECISIONS', 'fresh state'
call assert plan['openQuestions']~items > 8, 'fresh questions'
call assert plan['cost']['missingQuotes']~items == 0, 'no cost demands before selections'
call assert plan['buildRequest']['executable']~value == 0, 'build not executable'

/* Cloud branch must open a hosting question, RexxOS-only carrier stays hidden. */
p~answer('deployment_model','cloud','Hosted service','architect')
plan = planner~plan(p)
call assert hasQuestion(plan,'hosting'), 'cloud hosting open'
call assert hasQuestion(plan,'interconnect'), 'cloud interconnect open'
call assert \hasQuestion(plan,'xtp_carrier'), 'no MI-specific carrier'
call assert plan['cost']['missingQuotes']~items > 0, 'cost resources without price'

/* RTO2 topology activates XTP carrier instead, hides cloud selections. */
p~answer('deployment_model','rexxos_mu_mi','MU MI nodes','architect')
plan = planner~plan(p)
call assert hasQuestion(plan,'xtp_carrier'), 'MU carrier open'
call assert \hasQuestion(plan,'interconnect'), 'MU transport fixed XTP'
call assert \hasQuestion(plan,'hosting'), 'no cloud provider'

/* Illegal L2 topology and external UDP underlay fail closed. */
p~answer('xtp_carrier','l2','Native Ethernet','architect')
p~answer('network_scope','routed','Separate LANs','architect')
plan = planner~plan(p)
call assert plan['state'] == 'INCONSISTENT', 'L2 routed forbidden'
call assert hasIssue(plan,'ARCH_L2_SCOPE'), 'L2 issue'
p~answer('xtp_carrier','udp_outer','Try UDP fallback','architect')
plan = planner~plan(p)
call assert hasIssue(plan,'ARCH_XTP_UDP_POLICY'), 'UDP forbidden by policy'
p~answer('xtp_carrier','ip36','Routed native protocol','architect')
plan = planner~plan(p)
call assert \hasIssue(plan,'ARCH_L2_SCOPE'), 'L2 issue now removed'
call assert \hasIssue(plan,'ARCH_XTP_UDP_POLICY'), 'UDP issue now removed'

/* Wrong RexxOS execution target is not silently qualified. */
p~answer('deployment_target','linux','Linux test','architect')
plan = planner~plan(p)
call assert hasIssue(plan,'ARCH_MU_TARGET'), 'wrong target issue'
p~answer('deployment_target','rexxos','MU MI managed','architect')
plan = planner~plan(p)
call assert \hasIssue(plan,'ARCH_MU_TARGET'), 'correct target'

/* Component requests must be dependency ordered and unresolved. */
foundXtp = 0
foundSock = 0
do req over plan['buildRequest']['requirements']
  if req['componentId'] == 'socket_provider' then foundSock = 1
  if req['componentId'] == 'xtp' then do
    foundXtp = 1
    call assert foundSock == 1, 'socket provider before xtp'
  end
  call assert req['resolutionStatus'] == 'UNRESOLVED', 'never fake lock'
  call assert req['artifactDigest'] == .nil, 'never fake digest'
end
call assert foundXtp & foundSock, 'network closure'

/* A requirement may bring an explicit component even without a choice. */
req = .Array~of('notnotes','storage_fabric')
p~feature('revision_history','Document revision history','must', -
    'Checkpoint and restore verified', 'architect', req)
plan = planner~plan(p)
call assert plan['featureRegister']~items == 1, 'feature recorded'
call assert hasComponent(plan,'notnotes'), 'feature adds component'
call assert hasComponent(plan,'storage_fabric'), 'feature closure'

/* Selection is reversible; hidden choices never leak into current closure. */
p~answer('interconnect','socket','Alternative transport','architect')
p~answer('deployment_model','local','Local preview','architect')
plan = planner~plan(p)
call assert plan['effectiveAnswers']~hasIndex('xtp_carrier') == .false, 'hide stale carrier'
call assert plan['effectiveAnswers']~hasIndex('interconnect'), 'activate prior choice'
call assert plan['decisionHistory']~items > plan['decisionRegister']~items, 'keep history'

/* Assumption-only cost, with typed numeric projection and no invented rates. */
p~answer('storage','filesystem','Local file','architect')
p~answer('frontend','headless','Daemon','architect')
plan = planner~plan(p)
call assert plan['cost']['missingQuotes']~items == 0, 'local has no priced drivers'
p~answer('deployment_model','cloud','Cloud','architect')
p~answer('storage','object','Object store','architect')
p~answer('frontend','web','Browser','architect')
p~quote('compute',1.25,100,'GBP','instance-hours/month','quote 1')
p~quote('storage',.2,300,'GBP','GB-month','quote 2')
p~quote('network_egress',.1,200,'GBP','GB/month','quote 3')
plan = planner~plan(p)
call assert plan['cost']['status'] == 'ASSUMPTION_ONLY', 'cost assumptions status'
call assert plan['cost']['estimatedMonthly'] = 205, 'monthly quote arithmetic'
p~quote('storage',.2,300,'EUR','GB-month','quote 3 EUR')
plan = planner~plan(p)
call assert plan['cost']['status'] == 'INCOMPLETE', 'currency mismatch incomplete'
call assert plan['cost']['estimatedMonthly'] == .nil, 'currency mismatch not totalled'

say 'PASS architecture core: decisions, branches, policies, features, dependencies, costs'
exit 0

assert:
  use arg truth, message
  if truth then return
  say 'FAIL:' message
  exit 1

hasQuestion:
  use arg snapshot, questionId
  do row over snapshot['openQuestions']
    if row['id'] == questionId then return .true
  end
  return .false
hasIssue:
  use arg snapshot, code
  do row over snapshot['issues']
    if row['code'] == code then return .true
  end
  return .false
hasComponent:
  use arg snapshot, component
  do row over snapshot['buildRequest']['requirements']
    if row['componentId'] == component then return .true
  end
  return .false
::requires 'ArchitecturePlanner.cls'
