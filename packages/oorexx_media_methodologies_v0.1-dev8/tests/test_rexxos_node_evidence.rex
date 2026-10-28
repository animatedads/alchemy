call testMain
exit 0

testMain: procedure
  profile=.Directory~new
  profile["declared_role"]="media-worker"
  member=.RexxOSGridEstateMember~new("GRID-1","MI-7","MI","MU-2","epoch-44","ACTIVE",profile)
  evidence=.MediaRexxOSNodeEvidence~new(member)
  call assertEqual "rexxos://GRID-1/mu/MU-2/mi/MI-7",evidence~semanticRef,"stable MI semantic ref"
  call assertEqual "epoch-44",evidence~incarnation,"incarnation retained"
  p=evidence~profile
  p["declared_role"]="changed-outside"
  call assertEqual "media-worker",evidence~profile["declared_role"],"profile evidence detached"
  say "PASS RexxOS MI membership projected as read-only media node evidence"
  return

assertEqual: procedure
  use arg expected,actual,label
  if expected<>actual then do; say "FAIL" label "expected="expected "actual="actual; exit 1; end
  return

::requires "MediaMethodologyRexxOS.cls"
