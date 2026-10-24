/* Run: rexx examples/demo.rex from package root */
call demo
exit 0
::routine demo
  engine = .StoryDecisionEngine~new
  engine~policyRevision('institutional-8')
  engine~registerIntention(.StoryIntention~new('technical', 20, 'Technical evaluation', '1'))
  engine~registerIntention(.StoryIntention~new('support', 100, 'Restore service', '1'))
  ids = .Array~of('claim-architecture')
  engine~registerNarrative(.StoryNarrative~new('integration', 'technical', 'Integrate with confidence', 'Explore the architecture.', 'Read architecture', ids, '1'))
  engine~registerNarrative(.StoryNarrative~new('service', 'support', 'Resolve the issue first', 'Support and recovery guidance.', 'Open support', .Array~of('claim-support'), '1'))
  engine~approveClaim('claim-architecture', '7')
  engine~approveClaim('claim-support', '1')
  decision = engine~decide(.Array~of('technical'), 'DE', 'web')
  say decision['status'] decision['headline']
  decision = engine~decide(.Array~of('technical', 'support'), 'DE', 'web')
  say decision['status'] decision['headline']
  engine~revokeClaim('claim-support')
  decision = engine~decide(.Array~of('support'), 'DE', 'web')
  say decision['status'] decision['reason']
::requires 'src/DynamicStory.cls'
