/*
 * Semantic Source Control write-side intentions for Intention Service.
 *
 * The twin of the Examiner's SemanticSourceIntentionService, for the write authority
 * (import / accept / propose-edit). Intent meanings are registered once; operational
 * FEASIBILITY is discovered afresh every turn from live store state, so "accept the
 * import" is advertised only while an import is actually pending acceptance. Meaning and
 * feasibility are separate (an understood-but-impossible action is INFEASIBLE, not UNKNOWN),
 * exactly as the Scotty "Computer" front end and the NotNotes dynamic-discovery pattern require.
 *
 * Resolution and READY-gating stay in IntentionService; the repository authorizer still
 * gates acceptance at dispatch. A refused intention is never a bypass of the MCP authority.
 *
 * Author: Claude (Opus 4.8), 2026-10-24. Architecture: Tom Dyer.
 * Lives outside the backend-neutral store core and the store package itself; it depends only
 * on the store's public classes (repository read methods, MCP operations).
 */

/* -------------------------------------------------------------- vocabulary */

::class SemanticSourceWriteIntentionCatalog public
/* The write vocabulary. Shape matches the Examiner's intentionDefinitions:
 * action, phrase, aliases, verbs, nouns, side_effect (+ intention_id filled at register). */
::method definitions class
  defs = .array~new
  defs~append(self~def("accept_import", "accept the import", -
    .array~of("accept the import", "accept import", "approve the import", "accept the pending import", "approve the pending import"), -
    "accept approve", "import revisions", "ACCEPT_WRITE"))
  defs~append(self~def("refuse_import", "refuse the import", -
    .array~of("refuse the import", "reject the import", "fail the import"), -
    "refuse reject fail", "import", "REFUSE_WRITE"))
  defs~append(self~def("propose_edit", "propose an edit", -
    .array~of("propose an edit", "edit the method", "propose a change", "change the method body"), -
    "propose edit change", "method object revision", "PROPOSE_WRITE"))
  return defs
::method def class private
  use strict arg action, phrase, aliases, verbs, nouns, sideEffect
  d = .directory~new
  d["action"] = action; d["phrase"] = phrase; d["aliases"] = aliases
  d["verbs"] = verbs; d["nouns"] = nouns; d["side_effect"] = sideEffect
  return d

/* ------------------------------------------------- per-turn feasibility source */

::class SemanticSourceWriteCapabilitySource public
::method init
  expose sql
  use strict arg sqlExecutor
  if sqlExecutor == .nil then raise syntax 93.900 array("sql executor is required")
  sql = sqlExecutor
::attribute sql get
::attribute sql set private

/* Discover currently-feasible write actions: the vocabulary, annotated with live targets.
 * accept/refuse are feasible only while an import has PROPOSED (not-yet-accepted) revisions;
 * propose_edit is feasible only while editable semantic objects (METHOD etc.) exist. */
::method discoverWriteActions
  use arg context = .nil
  defs = .SemanticSourceWriteIntentionCatalog~definitions
  pending = self~pendingImports
  editable = self~editableObjectCount
  out = .array~new
  do d over defs
    feasible = .false; targets = .array~new
    select
      when d["action"] = "accept_import" | d["action"] = "refuse_import" then do
        targets = pending; feasible = (pending~items > 0)
      end
      when d["action"] = "propose_edit" then feasible = (editable > 0)
      otherwise feasible = .true
    end
    d["feasible"] = feasible
    d["targets"] = targets
    out~append(d)
  end
  return out

::method discoveryRevision
  use arg context = .nil
  /* Revision changes when feasibility could change, so IntentionService re-discovers. */
  return "ssc-write-intentions/1;pending=" || self~pendingImports~items || ";editable=" || self~editableObjectCount

/* Imports with at least one PROPOSED revision = pending acceptance. */
::method pendingImports
  expose sql
  ids = .array~new
  stmt = "SELECT DISTINCT b.import_id FROM ssc_import_batch b " || -
         "JOIN ssc_source_revision r ON r.origin_import_id=b.import_id " || -
         "WHERE r.status='PROPOSED'"
  rs = sql~execute(stmt)
  if rs~status = "SUCCESS" then do row over rs~rows
    id = row["import_id"]; if id == .nil then id = row["IMPORT_ID"]
    if id \== .nil then ids~append(id)
  end
  return ids

::method editableObjectCount
  expose sql
  rs = sql~execute("SELECT object_id FROM ssc_source_object WHERE object_kind='METHOD'")
  if rs~status = "SUCCESS" then return rs~rows~items
  return 0

/* --------------------------------------------- IntentionService discovery wiring */

::class SemanticSourceWriteDiscoveryProvider public
::method init
  expose capabilitySource
  use strict arg source
  if source == .nil then raise syntax 93.900 array("capability source is required")
  capabilitySource = source
::attribute capabilitySource get
::attribute capabilitySource set private

::method discover
  expose capabilitySource
  use strict arg service
  defs = capabilitySource~discoverWriteActions(.nil)
  revision = capabilitySource~discoveryRevision(.nil)
  snapshot = .IntentionDiscoverySnapshot~new("SEMANTIC_SOURCE_WRITE", revision)
  do d over defs
    if \d["feasible"] then iterate      -- advertise only what is doable right now
    provider = .SemanticSourceWriteSurfaceProvider~new(d)
    metadata = .directory~new
    metadata["ACTION"] = d["action"]
    metadata["PHRASE"] = d["phrase"]
    metadata["SIDE_EFFECT"] = d["side_effect"]
    metadata["FEASIBILITY"] = "FEASIBLE"
    metadata["TARGETS"] = d["targets"]
    advertisement = .IntentionSurfaceAdvertisement~new( -
      "SSCW." || translate(d["action"]), provider, d["action"], -
      "WRITE_ACTION", "SEMANTIC_SOURCE", "DISCOVERY", "AUTHORITATIVE_ACTION_GATE", metadata)
    snapshot~addSurfaceAdvertisement(advertisement)
  end
  return snapshot

::class SemanticSourceWriteSurfaceProvider public
::method init
  expose definition
  use strict arg d
  definition = d
::attribute definition get
::attribute definition set private

::method propose
  expose definition
  use strict arg service, text
  score = self~matchScore(text, definition)
  if score = 0 then return .array~new
  proposal = .IntentionProposal~new(definition["intention_id"], score, "SEMANTIC_SOURCE_WRITE", .true, "feasible write surface")
  proposal~putSlot("ACTION", definition["action"], .true)
  targets = definition["targets"]
  if targets \== .nil, targets~items = 1 then proposal~putSlot("TARGET", targets[1], .true)
  return .array~of(proposal)

::method matchScore private
  use strict arg text, definition
  input = translate(space(text))
  best = 0
  do alias over definition["aliases"]
    wanted = translate(space(alias))
    if wanted = "" then iterate
    if input = wanted then return 100
    if input~pos(wanted) > 0 then best = max(best, 92)
    else do
      words = wanted~words; hits = 0
      do i = 1 to words
        if input~wordpos(wanted~word(i)) > 0 then hits += 1
      end
      if hits = words & words > 0 then best = max(best, 80)
    end
  end
  return best

/* --------------------------------------------------- registration + dispatch */

::class SemanticSourceWriteIntentionInstaller public
::method install class
  use strict arg service, sqlExecutor
  source = .SemanticSourceWriteCapabilitySource~new(sqlExecutor)
  do d over .SemanticSourceWriteIntentionCatalog~definitions
    registration = service~register(d["phrase"], d["action"])
    do alias over d["aliases"]
      if translate(alias) \= translate(d["phrase"]) then registration~alias(alias)
    end
    registration~semantics(d["verbs"], d["nouns"])
    registration~tag("SPHERE", "SEMANTIC_SOURCE")
    registration~tag("ACTION", d["action"])
    registration~tag("SIDE_EFFECT", d["side_effect"])
    d["intention_id"] = registration~id
  end
  provider = .SemanticSourceWriteDiscoveryProvider~new(source)
  service~registerDiscoveryProvider(provider)
  return provider

/* Turns a READY decision into a call on the MCP write authority. The authorizer inside
 * SemanticSourceMcpOperations/RepositoryService still decides; this never writes directly. */
::class SemanticSourceWriteIntentionDispatcher public
::method init
  expose mcp principal
  use strict arg mcpOperations, sessionPrincipal
  mcp = mcpOperations; principal = sessionPrincipal
::method dispatch
  expose mcp principal
  use strict arg action, slots
  request = .directory~new
  select
    when action = "accept_import" then do
      request["import_id"] = self~slot(slots, "TARGET")
      request["reason"] = "accepted via intention"
      return mcp~dispatch("source.accept_import", request, principal)
    end
    when action = "refuse_import" then do
      request["import_id"] = self~slot(slots, "TARGET")
      request["summary"] = "refused via intention"
      return mcp~dispatch("source.import_archive_fail", request, principal)
    end
    otherwise do
      reply = .directory~new
      reply["ok"] = 0
      reply["error"] = "no dispatch mapping for action " || action
      return reply
    end
  end
::method slot private
  use strict arg slots, name
  if slots == .nil then return ""
  if slots~hasMethod("HASINDEX"), slots~hasIndex(name) then return slots[name]
  return ""

::requires "IntentionService.cls"
::requires "IntentionContext.cls"
