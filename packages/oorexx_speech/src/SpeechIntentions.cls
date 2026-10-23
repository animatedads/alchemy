/* SpeechIntentions.cls
 * Dynamic intention discovery for ooRexx Speech v0.1-dev11.
 *
 * Discovery is deliberately live.  No permanent action catalogue is cached.
 * Every discover() call re-reads the current SpeechRuntime channel objects,
 * their state and their provider identity.  The caller keeps the authoritative
 * channel objects; intention candidates retain those exact objects rather than
 * reconstructing them from IDs.
 */

::class SpeechIntentionBuild public
::constant VERSION "0.1-dev11"
::constant API "oorexx.speech.intentions/0.1"

::class SpeechIntentionState public
::constant AVAILABLE "AVAILABLE"
::constant BUSY "BUSY"
::constant UNAVAILABLE "UNAVAILABLE"

::class SpeechIntentionCandidate public
::attribute intentionId get
::attribute meaning get
::attribute featureKind get
::attribute target get
::attribute state get
::attribute reason get
::attribute evidence get
::method init
  expose intentionId meaning featureKind target state reason evidence
  use strict arg intentionIdArg, meaningArg, featureKindArg, targetArg=.nil, stateArg="AVAILABLE", reasonArg="", evidenceArg=.nil
  intentionId=intentionIdArg~string
  meaning=meaningArg~string
  featureKind=featureKindArg~string~upper
  target=targetArg
  state=stateArg~string~upper
  reason=reasonArg~string
  evidence=.array~new
  if evidenceArg<>.nil then do item over evidenceArg; evidence~append(item); end

::method available
  expose state
  return state=.SpeechIntentionState~AVAILABLE

::class SpeechIntentionDiscovery public
::attribute generation get
::attribute runtime get
::attribute intentions get
::method init
  expose generation runtime intentions
  use strict arg generationArg, runtimeArg
  generation=generationArg
  runtime=runtimeArg
  intentions=.array~new

::method add
  expose intentions
  use strict arg candidate
  if candidate<>.nil then intentions~append(candidate)
  return candidate

::method count
  expose intentions
  return intentions~items

::method byId
  expose intentions
  use strict arg idArg
  wanted=idArg~string
  do candidate over intentions
    if candidate~intentionId=wanted then return candidate
  end
  return .nil

::method byFeature
  expose intentions
  use strict arg featureArg
  wanted=featureArg~string~upper
  answer=.array~new
  do candidate over intentions
    if candidate~featureKind=wanted then answer~append(candidate)
  end
  return answer

::class SpeechIntentionProvider public
::attribute generation get
::method init
  expose generation
  generation=0

/* Fresh discovery over the current runtime.  A channel added, removed or made
 * busy changes the very next result. */
::method discover
  expose generation
  use strict arg runtime
  if runtime==.nil then raise syntax 88.900 array("SpeechRuntime is required")
  generation+=1
  snapshot=.SpeechIntentionDiscovery~new(generation,runtime)

  ttsAvailable=.array~new
  sttAvailable=.array~new
  ids=runtime~channelIds
  do id over ids
    channel=runtime~channel(id)
    if channel==.nil then iterate
    kind=self~channelKind(channel)
    if kind="TTS" then do
      candidate=self~ttsCandidate(channel)
      snapshot~add(candidate)
      if candidate~available then ttsAvailable~append(channel)
    end
    else if kind="STT" then do
      candidate=self~sttCandidate(channel)
      snapshot~add(candidate)
      if candidate~available then sttAvailable~append(channel)
    end
  end

  /* Duplex is a composition possibility discovered from what is live now. */
  if ttsAvailable~items>0 then if sttAvailable~items>0 then do
    evidence=.array~new
    do channel over ttsAvailable; evidence~append(channel); end
    do channel over sttAvailable; evidence~append(channel); end
    snapshot~add(.SpeechIntentionCandidate~new(
      "speech.duplex.session",
      "run concurrent text-to-speech and speech-to-text over independently owned lanes",
      "DUPLEX_SESSION",
      runtime,
      .SpeechIntentionState~AVAILABLE,
      "",
      evidence))
  end

  return snapshot

::method ttsCandidate
  use strict arg channel
  state=self~channelState(channel)
  evidence=.array~of(channel)
  if state="IDLE" then return .SpeechIntentionCandidate~new(
    "speech.tts.channel."||channel~channelId,
    "synthesize speech on the current TTS channel",
    "TTS",
    channel,
    .SpeechIntentionState~AVAILABLE,
    "",
    evidence)
  return .SpeechIntentionCandidate~new(
    "speech.tts.channel."||channel~channelId,
    "synthesize speech on the current TTS channel",
    "TTS",
    channel,
    .SpeechIntentionState~BUSY,
    "channel state is "||state,
    evidence)

::method sttCandidate
  use strict arg channel
  state=self~channelState(channel)
  evidence=.array~of(channel)
  if state="IDLE" then return .SpeechIntentionCandidate~new(
    "speech.stt.channel."||channel~channelId,
    "recognize speech on the current STT channel",
    "STT",
    channel,
    .SpeechIntentionState~AVAILABLE,
    "",
    evidence)
  return .SpeechIntentionCandidate~new(
    "speech.stt.channel."||channel~channelId,
    "recognize speech on the current STT channel",
    "STT",
    channel,
    .SpeechIntentionState~BUSY,
    "channel state is "||state,
    evidence)

::method channelKind
  use strict arg channel
  if channel~isA(.SpeechTTSChannel) then return "TTS"
  if channel~isA(.SpeechSTTChannel) then return "STT"
  return "OTHER"

::method channelState
  use strict arg channel
  if channel~hasMethod("STATE") then return channel~state~string~upper
  return "UNKNOWN"

::requires 'SpeechChannels.cls'
