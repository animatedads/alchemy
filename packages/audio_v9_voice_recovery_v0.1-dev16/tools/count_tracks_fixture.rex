numeric digits 30
parse arg fcPath fdPath
root=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT'); if root='' then root='.'
policy=.AudioV9SpectralFieldPolicy~new(120,3800,240,120,256,.60,.90,1000,500,2)
bridge=root||'/run/runtime/audio_v9_pattern_locator_v0.1-dev5-hotfix1/native/av9_pattern.bridge.json'
spectral=.AudioV9NativeProvider~new(bridge)
fcField=spectral~spectralField(fcPath,policy); fdField=spectral~spectralField(fdPath,policy)
boxer=.AudioV9SpectralBoxAnalyzer~new(policy)
fcBoxes=boxer~build(fcField,1000,500); fdBoxes=boxer~build(fdField,1000,500)
spatial=.AudioV9SpatialNativeProvider~new(root||'/run/native/av9_spatial.bridge.json')
scan=spatial~scan(fcPath,fdPath,8000,8000,4000,500,25)
assembler=.AudioV9AcousticCharacterAssembler~new(4000)
fc=assembler~assemble(fcBoxes,scan,0,'FC'); fd=assembler~assemble(fdBoxes,scan,0,'FD')
chars=.array~new; do x over fc; chars~append(x); end; do x over fd; chars~append(x); end
tracks=.AudioV9TrackBuilder~new(.AudioV9AcousticCharacterSchema~new,750,1,36)~build(chars)
say 'boxes='||(fcBoxes~items+fdBoxes~items)||' chars='||chars~items||' tracks='||tracks~items
exit 0
::requires 'AudioV9AcousticCharacter.cls'
::requires 'AudioV9NativeProvider.cls'
