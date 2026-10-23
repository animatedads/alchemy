/* AudioManagementIntentions.cls
 * Layered Audio v0.22-dev8 integration with Management Intention Discovery
 * v0.1-dev8.
 *
 * Management remains a discovery/router authority.  Audio owns Audio truth and
 * relevance semantics.  This adapter therefore publishes the original live
 * Audio objects and current AudioObjectIntentionSurface instances rather than
 * flattening them into a command catalogue.
 */

::class AudioManagementBuild public
::constant VERSION "0.22-dev8"
::constant API "audio.intentions.management/0.2"
::constant MANAGEMENT_API "management.intention.discovery/0.1"

::class AudioManagementSurfaceEntry public
::attribute object get
::attribute surface get
::attribute discovery get
::method init
  expose object surface discovery
  use strict arg objectArg, surfaceArg, discoveryArg
  object=objectArg
  surface=surfaceArg
  discovery=discoveryArg

::class AudioManagementSurface public
::attribute generation get
::attribute recording get
::attribute context get
::method init
  expose generation recording context entries
  use strict arg generationArg, recordingArg, contextArg=.nil
  generation=generationArg
  recording=recordingArg
  context=contextArg
  entries=.array~new
::method add
  expose entries
  use strict arg entry
  entries~append(entry)
  return entry
::method entries
  expose entries
  return entries~copy
::method objects
  expose entries
  out=.array~new
  do entry over entries
    out~append(entry~object)
  end
  return out
::method entryForObject
  expose entries
  use strict arg wanted
  do entry over entries
    if entry~object==wanted then return entry
  end
  return .nil

::class AudioManagementIntentionSource public
::method init
  expose audioProvider recording audioContext generation
  use strict arg audioProviderArg, recordingArg, audioContextArg=.nil
  if audioProviderArg==.nil then raise syntax 88.900 array("Audio management source requires AudioIntentionProvider")
  if recordingArg==.nil then raise syntax 88.900 array("Audio management source requires AudioRecording")
  audioProvider=audioProviderArg
  recording=recordingArg
  audioContext=audioContextArg
  generation=0
::method sourceId
  return "layered.audio.intentions/0.1"
::method discover
  expose audioProvider recording audioContext generation
  use strict arg context=.nil
  effective=self~effectiveContext(context,audioContext)
  generation+=1
  surfaceResult=.AudioManagementSurface~new(generation,recording,effective)
  objects=audioProvider~advertisableObjects(recording,effective)
  do object over objects
    objectSurface=audioProvider~surface(object,effective)
    discovery=objectSurface~discover
    if discovery~count>0 then surfaceResult~add(.AudioManagementSurfaceEntry~new(object,objectSurface,discovery))
  end
  return surfaceResult
::method assessRelevance
  expose audioProvider
  use strict arg request, surface, context=.nil
  if surface==.nil then return .ManagementRelevanceAssessment~new(.false,0,"audio","NO_SURFACE")
  query=request~string~lower~strip
  if query=="" then return .ManagementRelevanceAssessment~new(.false,0,"audio","EMPTY_REQUEST")
  matched=.array~new
  matchedEntries=.array~new
  strongest=0
  do entry over surface~entries
    score=self~entryScore(query,entry,audioProvider)
    if score<=0 then iterate
    strongest=max(strongest,score)
    self~appendUnique(matched,entry~object,audioProvider)
    matchedEntries~append(entry)
  end
  generic=self~genericAudioScore(query)
  if generic>strongest then do
    strongest=generic
    if generic>0 then self~appendUnique(matched,surface~recording,audioProvider)
  end
  evidence=.directory~new
  evidence["objects"]=matched
  evidence["entries"]=matchedEntries
  evidence["generation"]=surface~generation
  evidence["surface"]=surface
  if strongest>0 then return .ManagementRelevanceAssessment~new(.true,strongest,"audio","CURRENT_AUDIO_SURFACE_MATCH",evidence)
  return .ManagementRelevanceAssessment~new(.false,0,"audio","NO_AUDIO_SURFACE_MATCH",evidence)
::method effectiveContext
  use strict arg supplied, fallback
  if supplied<>.nil then return supplied
  return fallback
::method genericAudioScore
  use strict arg query
  do token over .array~of("audio","recording","sound","speech","voice","speaker","transcript","pitch","track")
    if pos(token,query)>0 then return 72
  end
  return 0
::method entryScore
  use strict arg query, entry, audioProvider
  object=entry~object
  score=0
  id=audioProvider~objectId(object)~lower
  if id<>"" then if pos(id,query)>0 then score=max(score,98)
  if object~hasMethod("DESCRIPTION") then do
    description=object~description~string~lower~strip
    if description<>"" then do
      tokens=self~significantWords(description)
      do token over tokens
        if pos(token,query)>0 then score=max(score,92)
      end
    end
  end
  if object~hasMethod("ELEMENTKIND") then do
    kind=object~elementKind~string~lower
    if kind<>"" then if pos(kind,query)>0 then score=max(score,90)
  end
  if object~hasMethod("VIEWKIND") then do
    kind=object~viewKind~string~lower
    if kind<>"" then if pos(kind,query)>0 then score=max(score,94)
  end
  do candidate over entry~discovery~intentions
    feature=candidate~featureKind~string~lower
    if feature<>"" then do
      featureText=changestr("_",feature," ")
      featureTokens=self~significantWords(featureText)
      do token over featureTokens
        if pos(token,query)>0 then score=max(score,88)
      end
    end
    meaning=candidate~meaning~string~lower
    meaningTokens=self~significantWords(meaning)
    do token over meaningTokens
      if pos(token,query)>0 then score=max(score,82)
    end
  end
  return score
::method significantWords
  use strict arg text
  out=.array~new
  normalized=translate(text," ",".,:;!?()[]{}<>/|-_+=*")
  do i=1 to words(normalized)
    token=word(normalized,i)~lower
    if token~length<4 then iterate
    if token="this" then iterate
    if token="that" then iterate
    if token="with" then iterate
    if token="from" then iterate
    if token="current" then iterate
    if token="audio" then iterate
    if token="selected" then iterate
    if token="select" then iterate
    if token="inspect" then iterate
    if token="evidence" then iterate
    out~append(token)
  end
  return out
::method appendUnique
  use strict arg output, object, audioProvider
  if object==.nil then return .false
  wanted=audioProvider~objectIdentityKey(object)
  do existing over output
    if audioProvider~objectIdentityKey(existing)==wanted then return .false
  end
  output~append(object)
  return .true

::class AudioManagementRelationshipProvider public
::method init
  expose audioProvider recording audioContext
  use strict arg audioProviderArg, recordingArg, audioContextArg=.nil
  if audioProviderArg==.nil then raise syntax 88.900 array("Audio relationship provider requires AudioIntentionProvider")
  if recordingArg==.nil then raise syntax 88.900 array("Audio relationship provider requires AudioRecording")
  audioProvider=audioProviderArg
  recording=recordingArg
  audioContext=audioContextArg
::method sourceId
  return "layered.audio.relationships/0.1"
::method discoverRelationships
  expose audioProvider recording audioContext
  use strict arg context=.nil
  effective=context
  if effective==.nil then effective=audioContext
  out=.array~new
  elements=audioProvider~liveElements(recording,effective)
  do element over elements
    out~append(.ManagementRelationship~new(self~edgeId("recording-element",recording,element,audioProvider),"CONTAINS_AUDIO_ELEMENT",recording,element,"AUDIO","live AudioRecording element inventory"))
    if element~hasMethod("PARENTIDS") then do
      parentIds=element~parentIds
      do parentId over parentIds
        parent=.nil
        if recording~hasMethod("ELEMENT") then parent=recording~element(parentId)
        if parent<>.nil then out~append(.ManagementRelationship~new(self~edgeId("derived-from",element,parent,audioProvider),"DERIVED_FROM_AUDIO_ELEMENT",element,parent,"AUDIO","AudioElement parentIds"))
      end
    end
    if effective<>.nil then if effective~hasMethod("STORAGEBINDING") then do
      binding=effective~storageBinding(audioProvider~objectId(element))
      if binding<>.nil then do
        out~append(.ManagementRelationship~new(self~edgeId("storage-binding",element,binding,audioProvider),"HAS_STORAGE_BINDING",element,binding,"AUDIO_STORAGE_BRIDGE","Audio Storage durable binding"))
        if binding~hasMethod("IDENTITY") then do
          identity=binding~identity
          if identity<>.nil then out~append(.ManagementRelationship~new(self~edgeId("storage-identity",binding,identity,audioProvider),"HAS_STORAGE_IDENTITY",binding,identity,"AUDIO_STORAGE_BRIDGE","Audio Storage identity"))
        end
      end
    end
  end
  if recording~hasMethod("VIEWS") then do
    supplier=recording~views~supplier
    do while supplier~available
      view=supplier~item
      supplier~next
      out~append(.ManagementRelationship~new(self~edgeId("recording-view",recording,view,audioProvider),"CONTAINS_AUDIO_VIEW",recording,view,"AUDIO","live AudioRecording view inventory"))
      if view~hasMethod("BOUNDARIES") then do
        viewSources=audioProvider~viewSourceElements(view~boundaries,recording)
        do source over viewSources
          out~append(.ManagementRelationship~new(self~edgeId("view-source",view,source,audioProvider),"VIEW_EVIDENCE_FROM_AUDIO_ELEMENT",view,source,"AUDIO","AudioBoundary sourceElementIds"))
        end
      end
    end
  end
  return out
::method edgeId
  use strict arg prefix, leftObject, rightObject, audioProvider
  left=self~identity(leftObject,audioProvider)
  right=self~identity(rightObject,audioProvider)
  return prefix||":"||left||":"||right
::method identity
  use strict arg object, audioProvider
  if object==.nil then return "NIL"
  if object~hasMethod("IDENTITYKEY") then return object~identityKey~string
  if object~hasMethod("ELEMENTID") then return object~elementId~string
  id=audioProvider~objectId(object)
  if id<>"" then return id
  return object~class~id

::class AudioManagementRelatedIntentionSourceProvider public
::method init
  expose audioProvider audioSource storageSource
  use strict arg audioProviderArg, audioSourceArg, storageSourceArg=.nil
  audioProvider=audioProviderArg
  audioSource=audioSourceArg
  storageSource=storageSourceArg
::method discoverSources
  expose audioProvider audioSource storageSource
  use strict arg objects, context=.nil
  out=.array~new
  if objects==.nil then return out
  do object over objects
    if self~isAudioObject(object,audioProvider) then do
      self~appendSource(out,audioSource)
      iterate
    end
    if storageSource<>.nil then if self~isStorageRelatedObject(object) then self~appendSource(out,storageSource)
  end
  return out
::method isAudioObject
  use strict arg object, audioProvider
  if object==.nil then return .false
  if audioProvider~isRecording(object) then return .true
  if audioProvider~isElement(object) then return .true
  if audioProvider~isView(object) then return .true
  if audioProvider~isCompositeSelection(object) then return .true
  return .false
::method isStorageRelatedObject
  use strict arg object
  if object==.nil then return .false
  if object~hasMethod("IDENTITY") then return .true
  if object~hasMethod("PINNEDREF") then return .true
  if object~hasMethod("IDENTITYKEY") then return .true
  return .false
::method appendSource
  use strict arg out, source
  if source==.nil then return .false
  do existing over out
    if existing==source then return .false
  end
  out~append(source)
  return .true

::class AudioManagementRegistration public
::attribute intentionSource get
::attribute relationshipSource get
::attribute relatedSourceProvider get
::attribute explorer get
::method init
  expose intentionSource relationshipSource relatedSourceProvider explorer
  use strict arg intentionSourceArg, relationshipSourceArg, relatedSourceProviderArg, explorerArg
  intentionSource=intentionSourceArg
  relationshipSource=relationshipSourceArg
  relatedSourceProvider=relatedSourceProviderArg
  explorer=explorerArg

::class AudioManagementInstaller public
::method install class
  use strict arg intentionDirectory, relationshipDirectory, audioProvider, recording, audioContext=.nil, storageSource=.nil
  if intentionDirectory==.nil then raise syntax 88.900 array("Audio Management installer requires ManagementIntentionDirectory")
  if relationshipDirectory==.nil then raise syntax 88.900 array("Audio Management installer requires ManagementRelationshipDirectory")
  if audioProvider==.nil then raise syntax 88.900 array("Audio Management installer requires AudioIntentionProvider")
  if recording==.nil then raise syntax 88.900 array("Audio Management installer requires AudioRecording")
  domainProvider=.AudioManagementIntentionSource~new(audioProvider,recording,audioContext)
  intentionSource=.ManagementSelfAssessingIntentionSurfaceSource~new(domainProvider~sourceId,domainProvider)
  intentionDirectory~registerSource(intentionSource)
  relationshipProvider=.AudioManagementRelationshipProvider~new(audioProvider,recording,audioContext)
  relationshipSource=.ManagementRelationshipProviderSource~new(relationshipProvider~sourceId,relationshipProvider)
  relationshipDirectory~registerSource(relationshipSource)
  relatedProvider=.AudioManagementRelatedIntentionSourceProvider~new(audioProvider,intentionSource,storageSource)
  relatedDiscovery=.ManagementRelatedSurfaceDiscovery~new(relatedProvider)
  explorer=.ManagementIntentionExplorer~new(intentionDirectory,relationshipDirectory,relatedDiscovery)
  return .AudioManagementRegistration~new(intentionSource,relationshipSource,relatedProvider,explorer)

::requires "AudioIntentions.cls"
::requires "ManagementIntentionDiscovery.cls"
