/* A deliberately crude plausible world: move/resize until several photographs agree. */
world=.SurveyWorld~new
ctx=world~context
ground=.SurveyGroundPatch~new('main-road',.MathVector3~new(0,0,0,ctx),120,30,0,'-0.015',ctx)
world~addGround(ground)

museum=.SurveyBlock~new('classical-building',32,18,12,.SurveyPose~new(.MathVector3~new(-8,14,6,ctx)),.7,'principal masonry mass')
world~addObject(museum)
museum~resize(34,19,12.5)~moveBy(-1,2,0)

do i=1 to 4
  c=.SurveyColumn~new('portico-column-'i,'0.65',8.5,.SurveyPose~new(.MathVector3~new(-15+i*3.2,4.8,4.25,ctx)),.65)
  world~addObject(c)
end

cam=.SurveyCamera~new('photo-latest',.SurveyPose~new(.MathVector3~new(0,-8,0,ctx),0,-4,0,ctx),1.60,58,1152,1536)
world~addCamera(cam)
cam~placeOnGround(ground)
cam~moveBy(1.2,0,0)
cam~pose~yaw=7
cam~pose~pitch=-5

say 'camera' cam~pose~position 'height-rule' cam~heightAboveGround
say 'building' museum~centre 'size' museum~size~width museum~size~depth museum~size~height
say 'objects' world~objectIds~items
