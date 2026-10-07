#!/usr/bin/env rexx
numeric digits 50
v=.VisionHumanBehaviourVector~new(.9,.8,.7,.6,.8,.75,.5)
call assert v~asArray~items=7,"behaviour vector has seven non-face dimensions"
s=.VisionEntityEvidenceSet~new("actor-9")
e=.VisionEntityEvidence~new("actor-9",12,"movement",.9,"persistent coherent track","movement:track-9")
call assert s~add(e)=1,"entity evidence retained"
s~setHumanBehaviour(v)
call assert s~behaviourVector~persistence=.9,"behaviour evidence retained"
h=.VisionEntityHypothesis~new("actor-9","human",.78,s,"future-ml-model")
call assert h~label="HUMAN","hypothesis label is semantic interpretation"
call assert h~confidence=.78,"hypothesis confidence retained"
call assert s~evidence[1]~evidenceType="MOVEMENT","measurement provenance retained"
say "PASS vision/0.1 entity evidence + non-face human behaviour seam"
exit 0
assert: procedure
 use arg c,m
 if \c then do; say "FAIL:" m; exit 1; end
 return
::requires "../src/Vision.cls"
