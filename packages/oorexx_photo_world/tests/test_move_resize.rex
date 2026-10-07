w=.SurveyWorld~new
ctx=w~context
o=.SurveyBlock~new('b',10,20,5,.SurveyPose~new(.MathVector3~new(0,0,2.5,ctx)))
o~moveBy(2,3,1)~resize(12,22,6)
if o~pose~position~x<>2 then exit 1
if o~pose~position~y<>3 then exit 2
if o~size~width<>12 then exit 3
if o~size~depth<>22 then exit 4
if o~size~height<>6 then exit 5
g=.SurveyGroundPatch~new('g',.MathVector3~new(0,0,10,ctx),20,20,0,0,ctx)
c=.SurveyCamera~new('c',.SurveyPose~new(.MathVector3~new(1,2,0,ctx)))
c~placeOnGround(g)
if c~pose~position~z<>11.60 then exit 6
say 'PASS move/resize/camera-height'
exit 0
::requires '../rexx/SurveyWorld.cls'
