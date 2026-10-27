#!/usr/bin/env rexx
call testAuthorityDirectoryGate
call testFeasibilityObjectGate
call testCompositeGate
call testInvalidGateFailsClosed
say "AUDIO CONTEXT AUTHORITY/FEASIBILITY GATES DEV9: OK"
exit 0

testAuthorityDirectoryGate: procedure
  recording=.AudioRecording~new("REC-GATE-1",1000)
  clean=recording~addRawFeed("CLEAN",1000,"storage-ref:clean","clean speech",.directory~new)
  bindings=.directory~new
  bindings["CLEAN"]=.TestBinding~new("obj:clean|g=7")
  authority=.directory~new
  authority["STORAGE_IDENTITY"]=.false
  ctx=.AudioIntentionContext~new(authority,.nil,bindings,.nil,recording)
  snapshot=.AudioIntentionProvider~new~discover(clean,ctx)
  storage=snapshot~byFeature("STORAGE_IDENTITY")
  call assert storage~items=1, "denied Storage candidate should remain observable"
  call assert storage[1]~state="UNAVAILABLE", "authority denial did not make candidate unavailable"
  call assert storage[1]~reason="AUTHORITY_DENIED", "authority denial reason missing"
  call assert \storage[1]~selectable, "authority-denied candidate remained selectable"
  call assert storage[1]~candidates[1]==bindings["CLEAN"], "authority gate flattened candidate object"
return

testFeasibilityObjectGate: procedure
  recording=.AudioRecording~new("REC-GATE-2",1000)
  raw=recording~addRawFeed("RAW",1000,"raw.wav","raw",.directory~new)
  view=recording~createTranscriptView("TR")
  view~addBoundary(.AudioBoundary~new("B1",.array~of("RAW")))
  feasibility=.FeatureGate~new("VIEW_BOUNDARIES","NO_BOUNDARY_RENDERER")
  ctx=.AudioIntentionContext~new(.nil,feasibility,.directory~new,.nil,recording)
  snapshot=.AudioIntentionProvider~new~discover(view,ctx)
  boundaries=snapshot~byFeature("VIEW_BOUNDARIES")
  call assert boundaries~items=1, "feasibility-denied boundaries should remain observable"
  call assert boundaries[1]~state="UNAVAILABLE", "feasibility denial not enforced"
  call assert boundaries[1]~reason="NO_BOUNDARY_RENDERER", "feasibility reason not retained"
  call assert snapshot~byFeature("VIEW_SOURCE_ELEMENTS")[1]~selectable, "unrelated view source intention was incorrectly denied"
return

testCompositeGate: procedure
  recording=.AudioRecording~new("REC-GATE-3",1000)
  raw=recording~addRawFeed("RAW",1000,"raw.wav","raw",.directory~new)
  view=recording~createTranscriptView("TR")
  view~addBoundary(.AudioBoundary~new("B1",.array~of("RAW")))
  authority=.directory~new
  authority["TRANSCRIPT"]=.false
  ctx=.AudioIntentionContext~new(authority,.nil,.directory~new,.nil,recording)
  criteria=.directory~new
  criteria["FEATURE_KIND"]="TRANSCRIPT"
  proposal=.AudioIntentionProvider~new~proposeComposite(recording,criteria,ctx)
  call assert proposal~status="UNAVAILABLE", "composite authority gate did not block READY"
  call assert proposal~reason="AUTHORITY_DENIED", "composite authority reason missing"
return

testInvalidGateFailsClosed: procedure
  recording=.AudioRecording~new("REC-GATE-4",1000)
  raw=recording~addRawFeed("RAW",1000,"raw.wav","raw",.directory~new)
  ctx=.AudioIntentionContext~new(.InvalidGate~new,.nil,.directory~new,.nil,recording)
  snapshot=.AudioIntentionProvider~new~discover(raw,ctx)
  inspect=snapshot~byFeature("ELEMENT_INSPECT")
  call assert inspect~items=1, "invalid gate removed semantic candidate"
  call assert inspect[1]~state="UNAVAILABLE", "invalid gate must fail closed"
  call assert inspect[1]~reason="AUTHORITY_GATE_INVALID", "invalid gate diagnostic missing"
return

assert: procedure
  use arg condition,message
  if condition then return
  say "FAIL:" message
  exit 1

::class TestBinding public
::attribute identityKey get
::method init
  expose identityKey
  use arg identityKey

::class InvalidGate public

::class FeatureGate public
::method init
  expose denied reason
  use strict arg deniedArg, reasonArg
  denied=deniedArg~string~upper
  reason=reasonArg~string
::method allowIntention
  expose denied reason
  use strict arg candidate, target, context
  if candidate~featureKind~upper=denied then return .AudioIntentionGateDecision~new(.false,reason,self)
  return .AudioIntentionGateDecision~new(.true)

::requires "fixtures/AudioCoreFixture.cls"
::requires "src/AudioIntentions.cls"
