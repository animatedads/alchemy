/*
 * Semantic Source Examiner intentions for Intention Service v0.1-dev11.
 *
 * Intent semantics are registered once; operational availability is discovered
 * afresh by IntentionService before every new input.  The discovery provider
 * asks its capability source for current action surfaces, so branch state,
 * authority, provider availability and future capabilities do not become a
 * permanent static command catalogue.
 */

::class SemanticSourceIntentionCapabilitySource public
::method init
  use strict arg examiner, revisionProvider = .nil
  self~examiner = examiner
  self~revisionProvider = revisionProvider
::attribute examiner get
::attribute examiner set private
::attribute revisionProvider get
::attribute revisionProvider set private

::method discoverExaminerActions
  use arg context = .nil
  -- Examiner action vocabulary is semantic; operational permission remains in
  -- SecureExaminer/Access Permissions at dispatch time.
  return self~examiner~intentionDefinitions(context)

::method discoveryRevision
  use arg context = .nil
  if self~revisionProvider \= .nil then return self~revisionProvider~revision(context)
  return "examiner-intentions/1"

::class SemanticSourceIntentionDiscoveryProvider public
::method init
  use strict arg capabilitySource
  if capabilitySource == .nil then raise syntax 93.900 array("semantic-source capability source is required")
  self~capabilitySource = capabilitySource
::attribute capabilitySource get
::attribute capabilitySource set private

::method discover
  use strict arg service
  definitions = self~capabilitySource~discoverExaminerActions(.nil)
  revision = self~capabilitySource~discoveryRevision(.nil)
  snapshot = .IntentionDiscoverySnapshot~new("SEMANTIC_SOURCE_EXAMINER", revision)
  do definition over definitions
    provider = .SemanticSourceIntentionSurfaceProvider~new(definition)
    metadata = .directory~new
    metadata["ACTION"] = definition["action"]
    metadata["PHRASE"] = definition["phrase"]
    metadata["SIDE_EFFECT"] = definition["side_effect"]
    advertisement = .IntentionSurfaceAdvertisement~new( -
      "SSC." || translate(definition["action"]), provider, definition["action"], -
      "EXAMINER_ACTION", "SEMANTIC_SOURCE", "DISCOVERY", "AUTHORITATIVE_ACTION_GATE", metadata)
    snapshot~addSurfaceAdvertisement(advertisement)
  end
  return snapshot

::class SemanticSourceIntentionSurfaceProvider public
::method init
  use strict arg definition
  self~definition = definition
::attribute definition get
::attribute definition set private

::method propose
  use strict arg service, text
  d = self~definition
  score = self~matchScore(text, d)
  if score = 0 then return .array~new
  proposal = .IntentionProposal~new(d["intention_id"], score, "SEMANTIC_SOURCE_DISCOVERY", .true, "current Examiner semantic surface")
  proposal~putSlot("ACTION", d["action"], .true)
  return .array~of(proposal)

::method matchScore private
  use strict arg text, definition
  input = translate(space(text))
  aliases = definition["aliases"]
  best = 0
  do alias over aliases
    wanted = translate(space(alias))
    if wanted = "" then iterate
    if input = wanted then return 100
    if input~pos(wanted) > 0 then best = max(best, 92)
    else do
      words = wanted~words
      hits = 0
      do i = 1 to words
        if input~wordpos(wanted~word(i)) > 0 then hits += 1
      end
      if hits = words & words > 0 then best = max(best, 80)
    end
  end
  return best

/* Install all semantic meanings, while discovery controls which are currently
 * advertised.  IntentionService still owns ambiguity, clarification, evidence
 * and policy evaluation. */
::class SemanticSourceIntentionInstaller public
::method install
  use strict arg service, examiner
  definitions = examiner~intentionDefinitions(.nil)
  do definition over definitions
    registration = service~register(definition["phrase"], definition["action"])
    aliases = definition["aliases"]
    do alias over aliases
      if translate(alias) \= translate(definition["phrase"]) then registration~alias(alias)
    end
    registration~semantics(definition["verbs"], definition["nouns"])
    registration~tag("SPHERE", "SEMANTIC_SOURCE")
    registration~tag("ACTION", definition["action"])
    registration~tag("SIDE_EFFECT", definition["side_effect"])
    definition["intention_id"] = registration~id
  end
  provider = .SemanticSourceIntentionDiscoveryProvider~new(.SemanticSourceIntentionCapabilitySource~new(examiner))
  service~registerDiscoveryProvider(provider)
  return provider

::requires "IntentionService.cls"
::requires "IntentionContext.cls"
