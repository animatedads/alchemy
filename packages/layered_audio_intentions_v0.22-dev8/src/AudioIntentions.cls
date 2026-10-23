/* AudioIntentions.cls
 * Layered Audio dynamic intention discovery v0.22-dev8.
 *
 * Audio owns Audio truth.  This provider observes live Audio objects and
 * presents the semantic surfaces that exist at this moment.  It does not
 * retain a static action catalogue, copy Audio state into a second model, or
 * flatten candidate objects to strings.
 */

::class AudioIntentionBuild public
::constant VERSION "0.22-dev8"
::constant API "audio.intentions/0.8"

::class AudioIntentionState public
::constant AVAILABLE "AVAILABLE"
::constant CLARIFY "CLARIFY"
::constant UNAVAILABLE "UNAVAILABLE"

::class AudioIntentionEvidence public
::attribute kind get
::attribute object get
::attribute detail get
::method init
  expose kind object detail
  use strict arg kindArg, objectArg=.nil, detailArg=""
  kind=kindArg~string
  object=objectArg
  detail=detailArg~string

::class AudioIntentionCandidate public
::attribute intentionId get
::attribute meaning get
::attribute featureKind get
::attribute target get
::attribute candidates get
::attribute evidence get
::attribute requiredSlots get
::attribute state get
::attribute reason get
::method init
  expose intentionId meaning featureKind target candidates evidence requiredSlots state reason
  use strict arg intentionIdArg, meaningArg, featureKindArg, targetArg=.nil, candidatesArg=.nil, evidenceArg=.nil, requiredSlotsArg=.nil, stateArg="AVAILABLE", reasonArg=""
  intentionId=intentionIdArg~string
  meaning=meaningArg~string
  featureKind=featureKindArg~string
  target=targetArg
  candidates=self~copyArray(candidatesArg)
  evidence=self~copyArray(evidenceArg)
  requiredSlots=self~copyArray(requiredSlotsArg)
  state=stateArg~string~upper
  reason=reasonArg~string

::method ambiguous
  expose candidates state
  return state=.AudioIntentionState~CLARIFY | candidates~items>1

::method selectable
  expose state
  return state=.AudioIntentionState~AVAILABLE | state=.AudioIntentionState~CLARIFY

::method copyArray
  use strict arg source
  answer=.array~new
  if source==.nil then return answer
  do item over source
    answer~append(item)
  end
  return answer

::class AudioIntentionDiscovery public
::attribute generation get
::attribute target get
::attribute intentions get
::attribute evidence get
::method init
  expose generation target intentions evidence
  use strict arg generationArg, targetArg
  generation=generationArg~string
  target=targetArg
  intentions=.array~new
  evidence=.array~new

::method add
  expose intentions
  use strict arg candidate
  if candidate<>.nil then intentions~append(candidate)
  return candidate

::method addEvidence
  expose evidence
  use strict arg item
  if item<>.nil then evidence~append(item)
  return item

::method count
  expose intentions
  return intentions~items

::method byFeature
  expose intentions
  use strict arg featureArg
  wanted=featureArg~string~upper
  answer=.array~new
  do candidate over intentions
    if candidate~featureKind~upper=wanted then answer~append(candidate)
  end
  return answer

::method byId
  expose intentions
  use strict arg idArg
  wanted=idArg~string
  do candidate over intentions
    if candidate~intentionId=wanted then return candidate
  end
  return .nil

/* The context carries other authoritative live objects, not serialized copies.
 * recording is optional because a view/element can be discovered independently.
 * storageBindings may be either a Directory keyed by element id or an
 * AudioStorageRecordingBindings-like object exposing ids() and binding(id).
 */
::class AudioIntentionContext public
::attribute authority get
::attribute feasibility get
::attribute storageBindings get
::attribute attributes get
::attribute recording get
::attribute objects get
::method init
  expose authority feasibility storageBindings attributes recording objects
  use strict arg authorityArg=.nil, feasibilityArg=.nil, storageBindingsArg=.nil, attributesArg=.nil, recordingArg=.nil, objectsArg=.nil
  authority=authorityArg
  feasibility=feasibilityArg
  storageBindings=storageBindingsArg
  if storageBindings==.nil then storageBindings=.directory~new
  attributes=attributesArg
  if attributes==.nil then attributes=.directory~new
  recording=recordingArg
  objects=.array~new
  if objectsArg<>.nil then do object over objectsArg; objects~append(object); end

::method addObject
  expose objects
  use strict arg object
  if object<>.nil then objects~append(object)
  return object

::method storageBinding
  expose storageBindings
  use strict arg elementId
  if storageBindings==.nil then return .nil
  if storageBindings~isa(.Directory) then do
    if storageBindings~hasIndex(elementId) then return storageBindings[elementId]
    return .nil
  end
  if storageBindings~hasMethod("BINDING") then return storageBindings~binding(elementId)
  return .nil

/* A resolved cross-feature selection is deliberately an object graph, not a
 * string plan.  It retains the authoritative Audio objects selected from one
 * discovery generation and, where present, the Storage binding object. */
::class AudioIntentionCompositeSelection public
::attribute generation get
::attribute recording get
::attribute element get
::attribute view get
::attribute featureKind get
::attribute boundaries get
::attribute storageBinding get

/* A resolved selection remains an object-capable semantic target.  Creating a
 * surface does not freeze the derived evidence around it; each discover/propose
 * call re-reads the recording, view and element relationships. */
::method surface
  use strict arg provider, context=.nil
  if provider==.nil then raise syntax 88.900 array("AudioIntentionProvider is required")
  return provider~surface(self,context)

::method init
  expose generation recording element view featureKind boundaries storageBinding
  use strict arg generationArg, recordingArg, elementArg=.nil, viewArg=.nil, featureKindArg="", boundariesArg=.nil, storageBindingArg=.nil
  generation=generationArg
  recording=recordingArg
  element=elementArg
  view=viewArg
  featureKind=featureKindArg~string~upper
  boundaries=.array~new
  if boundariesArg<>.nil then do boundary over boundariesArg; boundaries~append(boundary); end
  storageBinding=storageBindingArg

::class AudioIntentionCompositeProposal public
::attribute generation get
::attribute status get
::attribute question get
::attribute discovery get
::attribute selection get
::attribute choices get
::attribute reason get
::method init
  expose generation status question discovery selection choices reason
  use strict arg discoveryArg, statusArg, reasonArg="", questionArg="", selectionArg=.nil, choicesArg=.nil
  discovery=discoveryArg
  generation=discoveryArg~generation
  status=statusArg~string~upper
  reason=reasonArg~string
  question=questionArg~string
  selection=selectionArg
  choices=.array~new
  if choicesArg<>.nil then do choice over choicesArg; choices~append(choice); end

::method ready
  expose status
  return status="READY"

/* Adapter for Intention Service typed-slot proposals.  It depends only on the
 * proposal's public slot(name) contract and therefore does not vendor or
 * reimplement Intention Service. */
::class AudioIntentionServiceBridge public
::method resolve
  use strict arg provider, recording, intentionProposal, context=.nil
  if provider==.nil then raise syntax 88.900 array("AudioIntentionProvider is required")
  if intentionProposal==.nil then raise syntax 88.900 array("Intention proposal is required")
  if \intentionProposal~hasMethod("SL