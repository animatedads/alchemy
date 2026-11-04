numeric digits 30
root=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT'); if root='' then root='.'
source=.AudioV9Point3D~new(0,0,1.5)
receiver=.AudioV9Point3D~new(10,0,1.5)
geometry=.AudioV9TransientReflectorGeometry~new(source,receiver,8000,343)
policy=.AudioV9TransientReflectorPolicy~new(.55,.50,3,.70,6,3)

matches=.array~new
do i=1 to 3
  sample=.AudioV9ReflectorTrajectorySample~new(1000*i,.AudioV9Point3D~new(2*i,4,1.5),.90,'CAR_1')
  predicted=geometry~predict(sample)
  matches~append(policy~classify('A'||i,predicted,predicted~excessDelaySamples+1,.88,.10,0))
end
candidate=policy~virtualMicrophoneCandidate(matches)
call assert candidate~available,'audio-supported trajectory must admit candidate'
call assert candidate~matchCount=3,'candidate match count'

visualOnly=.array~new
sample=.AudioV9ReflectorTrajectorySample~new(1000,.AudioV9Point3D~new(5,4,1.5),.95,'CAR_2')
predicted=geometry~predict(sample)
visualOnly~append(policy~classify('V1',predicted,predicted~excessDelaySamples,.20,.10,0))
call assert \policy~virtualMicrophoneCandidate(visualOnly)~available,'visual geometry must not create authority'

selfNoise=policy~classify('N1',predicted,predicted~excessDelaySamples,.20,.90,0)
call assert selfNoise~hypothesis='H3_SELF_NOISE','self-noise competing hypothesis'
blocked=policy~classify('B1',predicted,predicted~excessDelaySamples+20,.20,.10,8)
call assert blocked~hypothesis='H2_BLOCKAGE','blockage competing hypothesis'
wrongDelay=policy~classify('W1',predicted,predicted~excessDelaySamples+20,.90,.10,0)
call assert \wrongDelay~admitted,'geometry mismatch must fail closed'

say 'PASS transient reflector trajectory authority and H0/H1/H2/H3 gates'
exit 0

assert: procedure
  parse arg condition,message
  if \condition then do; say 'FAIL' message; exit 1; end
  return

::requires 'AudioV9TransientReflectorTrajectory.cls'
