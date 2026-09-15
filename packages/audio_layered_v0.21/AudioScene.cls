/* AudioScene.cls - cross-recording acoustic scene membership and timeline mapping v0.14 */

::class AudioSceneMember public
::attribute recordingId
::attribute mountId
::attribute role
::attribute orientation
::attribute attributes

::method init
  use strict arg recordingId, mountId = '', role = '', orientation = '', attributes = .nil
  if attributes == .nil then attributes = .Directory~new
  self~recordingId = recordingId~string
  self~mountId = mountId~string
  self~role = role~string
  self~orientation = orientation~string
  self~attributes = .AudioUtil~copyDirectory(attributes)

::method canonicalText
  return 'SCENE_MEMBER=' || self~recordingId || '|mount=' || self~mountId || '|role=' || self~role || '|orientation=' || self~orientation || '|attributes=' || .AudioUtil~canonicalDirectory(self~attributes)


::class AudioSceneTimeMap public
::attribute id
::attribute recordingId
::attribute localAnchorMs
::attribute sceneAnchorMs
::attribute scale
::attribute confidence
::attribute method
::attribute attributes

::method init
  use strict arg id, recordingId, localAnchorMs = 0, sceneAnchorMs = 0, scale = 1, confidence = 0, method = '', attributes = .nil
  if attributes == .nil then attributes = .Directory~new
  if \datatype(localAnchorMs,'N') | \datatype(sceneAnchorMs,'N') | \datatype(scale,'N') then raise syntax 88.900 array('AudioSceneTimeMap numeric fields are required')
  if scale <= 0 then raise syntax 88.900 array('AudioSceneTimeMap scale must be positive')
  self~id = id~string
  self~recordingId = recordingId~string
  self~localAnchorMs = localAnchorMs
  self~sceneAnchorMs = sceneAnchorMs
  self~scale = scale
  self~confidence = confidence
  self~method = method~string
  self~attributes = .AudioUtil~copyDirectory(attributes)

::method localToScene
  use strict arg localMs
  return self~sceneAnchorMs + (localMs-self~localAnchorMs)*self~scale

::method sceneToLocal
  use strict arg sceneMs
  return self~localAnchorMs + (sceneMs-self~sceneAnchorMs)/self~scale

::method offsetAtLocal
  use strict arg localMs
  return self~localToScene(localMs)-localMs

::method driftPpm
  return (self~scale-1)*1000000

::method canonicalText
  return 'SCENE_TIME_MAP=' || self~id || '|recording=' || self~recordingId || '|localAnchorMs=' || self~localAnchorMs || '|sceneAnchorMs=' || self~sceneAnchorMs || '|scale=' || self~scale || '|driftPpm=' || self~driftPpm || '|confidence=' || self~confidence || '|method=' || self~method || '|attributes=' || .AudioUtil~canonicalDirectory(self~attributes)


::class AudioSceneAlignmentEvidence public
::attribute id
::attribute recordingAId
::attribute recordingBId
::attribute localAStartMs
::attribute localAEndMs
::attribute localBStartMs
::attribute localBEndMs
::attribute estimatedOffsetMs
::attribute score
::attribute method
::attribute confidence
::attribute attributes

::method init
  use strict arg id, recordingAId, recordingBId, localAStartMs, localAEndMs, localBStartMs, localBEndMs, estimatedOffsetMs, score = 0, method = '', confidence = 0, attributes = .nil
  if attributes == .nil then attributes = .Directory~new
  if localAEndMs < localAStartMs | localBEndMs < localBStartMs then raise syntax 88.900 array('AudioSceneAlignmentEvidence end precedes start')
  self~id = id~string
  self~recordingAId = recordingAId~string
  self~recordingBId = recordingBId~string
  self~localAStartMs = localAStartMs
  self~localAEndMs = localAEndMs
  self~localBStartMs = localBStartMs
  self~localBEndMs = localBEndMs
  self~estimatedOffsetMs = estimatedOffsetMs
  self~score = score
  self~method = method~string
  self~confidence = confidence
  self~attributes = .AudioUtil~copyDirectory(attributes)

::method canonicalText
  return 'SCENE_ALIGNMENT_EVIDENCE=' || self~id || '|a=' || self~recordingAId || ':' || self~localAStartMs || '-' || self~localAEndMs || '|b=' || self~recordingBId || ':' || self~localBStartMs || '-' || self~localBEndMs || '|offsetMs=' || self~estimatedOffsetMs || '|score=' || self~score || '|method=' || self~method || '|confidence=' || self~confidence || '|attributes=' || .AudioUtil~canonicalDirectory(self~attributes)


::class AudioSceneCutMember public
::attribute recordingId
::attribute sceneStartMs
::attribute sceneEndMs
::attribute requestedLocalStartMs
::attribute requestedLocalEndMs
::attribute clippedLocalStartMs
::attribute clippedLocalEndMs
::attribute sceneClippedStartMs
::attribute sceneClippedEndMs
::attribute localCut
::attribute timeMapId

::method init
  use strict arg recording, timeMap, sceneStartMs, sceneEndMs, viewIds = .nil
  self~recordingId = recording~id
  self~sceneStartMs = sceneStartMs
  self~sceneEndMs = sceneEndMs
  self~timeMapId = timeMap~id
  self~requestedLocalStartMs = timeMap~sceneToLocal(sceneStartMs)
  self~requestedLocalEndMs = timeMap~sceneToLocal(sceneEndMs)
  ls = max(0, self~requestedLocalStartMs)
  le = min(recording~durationMs, self~requestedLocalEndMs)
  if le <= ls then do
    self~clippedLocalStartMs = ls
    self~clippedLocalEndMs = ls
    self~sceneClippedStartMs = timeMap~localToScene(ls)
    self~sceneClippedEndMs = self~sceneClippedStartMs
    self~localCut = .nil
    return
  end
  self~clippedLocalStartMs = ls
  self~clippedLocalEndMs = le
  self~sceneClippedStartMs = timeMap~localToScene(ls)
  self~sceneClippedEndMs = timeMap~localToScene(le)
  self~localCut = recording~throughCut(ls, le, viewIds)

::method present
  return self~localCut \== .nil

::method canonicalText
  return 'SCENE_CUT_MEMBER=' || self~recordingId || '|map=' || self~timeMapId || '|scene=' || self~sceneStartMs || '-' || self~sceneEndMs || '|requestedLocal=' || self~requestedLocalStartMs || '-' || self~requestedLocalEndMs || '|clippedLocal=' || self~clippedLocalStartMs || '-' || self~clippedLocalEndMs || '|sceneClipped=' || self~sceneClippedStartMs || '-' || self~sceneClippedEndMs || '|present=' || self~present


::class AudioSceneThroughCut public
::attribute sceneId
::attribute startMs
::attribute endMs

::method init
  expose members
  use strict arg sceneId, startMs, endMs
  if endMs < startMs then raise syntax 88.900 array('Audio scene cut end precedes start')
  self~sceneId = sceneId
  self~startMs = startMs
  self~endMs = endMs
  members = .Directory~new

::method addMember
  expose members
  use strict arg memberCut
  members[memberCut~recordingId] = memberCut

::method member
  expose members
  use strict arg recordingId
  if members~hasIndex(recordingId) then return members[recordingId]
  return .nil

::method members
  expose members
  return .AudioUtil~copyDirectory(members)

::method memberCount
  expose members
  return members~items


::class AudioScene public
::attribute id
::attribute description
::attribute attributes

::method init
  expose recordings members timeMaps alignmentEvidence
  use strict arg id, description = '', attributes = .nil
  if attributes == .nil then attributes = .Directory~new
  self~id = id~string
  self~description = description~string
  self~attributes = .AudioUtil~copyDirectory(attributes)
  recordings = .Directory~new
  members = .Directory~new
  timeMaps = .Directory~new
  alignmentEvidence = .Array~new

::method addRecording
  expose recordings members
  use strict arg recording, mountId = '', role = '', orientation = '', attributes = .nil
  if \recording~isa(.AudioRecording) then raise syntax 88.900 array('AudioScene requires AudioRecording members')
  recordings[recording~id] = recording
  members[recording~id] = .AudioSceneMember~new(recording~id, mountId, role, orientation, attributes)
  return members[recording~id]

::method addTimeMap
  expose recordings timeMaps
  use strict arg timeMap
  if \timeMap~isa(.AudioSceneTimeMap) then raise syntax 88.900 array('AudioScene requires AudioSceneTimeMap')
  if \recordings~hasIndex(timeMap~recordingId) then raise syntax 88.900 array('AudioSceneTimeMap references unknown recording')
  timeMaps[timeMap~recordingId] = timeMap
  return timeMap

::method createTimeMap
  use strict arg id, recordingId, localAnchorMs = 0, sceneAnchorMs = 0, scale = 1, confidence = 0, method = '', attributes = .nil
  tm = .AudioSceneTimeMap~new(id, recordingId, localAnchorMs, sceneAnchorMs, scale, confidence, method, attributes)
  self~addTimeMap(tm)
  return tm

::method timeMap
  expose timeMaps
  use strict arg recordingId
  if timeMaps~hasIndex(recordingId) then return timeMaps[recordingId]
  return .nil

::method addAlignmentEvidence
  expose recordings alignmentEvidence
  use strict arg evidence
  if \evidence~isa(.AudioSceneAlignmentEvidence) then raise syntax 88.900 array('AudioScene requires AudioSceneAlignmentEvidence')
  if \recordings~hasIndex(evidence~recordingAId) | \recordings~hasIndex(evidence~recordingBId) then raise syntax 88.900 array('Alignment evidence references unknown recording')
  alignmentEvidence~append(evidence)
  return alignmentEvidence~items

::method alignmentEvidence
  expose alignmentEvidence
  return .AudioUtil~copyArray(alignmentEvidence)

::method throughCut
  expose recordings timeMaps
  use strict arg sceneStartMs, sceneEndMs, viewIds = .nil
  cut = .AudioSceneThroughCut~new(self~id, sceneStartMs, sceneEndMs)
  ids = .Array~new
  s = recordings~supplier
  do while s~available
    ids~append(s~index)
    s~next
  end
  ids~sort
  do recordingId over ids
    if \timeMaps~hasIndex(recordingId) then iterate
    mc = .AudioSceneCutMember~new(recordings[recordingId], timeMaps[recordingId], sceneStartMs, sceneEndMs, viewIds)
    if mc~present then cut~addMember(mc)
  end
  return cut

::method canonicalText
  expose members timeMaps alignmentEvidence
  lines = .Array~new
  lines~append('AUDIO_SCENE=' || self~id || '|description=' || self~description || '|attributes=' || .AudioUtil~canonicalDirectory(self~attributes))
  mlines=.Array~new
  ms=members~supplier
  do while ms~available
    mlines~append(ms~item~canonicalText)
    ms~next
  end
  mlines~sort; do l over mlines; lines~append(l); end
  tlines=.Array~new
  ts=timeMaps~supplier
  do while ts~available
    tlines~append(ts~item~canonicalText)
    ts~next
  end
  tlines~sort; do l over tlines; lines~append(l); end
  elines=.Array~new
  do e over alignmentEvidence
    elines~append(e~canonicalText)
  end
  elines~sort; do l over elines; lines~append(l); end
  return lines~makeString('L')

::requires 'AudioCore.cls'
