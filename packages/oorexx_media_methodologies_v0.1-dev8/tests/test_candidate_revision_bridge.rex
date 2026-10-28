#!/usr/bin/env rexx
b=.MediaMethodologyRevisionBridge~new
cases=.array~new
cases~append(.array~of('NO_REVISION','UNCHANGED'))
cases~append(.array~of('ADMITTED_DELTA_BACKED','REVISED'))
cases~append(.array~of('MUTATED_GROUND_ID','QUARANTINED'))
cases~append(.array~of('UNVERIFIED_REMOVAL','QUARANTINED'))
cases~append(.array~of('POLICY_CHANGE_REQUIRES_REVIEW','REVIEW_REQUIRED'))
cases~append(.array~of('CLAIMED_FLIP_UNSUPPORTED','UNRESOLVED'))
do pair over cases
  a=.Directory~new
  a['classification']=pair[1]
  a['claimedMatchesDerived']=.true
  r=b~consume('candidate:1',a)
  call assertEq pair[2],r~lifecycle,'lifecycle for' pair[1]
  call assertTrue \r~allowsAutomaticCandidatePromotion,'revision never promotes candidate'
  call assertEq 'FALSE',r~details['FACTUAL_TRUTH_CLAIM'],'revision is not factual truth'
end
say 'PASS candidate revision bridge consumes audit classification without taking truth authority'
exit 0
assertTrue: procedure
  use arg value,label
  if value then return
  say 'FAIL' label
  exit 1
assertEq: procedure
  use arg expected,actual,label
  if expected==actual then return
  say 'FAIL' label 'expected='expected 'actual='actual
  exit 1
::requires 'MediaMethodologyRevision.cls'
