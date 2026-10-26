/*
 * Reasoned Thought: a provable, defeasible belief model for Alchemy.
 *
 * A Proposition is a thought that records WHY it is held - a set of Grounds, each citing an
 * Utterance, carrying an evidence class AND a binding scope (what that evidence actually proves).
 * A new Utterance TRIGGERS re-evaluation: the ThoughtNetwork re-settles the affected propositions
 * like a circuit and emits an auditable change report.
 *
 * Decision procedure is ORDINAL and defeasible, per ChatGPT's combiner design (coordination
 * REQ-00000189): grounds are weighed by evidence TIER, not by a manufactured scalar. No
 * accumulation of weaker-tier evidence settles a claim that requires a higher tier, and evidence
 * only counts for the proposition its binding scope is actually on point for - a mail Message-ID
 * proves the email document, not that a given passage was generated verbatim by Claude.
 *
 * Spines: utterance (evidence unit) | intentions (status recomputed per utterance from live state)
 * | legal (tier + binding + per-claim floors) | rexx-tronics (the network re-settles like a circuit).
 *
 * SEAM: the authoritative EvidenceCombiner is ChatGPT's (GPT-6) to own and harden
 * (paraconsistent stance, derivation certificates, independent-origin dedup, cycle detection).
 * OrdinalEvidenceCombiner here is a REFERENCE implementation of the agreed ordinal rule, enough
 * to run the qualification; ThoughtNetwork takes any combiner via injection.
 *
 * Author: Claude (Opus 4.8), 2026-10-26. Architecture: Tom Dyer.
 * Pure ooRexx 5.3, no native dependencies.
 */

/* ----------------------------------------------------------- evidence classes (legal spine) */

::class EvidenceClass public
::method of class
  use strict arg name
  t = self~table
  if \t~hasIndex(name~upper) then raise syntax 93.900 array("unknown evidence class " name)
  return t[name~upper]
::method table class private
  if .local~hasIndex("ReasonedThought.EvidenceClasses") then return .local["ReasonedThought.EvidenceClasses"]
  t = .directory~new
  /* rank is the evidentiary TIER; it is the authoritative ordinal. weight is retained only for a
     possible future within-tier numeric extension and is NOT used in the ordinal decision. */
  t["STYLOMETRIC"] = self~new("STYLOMETRIC", 0.15, 1)   /* voice / stylistic resemblance - a hunch */
  t["TESTIMONY"]   = self~new("TESTIMONY",   0.70, 2)   /* a person asserts it (incl. an editorial disclosure) */
  t["DOCUMENTARY"] = self~new("DOCUMENTARY", 0.85, 3)   /* a dated artifact or record */
  t["PROVENANCE"]  = self~new("PROVENANCE",  0.98, 4)   /* cryptographic / chain-of-custody binding */
  .local["ReasonedThought.EvidenceClasses"] = t
  return t
::method init
  expose name weight rank
  use strict arg name, weight, rank
::attribute name get
::attribute weight get
::attribute rank get

/* ----------------------------------------------------------------------------- a ground */

::class Ground public
/* kind: "SUPPORT" | "REBUT" | "UNDERCUT".
   SUPPORT/REBUT target a proposition's conclusion; UNDERCUT targets another ground's inferential
   link (undercutsGroundId). binds is the ground's binding scope - what the evidence actually
   proves (e.g. GENERAL, MAIL_DOCUMENT, PASSAGE_GENERATION); a proposition only accepts grounds
   whose binding scope is on point for it. */
::method init
  expose id kind evidenceClass sourceUtterance targetId undercutsGroundId binds note
  use strict arg id, kind, evidenceClass, sourceUtterance, targetId, -
                 undercutsGroundId = "", binds = "GENERAL", note = ""
  if \ .array~of("SUPPORT","REBUT","UNDERCUT")~hasItem(kind) then -
    raise syntax 93.900 array("ground kind must be SUPPORT, REBUT or UNDERCUT, not " kind)
::attribute id get
::attribute kind get
::attribute evidenceClass get
::attribute sourceUtterance get
::attribute targetId get
::attribute undercutsGroundId get
::attribute binds get
::attribute note get
::method tier
  expose evidenceClass
  return evidenceClass~rank
::method className
  expose evidenceClass
  return evidenceClass~name

/* ------------------------------------------------------------------------- a proposition */

::class Proposition public
/* settleFloor: minimum evidence class to SETTLE (assert as proven), "" = settlement not tracked.
   assertFloor: minimum class for the stance to be ASSERTIBLE (default TESTIMONY).
   acceptedBindings: binding scopes (besides GENERAL) that bear on this claim; a ground whose
   binding scope is not on point is INELIGIBLE and does not count. */
::method init
  expose id statement settleFloor assertFloor acceptedBindings grounds
  use strict arg id, statement, settleFloor = "", assertFloor = "TESTIMONY", accepted = .nil
  if settleFloor \= "" then .EvidenceClass~of(settleFloor)   /* validate */
  if assertFloor \= "" then .EvidenceClass~of(assertFloor)
  acceptedBindings = .set~new
  if accepted \== .nil then do b over accepted; acceptedBindings~put(b); end
  grounds = .array~new
::attribute id get
::attribute statement get
::method grounds
  expose grounds
  return grounds
::method addGround
  expose grounds
  use strict arg g
  grounds~append(g)
::method acceptsBinding
  expose acceptedBindings
  use strict arg binds
  if binds = "GENERAL" then return .true
  return acceptedBindings~hasItem(binds)
::method assertFloorRank
  expose assertFloor
  if assertFloor = "" then return 0
  return .EvidenceClass~of(assertFloor)~rank
::method settleFloorRank
  expose settleFloor
  if settleFloor = "" then return 0
  return .EvidenceClass~of(settleFloor)~rank

/* ------------------------------------------------- an utterance (structured evidence unit) */

::class Utterance public
::method init
  expose id text assertions
  use strict arg id, text = ""
  assertions = .array~new
::attribute id get
::attribute text get
::attribute assertions get
::method assert
  /* kind, evidence class, target proposition id, [undercuts ground id], [binding scope], [note], [id hint] */
  expose assertions
  use strict arg kind, evidenceClassName, targetId, undercutsGroundId = "", -
                 binds = "GENERAL", note = "", idHint = ""
  a = .directory~new
  a["kind"] = kind; a["class"] = evidenceClassName; a["target"] = targetId
  a["undercuts"] = undercutsGroundId; a["binds"] = binds; a["note"] = note; a["idhint"] = idHint
  assertions~append(a)
  return a

/* --------------------------------------------- reference combiner (ChatGPT owns the authoritative) */

::class OrdinalEvidenceCombiner public
/* evaluate(proposition) -> BeliefDecision (a directory). Pure: no IO, no network, no LLM.
   This is the agreed interface; ChatGPT's authoritative combiner replaces this body. */
::method evaluate
  use strict arg p
  grounds = p~grounds
  ineligible = .set~new; defeated = .set~new; disputed = .false
  liveSupportTiers = .array~new; liveRebutTiers = .array~new; liveIds = .array~new
  settleOK = .false; lines = .array~new

  do g over grounds
    if g~kind = "UNDERCUT" then iterate            /* undercutters act on other grounds, below */
    if \ p~acceptsBinding(g~binds) then do
      ineligible~put(g~id)
      lines~append(g~id g~kind g~className "binds=" || g~binds "INELIGIBLE: binding not on point for this claim")
      iterate
    end
    /* resolve undercuts against THIS ground's inferential link */
    maxUnder = 0; eqUnder = .false
    do u over grounds
      if u~kind \= "UNDERCUT" then iterate
      if u~undercutsGroundId \= g~id then iterate
      if u~tier > g~tier then maxUnder = max(maxUnder, u~tier)
      else if u~tier = g~tier then eqUnder = .true
    end
    if maxUnder > g~tier then do
      defeated~put(g~id)
      lines~append(g~id g~kind g~className "tier=" || g~tier "DEFEATED by higher-tier undercut (tier " || maxUnder || ")")
      iterate
    end
    if eqUnder then do
      defeated~put(g~id); disputed = .true
      lines~append(g~id g~kind g~className "tier=" || g~tier "QUARANTINED by equal-tier undercut (inference DISPUTED)")
      iterate
    end
    liveIds~append(g~id)
    lines~append(g~id g~kind g~className "tier=" || g~tier "binds=" || g~binds "LIVE")
    if g~kind = "SUPPORT" then do
      liveSupportTiers~append(g~tier)
      if p~settleFloorRank > 0, g~tier >= p~settleFloorRank then settleOK = .true
    end
    else if g~kind = "REBUT" then liveRebutTiers~append(g~tier)
  end

  s = self~maxTier(liveSupportTiers)
  r = self~maxTier(liveRebutTiers)
  select
    when s > r then stance = "PRO"
    when r > s then stance = "CONTRA"
    when s = r, s > 0 then do; stance = "DISPUTED"; disputed = .true; end
    otherwise stance = "UNDETERMINED"
  end

  assertible = .false
  if stance = "PRO", s >= p~assertFloorRank then assertible = .true
  else if stance = "CONTRA", r >= p~assertFloorRank then assertible = .true

  settled = .false
  if stance = "PRO", p~settleFloorRank > 0, settleOK then settled = .true

  select
    when settled then status = "SETTLED"
    when stance = "DISPUTED" then status = "DISPUTED"
    when stance = "PRO", assertible then status = "SUPPORTED"
    when stance = "CONTRA", assertible then status = "REBUTTED"
    when stance = "PRO" then status = "HINT"          /* a lead, but below the assertibility floor */
    when stance = "CONTRA" then status = "HINT"
    otherwise status = "UNDETERMINED"
  end

  d = .directory~new
  d["stance"] = stance; d["status"] = status
  d["assertible"] = assertible; d["settled"] = settled
  d["supportTier"] = s; d["rebutTier"] = r
  d["live"] = liveIds; d["defeated"] = defeated; d["ineligible"] = ineligible; d["disputed"] = disputed
  d["why"] = self~why(p, s, r, lines)
  return d

::method maxTier private
  use strict arg tiers
  m = 0
  do t over tiers; if t > m then m = t; end
  return m

::method why private
  use strict arg p, s, r, lines
  parts = .array~new
  parts~append("supportTier=" || s "rebutTier=" || r "assertFloor=" || p~assertFloorRank "settleFloor=" || p~settleFloorRank)
  if lines~items = 0 then parts~append("no grounds yet")
  else do ln over lines; parts~append("  " || ln); end
  out = ""
  do i = 1 to parts~items
    if i = 1 then out = parts[i]
    else out = out || "0a"x || parts[i]
  end
  return out

/* ------------------------------------------------------- the network (rexx-tronics spine) */

::class ThoughtNetwork public
::method init
  expose props groundIndex groundSeq combiner
  use strict arg combinerArg = .nil
  props = .directory~new; groundIndex = .directory~new; groundSeq = 0
  if combinerArg == .nil then combiner = .OrdinalEvidenceCombiner~new
  else combiner = combinerArg

::method propose
  expose props
  use strict arg id, statement, settleFloor = "", assertFloor = "TESTIMONY", accepted = .nil
  p = .Proposition~new(id, statement, settleFloor, assertFloor, accepted)
  props[id] = p
  return p

::method add
  expose props
  use strict arg proposition
  props[proposition~id] = proposition
  return proposition

::method proposition
  expose props
  use strict arg id
  return props[id]

/* Admit an utterance: attach its assertions as grounds, re-settle, return a change report. */
::method admit
  expose props groundIndex groundSeq combiner
  use strict arg utterance
  before = self~snapshot
  touched = .set~new
  do a over utterance~assertions
    groundSeq += 1
    if a["idhint"] \= "" then gid = a["idhint"]
    else gid = "G-" || groundSeq
    g = .Ground~new(gid, a["kind"], .EvidenceClass~of(a["class"]), utterance~id, -
                    a["target"], a["undercuts"], a["binds"], a["note"])
    groundIndex[gid] = g
    target = props[a["target"]]
    if target == .nil then raise syntax 93.900 array("ground targets unknown proposition " a["target"])
    target~addGround(g)
    touched~put(a["target"])
    if a["undercuts"] \= "" then do
      uttg = groundIndex[a["undercuts"]]
      if uttg \== .nil then touched~put(uttg~targetId)
    end
  end
  after = self~snapshot
  return self~report(before, after, touched, utterance)

::method assess
  expose props combiner
  use strict arg id
  p = props[id]
  if p == .nil then raise syntax 93.900 array("no such proposition " id)
  d = combiner~evaluate(p)
  d["id"] = id; d["statement"] = p~statement
  return d

::method snapshot private
  expose props
  snap = .directory~new
  do id over props~allIndexes
    snap[id] = self~assess(id)
  end
  return snap

::method report private
  use strict arg before, after, touched, utterance
  rep = .directory~new
  rep["utterance"] = utterance~id; rep["text"] = utterance~text
  changes = .array~new
  do id over touched
    b = before[id]; a = after[id]
    c = .directory~new
    c["id"] = id; c["statement"] = a["statement"]
    c["fromStatus"] = b["status"]; c["toStatus"] = a["status"]
    c["fromAssertible"] = b["assertible"]; c["toAssertible"] = a["assertible"]
    c["fromSettled"] = b["settled"]; c["toSettled"] = a["settled"]
    c["moved"] = (b["status"] \= a["status"]) | (b["assertible"] \= a["assertible"]) | -
                 (b["settled"] \= a["settled"]) | (b["supportTier"] \= a["supportTier"]) | -
                 (b["rebutTier"] \= a["rebutTier"])
    changes~append(c)
  end
  rep["changes"] = changes
  return rep
