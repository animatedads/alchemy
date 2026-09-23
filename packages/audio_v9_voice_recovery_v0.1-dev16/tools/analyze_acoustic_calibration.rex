numeric digits 30
parse arg fcPath fdPath chunkStart outPrefix provenance maxCharacters maxTracks maxFamilyComparisons maxVoiceFamilies
if outPrefix='' then do
  say 'usage: analyze_acoustic_calibration.rex FC.f32 FD.f32 CHUNK_START_SERIAL OUT_PREFIX [PROVENANCE] [MAX_CHARACTERS] [MAX_TRACKS] [MAX_FAMILY_COMPARISONS] [MAX_VOICE_FAMILIES]'
  exit 2
end
if maxCharacters='' then maxCharacters=3000
if maxTracks='' then maxTracks=1600
if maxFamilyComparisons='' then maxFamilyComparisons=50000
if maxVoiceFamilies='' then maxVoiceFamilies=48
maxCharacters=maxCharacters+0; maxTracks=maxTracks+0; maxFamilyComparisons=maxFamilyComparisons+0; maxVoiceFamilies=maxVoiceFamilies+0
root=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT'); if root='' then root='.'
policy=.AudioV9SpectralFieldPolicy~new(120,3800,240,120,256,.60,.90,1000,500,2)
bridge=root||'/run/runtime/audio_v9_pattern_locator_v0.1-dev5-hotfix1/native/av9_pattern.bridge.json'
spectral=.AudioV9NativeProvider~new(bridge)
say 'STAGE spectral'; fcField=spectral~spectralField(fcPath,policy); fdField=spectral~spectralField(fdPath,policy)
boxer=.AudioV9SpectralBoxAnalyzer~new(policy)
say 'STAGE boxes'; fcBoxes=boxer~build(fcField,1000,500); fdBoxes=boxer~build(fdField,1000,500)
spatial=.AudioV9SpatialNativeProvider~new(root||'/run/native/av9_spatial.bridge.json')
say 'STAGE spatial'; scan=spatial~scan(fcPath,fdPath,8000,8000,4000,500,25)
assembler=.AudioV9AcousticCharacterAssembler~new(4000)
fc=assembler~assemble(fcBoxes,scan,(chunkStart+0)*1000,'FC'); fd=assembler~assemble(fdBoxes,scan,(chunkStart+0)*1000,'FD')
chars=.array~new; do x over fc; chars~append(x); end; do x over fd; chars~append(x); end
if chars~items>maxCharacters then do
  say 'FAIL CALIBRATION_COMPLEXITY_EXCEEDED characters='||chars~items||' limit='||maxCharacters
  exit 75
end
say 'STAGE tracks characters='||chars~items; tracks=.AudioV9TrackBuilder~new(.AudioV9AcousticCharacterSchema~new,750,1,36)~build(chars)
if tracks~items>maxTracks then do
  say 'FAIL CALIBRATION_COMPLEXITY_EXCEEDED tracks='||tracks~items||' limit='||maxTracks
  exit 75
end
clusterer=.AudioV9SourceFamilyClusterer~new(28,120)
say 'STAGE families tracks='||tracks~items||' budget='||maxFamilyComparisons; families=clusterer~cluster(tracks,maxFamilyComparisons)
say 'STAGE speakers families='||families~items||' limit='||maxVoiceFamilies; speakers=.AudioV9CalibrationDiarizer~new~cluster(families,.45,maxVoiceFamilies)
analysis=.AudioV9AcousticAnalysis~new(chars,tracks,families,speakers)
files=analysis~write(outPrefix)
say 'PASS calibration acoustic characters='||chars~items||' tracks='||tracks~items||' families='||families~items||' speakers='||speakers~items||' files='||files~items
exit 0
::requires 'AudioV9CalibrationAcoustic.cls'
::requires 'AudioV9NativeProvider.cls'
