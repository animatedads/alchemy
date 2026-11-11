/* These are camera-role/authority checks, NOT celestial identification. */
examples=.array~of(.array~of('stream1',1280,720,.true), -
  .array~of('stream2',1280,720,.true), -
  .array~of('stream3',640,360,.false))
checks=0
do case over examples
  frame=.SkyFixtureFrame~new(case[2],case[3])
  result=.MoonsaultSkyEvidence~assessFrame(frame,case[1])
  if result['starSearchAllowed']<>case[4] then -
    call fail 'candidate eligibility' case[1]
  if result['celestialHeadingAuthorized']<>.false then -
    call fail 'unexpected star fix' case[1]
  if .MoonsaultSkyEvidence~authorizeFix(result,3,3,0.5,.true,.true)<>case[4] then -
    call fail 'conditional fix-policy threshold' case[1]
  if .MoonsaultSkyEvidence~authorizeFix(result,3,0,0.5,.true,.true) then -
    call fail 'no catalogue match should be rejected' case[1]
  if .MoonsaultSkyEvidence~authorizeFix(result,0,3,0.5,.true,.true) then -
    call fail 'no tracks should be rejected' case[1]
  if .MoonsaultSkyEvidence~authorizeFix(result,3,3,0.5,.false,.true) then -
    call fail 'uncalibrated camera should be rejected' case[1]
  if .MoonsaultSkyEvidence~authorizeFix(result,3,3,0.5,.true,.false) then -
    call fail 'unverified clock should be rejected' case[1]
  say 'PASS' case[1] result['width'] 'x' result['height'] result['role']
  checks+=7
end
say 'PASS MOONSAULT SKY ROLE/AUTHORITY' checks 'assertions'
exit 0
fail: procedure
 use arg message,detail
 say 'FAIL:' message detail
 exit 1
::class SkyFixtureFrame public
::attribute width get
::attribute height get
::method init
  expose width height
  use strict arg w,h
  width=w; height=h
::requires '../src/MoonsaultSkyEvidence.cls'