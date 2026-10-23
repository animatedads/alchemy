/* AudioIntentionServiceIntegration.cls
 * Layered Audio v0.22-dev8 bridge to Intention Service v0.1-dev11.
 *
 * Audio publishes one transient Intention Service surface per current live
 * Audio object.  Advertisements carry the original ooRexx object in
 * sourceObject; they are not names, paths or reconstructed DTOs.  A staged
 * request is scoped to the exact object selected by the caller and is resolved
 * again both when proposed and when dispatched.
 */

::class AudioIntentionServiceIntegrationBuild public
::constant VERSION "0.22-dev8"
::constant API "audio.intentions.intention-service/0.4"

::class AudioIntentionServiceInstaller public
::constant PHRASE "audio object selection"

::method install class
  use strict arg service, audioProvider, recording, context=.nil, bucketName="LAYERED_AUDIO"
  if service==.nil then raise syntax 88.900 array("IntentionService is required")
  if audioProvider==.nil then raise syntax 88.900 array("AudioIntentionProvider is required")
  if recording==.nil then raise syntax 88.900 array("AudioRecording is required")
  if service~bucket(bucketName)==.nil then service~registerBucket(bucketName,.IntentionBucketPolicy~new("FLEXIBLE",50,8,.false,.false))
  registration=service~registration("AUDIO_OBJECT_SELECTION")
  structured=.AudioIntentionServiceStructuredProvider~new(audioProvider,recording,context)
  if registration==.nil then do
    event=.AudioIntentionServiceEvent~new(audioProvider,recording,context)
    registration=service~register(self~PHRASE,event,bucketName)
    registration~tag("DOMAIN","LAYERED_AUDIO")
    registration~tag("DYNAMIC_SURFACE",.true)
    registration~tag("OBJECT_PRESERVING",.true)
    registration~tag("TRANSIENT_OBJECT_SURFACES",.true)
  end
  discovery=.AudioIntentionServiceDiscoveryProvider~new(audioProvider,recording,context,structured)
  service~registerDiscoveryProvider(discovery)
  return discovery

::class AudioIntentionServiceDiscoveryProvider public
::method init
  expose audioProvider recording context structured
  use strict arg audioProvider, recording, context=.nil, structured=.nil
  if structured==.nil then structured=.AudioIntentionServiceStructuredProvider~new(audioProvider,recording,context)

::attribute structured get

::method discover
  expose audioProvider recording context structured
  use strict arg service
  discovery=audioProvider~discover(recording,context)
  revision=self~signature(discovery,audioProvider~advertisableObjects(recording,context))
  snapshot=.IntentionDiscoverySnapshot~new("LAYERED_AUDIO",revision)
  snapshot~addEvidenceFact(.IntentionEvidenceFact~new("LAYERED_AUDIO","INTENTION_SURFACE_SIGNATURE",revision,100,"LAYERED_AUDIO","OBSERVED",revision))

  objects=audioProvider~advertisableObjects(recording,context)
  do object over objects
    surface=audioProvider~surface(object,context)
    if surface~discover~count=0 then iterate
    metadata=.directory~new
    metadata["audio_api"]=.AudioIntentionBuild~API
    metadata["object_kind"]=self~objectKind(audioProvider,object)
    metadata["object_id"]=self~objectIdentity(object)
    metadata["object_preserving"]=.true
    provider=.AudioIntentionServiceObjectSurfaceProvider~new(structured,surface)
    surfaceId="LAYERED_AUDIO."||self~safeId(metadata["object_kind"])||"."||self~safeId(metadata["object_id"])
    advertisement=.IntentionSurfaceAdvertisement~new(surfaceId,provider,object,"EXPOSES_INTENTIONS","OBJECT","DISCOVERY","OBSERVED",metadata)
    snapshot~addSurfaceAdvertisement(advertisement)
  end
  return snapshot

::method signature
  use strict arg discovery, objects
  lines=.array~new
  do candidate over discovery~intentions
    line=candidate~intentionId||"|"||candidate~featureKind||"|"||candidate~state
    ids=.array~new
    do object over candidate~candidates
      ids~append(self~objectIdentity(object))
    end
    ids~sort
    line=line||"|"||self~join(ids,",")
    lines~append(line)
  end
  do object over objects
    lines~append("OBJECT|"||self~objectKind(.AudioIntentionProvider~new,object)||"|"||self~objectIdentity(object))
  end
  lines~sort
  if lines~items=0 then return "EMPTY"
  return self~join(lines,";")

::method objectKind
  use strict arg audioProvider, object
  if audioProvider~isRecording(object) then return "RECORDING"
  if audioProvider~isElement(object) then return "ELEMENT"
  if audioProvider~isView(object) then return "VIEW"
  if audioProvider~isCompositeSelection(object) then return "SELECTION"
  return object~class~id

::method objectIdentity
  use strict arg object
  if object==.nil then return "NIL"
  if object~hasMethod("ID") then return object~id~string
  if object~hasMethod("IDENTITYKEY") then return object~identityKey~string
  return object~class~id

::method safeId
  use strict arg value
  answer=value~string~upper
  answer=changestr(" ",answer,"_")
  answer=changestr("/",answer,"_")
  answer=changestr(":",answer,"_")
  return answer

::method join
  use strict arg values, separator
  out=""; first=.true
  do value over values
    if irst then out=out||separator
    out=out||value
    first=.false
  end
  return out

::class AudioIntentionServiceObjectSurfaceProvider public
::method init
  expose structured surface
  use strict arg structuredArg, surfaceArg
  structured=structuredArg
  surface=surfaceArg

::method propose
  expose structured surface
  use strict arg service, text
  return structured~proposeOn(service,text,surface)

::class AudioIntentionServiceStructuredProvider public
::method init
  expose audioProvider recording context staged nextId
  use strict arg audioProvider, recording, context=.nil
  staged=.directory~new
  nextId=0

::method name
  return "LAYERED_AUDIO_OBJECT_SURFACE"

::method stage
  expose recording
  use strict arg criteria=.nil
  return self~stageOn(recording,criteria)

::method stageOn
  expose staged nextId
  use strict arg target, criteria=.nil
  if target==.nil then raise syntax 88.900 array("Audio intention target is required")
  if criteria==.nil then criteria=.directory~new
  if criteria~isa(.Directory) then raise syntax 88.900 array("Audio intention criteria must be a Directory")
  nextId+=1
  token="AUDIO"||nextId
  request=.AudioIntentionServiceStagedRequest~new(target,.AudioIntentionUtil~copyDirectory(criteria))
  staged[token]=request
  return "AUDIO_INTENTION "||token

::method stagedRequest
  expose staged
  use strict arg token
  key=translate(strip(token))
  if staged~hasIndex(key) then return staged[key]
  return .nil

::method stagedCriteria
  use strict arg token
  request=self~stagedRequest(token)
  if request==.nil then return .nil
  return request~criteria

::method propose
  expose audioProvider recording context
  use strict arg service, text
  return self~proposeOn(service,text,audioProvider~surface(recording,context))

::method proposeOn
  expose audioProvider recording context
  use strict arg service, text, surface
  parse upper value strip(text) with prefix token extra
  if prefix<>"AUDIO_INTENTION" then return .array~new
  if token=="" | extra<>"" then return .array~new
  request=self~stagedRequest(token)
  if request==.nil then return .array~new
  if request~target<>surface~target then return .array~new

  composite=surface~propose(request~criteria)
  if composite~ready then return .array~new
  registration=service~registration("AUDIO_OBJECT_SELECTION")
  if registration==.nil then return .array~new
  proposal=.IntentionProposal~new(registration~id,100,self~name,.true,"live object-bound Layered Audio selection")
  proposal~putSlot("AUDIO_CRITERIA",request~criteria,.true)
  proposal~putSlot("AUDIO_TARGET",request~target,.true)
  proposal~putSlot("AUDIO_PROPOSAL",composite,.true)
  proposal~putSlot("AUDIO_SELECTION",composite~selection,.true)
  proposal~putSlot("AUDIO_RECORDING",recording,.true)
  return .array~of(proposal)

::class AudioIntentionServiceStagedRequest public
::attribute target get
::attribute criteria get
::method init
  expose target criteria
  use strict arg targetArg, criteriaArg
  target=targetArg
  criteria=criteriaArg

::class AudioIntentionServiceEvent public
::method init
  expose audioProvider recording context
  use strict arg audioProvider, recording, context=.nil

::method invoke
  expose audioProvider recording context
  use strict arg decision
  slots=decision~slots
  if slots==.nil then raise syntax 88.900 array("Audio intention decision has no slots")
  if slots~hasIndex("AUDIO_CRITERIA") then raise syntax 88.900 array("Audio intention decision has no AUDIO_CRITERIA slot")
  if slots~hasIndex("AUDIO_TARGET") then raise syntax 88.900 array("Audio intention decision has no AUDIO_TARGET slot")
  criteria=slots["AUDIO_CRITERIA"]
  target=slots["AUDIO_TARGET"]
  surface=audioProvider~surface(target,context)
  composite=surface~propose(criteria)
  if composite~ready then raise syntax 88.900 array("Audio intention is no longer READY: "||composite~status||" "||composite~reason)
  return composite~selection

::requires "AudioIntentions.cls"
::requires "IntentionService.cls"
::requires "IntentionProviders.cls"
