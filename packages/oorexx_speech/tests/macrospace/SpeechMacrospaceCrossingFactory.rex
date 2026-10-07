use strict arg kind, pyHandle = .nil
if kind \== 'PYTHON_PROXY' then raise syntax 93.900 array('expected PYTHON_PROXY', kind)
proxy = .AlchemyPythonObject~new(pyHandle)
return .SpeechMacrospaceCrossingLane~new(proxy)

::class SpeechMacrospaceCrossingLane public
::method init
  expose proxy peers
  use strict arg proxy
  peers = .Array~new

::method attachLane
  expose peers
  use strict arg lane
  peers~append(lane)
  return .true

::method provider
  expose proxy
  return .SpeechMacrospaceDuplexProvider~new(proxy, 'macrospace-probe')

::method run
  expose peers
  if peers~items \== 3 then return 'FAIL expected 4 lanes'
  lanes = .Array~of(self, peers[1], peers[2], peers[3])
  runtime = .SpeechRuntime~new
  t1 = .SpeechTTSChannel~new('tts-a', lanes[1]~provider, .nil)
  t2 = .SpeechTTSChannel~new('tts-b', lanes[2]~provider, .nil)
  s1 = .SpeechSTTChannel~new('stt-a', lanes[3]~provider)
  s2 = .SpeechSTTChannel~new('stt-b', lanes[4]~provider)
  runtime~addChannel(t1); runtime~addChannel(t2); runtime~addChannel(s1); runtime~addChannel(s2)

  fmt = .SpeechAudioFormat~new(16000, 1, 'S16LE', 'PCM')
  a1 = .SpeechAudioArtifact~new('input-a.wav', 'audio/wav', fmt, 'probe')
  a2 = .SpeechAudioArtifact~new('input-b.wav', 'audio/wav', fmt, 'probe')

  call time 'R'
  m1 = t1~synthesizeAsync(.SpeechTTSRequest~new('alpha', 'voice-a', 'en'))
  m2 = t2~synthesizeAsync(.SpeechTTSRequest~new('beta', 'voice-b', 'en'))
  m3 = s1~recognizeAsync(.SpeechSTTRequest~new(a1, 'en'))
  m4 = s2~recognizeAsync(.SpeechSTTRequest~new(a2, 'en'))
  r1 = m1~result; r2 = m2~result; r3 = m3~result; r4 = m4~result
  elapsed = time('E')

  if r1~artifact~ref \== 'probe:alpha' then return 'FAIL tts-a=' || r1~artifact~ref
  if r2~artifact~ref \== 'probe:beta' then return 'FAIL tts-b=' || r2~artifact~ref
  if r3~text \== 'probe-transcript:input-a.wav' then return 'FAIL stt-a=' || r3~text
  if r4~text \== 'probe-transcript:input-b.wav' then return 'FAIL stt-b=' || r4~text
  return 'PASS elapsed=' || elapsed

::requires 'SpeechChannels.cls'
::requires 'SpeechProviders.cls'
::requires 'SpeechMacrospace.cls'
::requires 'animals.cls'
