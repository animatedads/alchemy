call tests
exit 0
::routine assertEq
  use strict arg actual, expected, label
  if actual \== expected then do
    say 'FAIL:' label 'expected='expected 'actual='actual
    exit 1
  end
::routine tests
  e = .StoryDecisionEngine~new
  e~policyRevision('p1')
  e~registerIntention(.StoryIntention~new('sales', 10, 'Explain value', '1'))
  e~registerIntention(.StoryIntention~new('incident', 90, 'Restore service', '1'))
  e~registerNarrative(.StoryNarrative~new('n-sales', 'sales', 'Value', 'Benefit', 'Learn', .Array~of('c1'), '1'))
  e~registerNarrative(.StoryNarrative~new('n-incident', 'incident', 'Help', 'Fix', 'Support', .Array~of('c2'), '2'))
  call assertEq e~decide(.Array~of('sales'), 'GB', 'web')['status'], 'BLOCKED_UNAPPROVED_CLAIM', 'unapproved'
  e~approveClaim('c1', '1')
  e~approveClaim('c2', '1')
  result = e~decide(.Array~of('sales','incident'), 'GB', 'web')
  call assertEq result['intention_id'], 'incident', 'priority'
  e~revokeClaim('c2')
  result = e~decide(.Array~of('incident'), 'GB', 'web')
  call assertEq result['status'], 'BLOCKED_REVOKED_CLAIM', 'revoke'
  call assertEq e~decide(.Array~of('none'), 'GB', 'web')['status'], 'NO_ELIGIBLE_INTENTION', 'unknown'
  say 'PASS: Dynamic Story core tests'
::requires 'src/DynamicStory.cls'
