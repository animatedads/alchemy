/*
 * Reasoned Thought / EvidenceCombiner.cls
 * Pure ooRexx ordinal inference and auditable conflict resolution.
 * Architecture: Tom Dyer. Combiner implementation: ChatGPT (GPT-6).
 * REQ-00000181 / REQ-00000189 / REQ-00000193.
 *
 * Boundary: Ground~tier is an ALREADY ADMITTED evidence priority. This class cannot
 * authenticate sources or prove their declared class/binding. Provenance validators
 * and derivation warrant admission must run BEFORE grounds reach this combiner.
 * No probability is implied by its decisions, and SETTLED is policy-relative.
 *
 * This file is separate from Claude's ReasonedThought.cls and does not edit its
 * reference combiner. Inject: .ThoughtNetwork~new(.EvidenceCombiner~new).
 */
::class EvidenceCombiner public
::method evaluate
  use strict arg p
  inputs = p~grounds
  byId = .directory~new
  allIds = .array~new
  decisions = .directory~new
  note = .array~new
  bad = .false
  /* Ground IDs are stable within one proposition; ambiguity invalidates evidence. */
  do g over inputs
    gid = g~id
    if gid = "" | byId~hasIndex(gid) then do
      bad = .true
      note~append("INVALID_DUPLICATE_OR_EMPTY_ID:" || gid)
    end
    else do
      byId[gid] = g
      allIds~append(gid)
    end
  end
  allIds~sort
  /* A source may be cited repeatedly; keep one representative for each origin,
     direction, target and binding. The strongest class wins, then smallest ID. */
  originBest = .directory~new
  do gid over allIds
    g = byId[gid]
    key = self~part(g~sourceUtterance) || self~part(g~kind) || -
          self~part(g~targetId) || self~part(g~undercutsGroundId) || self~part(g~binds)
    if \originBest~hasIndex(key) then originBest[key] = gid
    else do
      prior = originBest[key]
      old = byId[prior]
      if g~tier > old~tier | (g~tier = old~tier & gid < prior) then originBest[key] = gid
    end
  end
  duplicates = .set~new
  do gid over allIds
    g = byId[gid]
    key = self~part(g~sourceUtterance) || self~part(g~kind) || -
          self~part(g~targetId) || self~part(g~undercutsGroundId) || self~part(g~binds)
    if originBest[key] \= gid then do
      decisions[gid] = "DUPLICATE"
      duplicates~put(gid)
    end
  end

  /* Validate the defeater graph, independently of the concept hierarchy.
     UNDERCUT -> its target must be another Ground in this proposition. */
  do gid over allIds
    g = byId[gid]
    if g~kind = "UNDERCUT" then do
      if g~undercutsGroundId = "" | \byId~hasIndex(g~undercutsGroundId) then do
        bad = .true
        note~append("INVALID_UNDERCUT_TARGET:" || gid)
      end
    end
    else if g~kind \= "SUPPORT" & g~kind \= "REBUT" then do
      bad = .true
      note~append("INVALID_RELATION:" || gid)
    end
    else if g~undercutsGroundId \= "" then do
      bad = .true
      note~append("NON_UNDERCUT_HAS_TARGET:" || gid)
    end
    if g~targetId \= p~id then do
      bad = .true
      note~append("CROSS_PROPOSITION_TARGET:" || gid)
    end
    if g~tier < 1 | g~tier > 4 then do
      bad = .true
      note~append("UNKNOWN_EVIDENCE_TIER:" || gid)
    end
  end

  /* Resolve leaves first: an undercutter itself can be undercut. No recursion,
     no input-order dependence. If no progress is possible, there is a cycle. */
  if \bad then do
    do while decisions~items < allIds~items
      progressed = .false
      do gid over allIds
        if decisions~hasIndex(gid) then iterate
        g = byId[gid]
        waiting = .false
        highest = 0
        equal = .false
        uncertain = .false
        do aid over allIds
          a = byId[aid]
          if a~kind \= "UNDERCUT" | a~undercutsGroundId \= gid then iterate
          if \decisions~hasIndex(aid) then do
            waiting = .true
            iterate
          end
          ast = decisions[aid]
          if ast = "LIVE" then do
            if a~tier > highest then highest = a~tier
            if a~tier = g~tier then equal = .true
          end
          else if ast = "DISPUTED" then uncertain = .true
        end
        if waiting then iterate
        if \p~acceptsBinding(g~binds) then decisions[gid] = "INELIGIBLE"
        else if highest > g~tier then decisions[gid] = "DEFEATED"
        else if equal | uncertain then decisions[gid] = "DISPUTED"
        else decisions[gid] = "LIVE"
        progressed = .true
      end
      if \progressed then do
        bad = .true
        note~append("CYCLIC_UNDERCUT_GRAPH")
        leave
      end
    end
  end
  if bad then return self~invalid(p, allIds, note)

  live = .array~new
  defeated = .set~new
  ineligible = .set~new
  disputedIds = .set~new
  support = 0
  rebut = 0
  ambiguous = .false
  transcript = .array~new
  transcript~append("ordinal-evidence-combiner/0.3")
  transcript~append("claim=" || self~part(p~id))
  transcript~append(self~claimText(p))
  do gid over allIds
    g = byId[gid]
    st = decisions[gid]
    /* The explanatory note is a provenance-bearing part of the submitted
     * Ground, not a reason to change its evidence tier. Preserve exact bytes
     * in the transcript while keeping deduplication source-origin based. */
    notePresent = 0; noteText = ""
    if g~hasMethod("NOTE") then do
      notePresent = 1
      noteText = g~note
    end
    transcript~append(self~part(gid) || self~part(g~kind) || self~part(g~tier) || -
      self~part(g~sourceUtterance) || self~part(g~targetId) || -
      self~part(g~undercutsGroundId) || self~part(g~binds) || -
      self~part(notePresent) || self~part(noteText) || self~part(st))
    select
      when st = "LIVE" then do
        live~append(gid)
        if g~kind = "SUPPORT" then support = max(support, g~tier)
        if g~kind = "REBUT" then rebut = max(rebut, g~tier)
      end
      when st = "INELIGIBLE" then ineligible~put(gid)
      when st = "DISPUTED" then do
        disputedIds~put(gid)
        ambiguous = .true
      end
      when st = "DEFEATED" then defeated~put(gid)
      otherwise nop
    end
  end
  select
    when support > rebut then stance = "PRO"
    when rebut > support then stance = "CONTRA"
    when support = rebut & support > 0 then stance = "DISPUTED"
    when ambiguous then stance = "DISPUTED"
    otherwise stance = "UNDETERMINED"
  end
  floorA = p~assertFloorRank
  floorS = p~settleFloorRank
  assertible = .false
  if stance = "PRO" & support >= floorA then assertible = .true
  if stance = "CONTRA" & rebut >= floorA then assertible = .true
  settled = .false
  if stance = "PRO" & floorS > 0 & support >= floorS then settled = .true
  /* Quarantined high-tier contradictions cannot be silently outweighed by
     unrelated low-tier live grounds. Their challenge must remain visible. */
  do gid over allIds
    if decisions[gid] \= "DISPUTED" then iterate
    g = byId[gid]
    if g~tier >= max(support, rebut) then do
      stance = "DISPUTED"
      assertible = .false
      settled = .false
    end
  end
  select
    when settled then status = "SETTLED"
    when stance = "DISPUTED" then status = "DISPUTED"
    when assertible & stance = "PRO" then status = "SUPPORTED"
    when assertible & stance = "CONTRA" then status = "REBUTTED"
    when stance = "UNDETERMINED" then status = "UNDETERMINED"
    otherwise status = "HINT"
  end
  transcript~append("tiers=" || support || "/" || rebut || ":floors=" || floorA || "/" || floorS)
  transcript~append("decision=" || stance || ":" || status || ":" || assertible || ":" || settled)
  why = self~join(transcript)
  d = .directory~new
  d["stance"] = stance; d["status"] = status
  d["assertible"] = assertible; d["settled"] = settled
  d["supportTier"] = support; d["rebutTier"] = rebut
  d["live"] = live; d["defeated"] = defeated; d["ineligible"] = ineligible
  d["disputed"] = (stance = "DISPUTED") | ambiguous
  d["disputedGrounds"] = disputedIds; d["duplicates"] = duplicates
  d["admissibility"] = "ADMITTED_EVIDENCE_ONLY"
  d["derivation"] = why; d["why"] = why
  d["derivationVersion"] = "ordinal-evidence-combiner/0.3"
  d["validationBoundary"] = "source authenticity, evidence class and warrants are upstream obligations"
  return d

::method invalid private
  use strict arg p, ids, notes
  d = .directory~new
  d["stance"] = "UNDETERMINED"; d["status"] = "INVALID"
  d["assertible"] = .false; d["settled"] = .false
  d["supportTier"] = 0; d["rebutTier"] = 0
  d["live"] = .array~new; d["defeated"] = .set~new
  d["ineligible"] = .set~new; d["disputed"] = .true
  d["disputedGrounds"] = .set~new; d["duplicates"] = .set~new
  d["admissibility"] = "FAIL_CLOSED"
  why = "ordinal-evidence-combiner/0.3" || "0a"x || -
    "claim=" || self~part(p~id) || "0a"x || self~claimText(p) || "0a"x || self~join(notes)
  d["derivation"] = why; d["why"] = why
  d["derivationVersion"] = "ordinal-evidence-combiner/0.3"
  d["validationBoundary"] = "failed structural admission"
  return d

::method claimText private
  use strict arg p
  if p~hasMethod("STATEMENT") then return "claimText=AVAILABLE:" || self~part(p~statement)
  return "claimText=UNAVAILABLE"

::method join private
  use strict arg arr
  out = ""
  do i = 1 to arr~items
    if i > 1 then out = out || "0a"x
    out = out || arr[i]
  end
  return out

::method part private
  /* Length-prefixed fields are unambiguous even if an ID contains ':' or '|'. */
  use strict arg item
  val = item~string
  return length(val) || ":" || val
