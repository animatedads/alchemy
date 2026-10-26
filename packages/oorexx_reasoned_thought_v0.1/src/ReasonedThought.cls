/*
 * Reasoned Thought: a provable, defeasible belief model for Alchemy.
 *
 * A Proposition is a thought that records WHY it is held - a set of Grounds, each
 * citing an Utterance and carrying an evidence class - and what would change it.
 * A new Utterance TRIGGERS re-evaluation: the ThoughtNetwork re-settles the affected
 * propositions like a circuit and emits an auditable change report.
 *
 * The four Alchemy spines meet here:
 *   utterance    - the unit of incoming evidence (structured; NL parsing is a separate seam)
 *   intentions   - meaning registered once, STATUS recomputed per utterance from live state
 *   maths        - the confidence-combination rule (noisy-OR + class-rank gating; v0, see README)
 *   legal        - evidence classes carry weight AND rank; a claim may require a minimum
 *                  class to be SETTLED, so testimony or stylistic resemblance can never
 *                  settle a claim that demands PROVENANCE
 *
 * "Provable" means: a proposition's status is a pure, re-runnable function of its recorded
 * grounds and the combination rule. An LLM may PROPOSE a thought and cite grounds; it cannot
 * assert a confidence the grounds do not support, and any later utterance that bears on it
 * forces re-evaluation. The reasoning is inspectable (assess~why), not a vibe.
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
  /* weight: how much one ground of this class moves belief; rank: evidentiary order.
     A claim that requires a minimum class is settled only by a LIVE support ground of
     that rank or higher - never by accumulating weaker-class evidence. */
  t["STYLOMETRIC"] = self~new("STYLOMETRIC", 0.15, 1)   /* voice / stylistic resemblance - a hunch */
  t["TESTIMONY"]   = self~new("TESTIMONY",   0.70, 2)   /* a person asserts it (incl. an editorial disclosure) */
  t["DOCUMENTARY"] = self~new("DOCUMENTARY", 0.85, 3)   /* a dated artifact or record */
  t["PROVENANCE"]  = self~new("PROVENANCE",  0.98, 4)   /* cryptographic / Message-ID chain of custody */
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
   SUPPORT/REBUT target a proposition's conclusion; UNDERCUT targets another ground's
   inferential link (undercutsGroundId) and attenuates its effective weight. */
::method init
  expose id kind evidenceClass sourceUtterance targetId undercutsGroundId note
  use strict arg id, kind, evidenceClass, sourceUtterance, targetId, undercutsGroundId = "", note = ""
  if \ .array~of("SUPPORT","REBUT","UNDERCUT")~hasItem(kind) then -
    raise syntax 93.900 array("ground kind must be SUPPORT, REBUT or UNDERCUT, not " kind)
::attribute id get
::attribute kind get
::attribute evidenceClass get
::attribute sourceUtterance get
::attribute targetId get
::attribute undercutsGroundId get
::attribute note get
::method weight
  expose evidenceClass
  return evidenceClass~weight
::method rank
  expose evidenceClass
  return evidenceClass~rank

/* ------------------------------------------------------------------------- a proposition */

::class Proposition public
/* requiresClass: name of the minimum evidence class needed to SETTLE (assert) this
   proposition, or "" for none. */
::method init
  expose id statement requiresClass grounds
  use strict arg id, statement, requiresClass = ""
  if requiresClass \= "" then call checkClass requiresClass   /* validate early */
  grounds = .array~new
::attribute id get
::attribute statement get
::attribute requiresClass get
::method grounds
  expose grounds
  return grounds
::method addGround
  expose grounds
  use strict arg g
  grounds~append(g)
::method requiredRank
  expose requiresClass
  if requiresClass = "" then return 0
  return .EvidenceClass~of(requiresClass)~rank

/* ------------------------------------------------- an utterance (structured evidence unit) */

::class Utterance public
/* Carries text plus zero or more structured assertions. Turning free text into these
   assertions is the IntentionService / structured-utterance seam, deliberately external. */
::method init
  expose id text assertions
  use strict arg id, text = ""
  assertions = .array~new
::attribute id get
::attribute text get
::attribute assertions get
::method assert
  /* kind, evidence class, target proposition id, [ground it undercuts], [note], [ground id hint] */
  expose assertions
  use strict arg kind, evidenceClassName, targetId, undercutsGroundId = "", note = "", idHint = ""
  a = .directory~new
  a["kind"] = kind; a["class"] = evidenceClassName; a["target"] = targetId
  a["undercuts"] = undercutsGroundId; a["note"] = note; a["idhint"] = idHint
  assertions~append(a)
  return a

/* ------------------------------------------------------- the network (rexx-tronics spine) */

::class ThoughtNetwork public
::method init
  expose props groundIndex groundSeq
  props = .directory~new        /* propId  -> Proposition */
  groundIndex = .directory~new  /* groundId -> Ground     */
  groundSeq = 0

::method propose
  /* convenience: make and register a proposition */
  expose props
  use strict arg id, statement, requiresClass = ""
  p = .Proposition~new(id, statement, requiresClass)
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

/* Admit an utterance: attach its assertions as grounds, re-settle, return a change report.
   This is the trigger: "from the sentence below, re-evaluate the idea above." */
::method admit
  expose props groundIndex groundSeq
  use strict arg utterance
  before = self~snapshot
  touched = .set~new
  do a over utterance~assertions
    groundSeq += 1
    if a["idhint"] \= "" then gid = a["idhint"]
    else gid = "G-" || groundSeq
    g = .Ground~new(gid, a["kind"], .EvidenceClass~of(a["class"]), utterance~id, -
                    a["target"], a["undercuts"], a["note"])
    groundIndex[gid] = g
    target = props[a["target"]]
    if target == .nil then raise syntax 93.900 array("ground targets unknown proposition " a["target"])
    target~addGround(g)
    touched~put(a["target"])
    if a["undercuts"] \= "" then do
      uttg = groundIndex[a["undercuts"]]
      if uttg \== .nil then touched~put(uttg~targetId)   /* undercut target also re-settles */
    end
  end
  after = self~snapshot
  return self~report(before, after, touched, utterance)

/* Assess one proposition now: status, confidence, assertibility and the WHY. Pure function
   of the recorded grounds - this is the inspectable, re-runnable judgement. */
::method assess
  expose props
  use strict arg id
  p = props[id]
  if p == .nil then raise syntax 93.900 array("no such proposition " id)

  supportW = .array~new; attackW = .array~new
  bestLiveSupportRank = 0; liveSupportCount = 0; liveLines = .array~new

  do g over p~grounds
    if g~kind = "UNDERCUT" then iterate     /* undercutters act on other grounds, below */
    eff = g~weight
    undercutBy = ""
    do u over p~grounds
      if u~kind = "UNDERCUT", u~undercutsGroundId = g~id then do
        eff = eff * (1 - u~weight)
        undercutBy = undercutBy u~id || "(" || u~evidenceClass~name || ")"
      end
    end
    line = g~id g~kind g~evidenceClass~name "w=" || format(g~weight,,2) "eff=" || format(eff,,3)
    if undercutBy \= "" then line = line "[undercut by " || strip(undercutBy) || "]"
    liveLines~append(line)
    if g~kind = "SUPPORT" then do
      supportW~append(eff)
      if eff > 0.001 then do
        liveSupportCount += 1
        bestLiveSupportRank = max(bestLiveSupportRank, g~rank)
      end
    end
    else if g~kind = "REBUT" then attackW~append(eff)
  end

  s = self~noisyOr(supportW)
  att = self~noisyOr(attackW)
  conf = s * (1 - att)
  required = p~requiredRank
  settleThreshold = 0.66

  assertible = .false
  select
    when s = 0 & att = 0 then status = "OPEN"
    when required > 0 & bestLiveSupportRank < required then status = "UNDERDETERMINED"
    when conf >= settleThreshold & s > att then do
      if required > 0 then status = "SETTLED"; else status = "SUPPORTED"
      assertible = .true
    end
    when att > s & att >= 0.5 then status = "REBUTTED"   /* attack must clearly dominate; a standoff is UNDERDETERMINED */
    otherwise status = "UNDERDETERMINED"
  end

  r = .directory~new
  r["id"] = id; r["statement"] = p~statement; r["status"] = status
  r["confidence"] = conf; r["support"] = s; r["attack"] = att
  r["assertible"] = assertible
  r["why"] = self~why(p, status, assertible, required, bestLiveSupportRank, conf, liveLines)
  return r

::method why private
  use strict arg p, status, assertible, required, bestRank, conf, liveLines
  parts = .array~new
  parts~append("status=" || status "conf=" || format(conf,,3) "assertible=" || assertible)
  if required > 0 then do
    needed = p~requiresClass
    if bestRank < required then -
      parts~append("blocked: requires " || needed " (rank " || required || ") to settle; best live support is rank " || bestRank)
    else parts~append("satisfied: a live support ground meets required class " || needed)
  end
  if liveLines~items = 0 then parts~append("no grounds yet")
  else do ln over liveLines; parts~append("  " || ln); end
  out = ""
  do i = 1 to parts~items
    if i = 1 then out = parts[i]
    else out = out || "0a"x || parts[i]
  end
  return out

::method noisyOr private
  /* combine independent same-side weights in [0,1]: 1 - prod(1-w). Order-independent. */
  use strict arg weights
  prod = 1
  do w over weights
    prod = prod * (1 - w)
  end
  return 1 - prod

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
  rep["utterance"] = utterance~id
  rep["text"] = utterance~text
  changes = .array~new
  do id over touched
    b = before[id]; a = after[id]
    c = .directory~new
    c["id"] = id; c["statement"] = a["statement"]
    c["fromStatus"] = b["status"]; c["toStatus"] = a["status"]
    c["fromConf"] = b["confidence"]; c["toConf"] = a["confidence"]
    c["fromAssertible"] = b["assertible"]; c["toAssertible"] = a["assertible"]
    c["moved"] = (b["status"] \= a["status"]) | (abs(b["confidence"] - a["confidence"]) > 0.0005)
    changes~append(c)
  end
  rep["changes"] = changes
  return rep

/* ----------------------------------------------------------------------------- routines */

::routine checkClass
  use strict arg name
  .EvidenceClass~of(name)   /* bare message; raises if the class is unknown */
  return
