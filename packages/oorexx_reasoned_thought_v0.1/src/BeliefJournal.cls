/*
 * Belief Journal: retroactive revision with dependency tracing - "let me think about what I missed".
 * (Tom's requirement, 2026-10-26.)
 *
 * Decisions rest on claims. Replay the claims under a NEW thinking model (a different combiner or
 * categorisation); if a claim that was usable now fails, walk FORWARD along the dependency edges to
 * every decision that was built on it, and report which of those decisions now fall. This is a
 * justification-based truth-maintenance pass over the Reasoned Thought network: a conclusion is only
 * as good as the claims still standing beneath it.
 *
 * Lanes: the journal (dependency edges + replay + impact trace) is Claude's; the combiner it replays
 * under is ChatGPT's. NaiveEvidenceCombiner here is a stand-in for a PRIOR (weaker) thinking model -
 * it ignores binding scope, so it makes the old mistake of settling authorship on a mail Message-ID.
 *
 * Author: Claude (Opus 4.8), 2026-10-26. Architecture: Tom Dyer. Pure ooRexx 5.3.
 */

::class BeliefJournal public
::method init
  expose net claims decisions deps revdeps
  use strict arg network
  net = network
  claims = .set~new                 /* claim proposition ids */
  decisions = .set~new              /* decision proposition ids */
  deps = .directory~new             /* decisionId -> array of {claim, mode} */
  revdeps = .directory~new          /* claimId -> set of decision ids that rest on it */

::method claim
  expose net claims
  use strict arg id, statement, settleFloor = "", assertFloor = "TESTIMONY", accepted = .nil
  net~propose(id, statement, settleFloor, assertFloor, accepted)
  claims~put(id)
  return id

::method decision
  expose net decisions
  use strict arg id, statement
  net~propose(id, statement)        /* a pure decision node: it holds iff the claims under it hold */
  decisions~put(id)
  return id

::method restsOn
  expose decisions deps revdeps
  use strict arg decisionId, claimId, mode = "assertible"   /* mode: assertible | settled */
  decisions~put(decisionId)
  if \deps~hasIndex(decisionId) then deps[decisionId] = .array~new
  d = .directory~new; d["claim"] = claimId; d["mode"] = mode
  deps[decisionId]~append(d)
  if \revdeps~hasIndex(claimId) then revdeps[claimId] = .set~new
  revdeps[claimId]~put(decisionId)
  return self

/* Status of any node under a given combiner (.nil = the network's current/baseline model). */
::method status
  expose net decisions deps
  use strict arg id, combiner = .nil
  return self~statusRec(id, combiner, .set~new)

::method statusRec private
  expose net decisions deps
  use strict arg id, combiner, visiting
  r = .directory~new; r["id"] = id
  if visiting~hasItem(id) then do
    r["kind"] = "CYCLE"; r["ok"] = .false; r["status"] = "CYCLE"; r["failedDeps"] = .array~new
    return r                                  /* dependency cycle: fail closed */
  end
  if \decisions~hasItem(id) then do
    b = net~assess(id, combiner)
    r["kind"] = "CLAIM"; r["status"] = b["status"]
    r["assertible"] = b["assertible"]; r["settled"] = b["settled"]
    /* a claim is "usable" as a premise only when it is assertible IN FAVOUR (PRO); a CONTRA claim is
       assertibly false, and must NOT prop up a decision that rested on it being true */
    r["ok"] = (b["stance"] = "PRO" & b["assertible"])
    r["failedDeps"] = .array~new
    return r
  end
  /* a decision: holds iff every claim it rests on still meets its required mode */
  visiting~put(id)
  failed = .array~new; holds = .true
  if deps~hasIndex(id) then do dep over deps[id]
    sub = self~statusRec(dep["claim"], combiner, visiting)
    if dep["mode"] = "settled" then ok = sub["settled"]
    else ok = sub["ok"]
    if ok \== .true then do; holds = .false; failed~append(dep["claim"] "(needs" dep["mode"] || ")"); end
  end
  visiting~remove(id)
  r["kind"] = "DECISION"; r["ok"] = holds; r["assertible"] = holds
  r["failedDeps"] = failed
  if holds then r["status"] = "SUPPORTED"; else r["status"] = "UNSUPPORTED"
  return r

/* All decisions that rest on claimId, directly or transitively. */
::method dependents
  expose revdeps
  use strict arg claimId
  out = .set~new
  frontier = .array~of(claimId)
  do while frontier~items > 0
    next = .array~new
    do node over frontier
      if \revdeps~hasIndex(node) then iterate
      do dec over revdeps[node]
        if \out~hasItem(dec) then do; out~put(dec); next~append(dec); end
      end
    end
    frontier = next
  end
  return out

/* The "what did I miss" pass: replay every node under newCombiner, find claims that regressed, and
   for each, the decisions downstream that now fall. */
::method review
  expose net claims decisions
  use strict arg newCombiner
  regressed = .array~new; impactedSet = .set~new; impacted = .array~new
  do id over claims
    was = self~status(id, .nil)              /* baseline: the network's current model */
    now = self~status(id, newCombiner)       /* the new thinking model */
    if was["ok"] == .true, now["ok"] \== .true then do
      rr = .directory~new
      rr["id"] = id; rr["was"] = was["status"]; rr["now"] = now["status"]
      regressed~append(rr)
      do dec over self~dependents(id)
        if \impactedSet~hasItem(dec) then impactedSet~put(dec)
      end
    end
  end
  do dec over impactedSet
    wasD = self~status(dec, .nil); nowD = self~status(dec, newCombiner)
    di = .directory~new
    di["id"] = dec; di["was"] = wasD["status"]; di["now"] = nowD["status"]
    di["fell"] = (wasD["ok"] == .true & nowD["ok"] \== .true)
    di["failedDeps"] = nowD["failedDeps"]
    impacted~append(di)
  end
  rep = .directory~new
  rep["regressed"] = regressed
  rep["impacted"] = impacted
  if regressed~items = 0 then rep["headline"] = "nothing I concluded fails under the new model"
  else rep["headline"] = regressed~items "claim(s) now fail;" impacted~items "decision(s) rested on them"
  return rep

/* --------------------------------------------- a PRIOR, weaker combiner (ignores binding scope) */

::class NaiveEvidenceCombiner public
/* The mistake the corrected model fixes: it counts a ground regardless of whether its binding scope
   is on point, so a mail Message-ID "settles" verbatim authorship. Kept only to replay the past. */
::method evaluate
  use strict arg p
  grounds = p~grounds
  liveSupportTiers = .array~new; liveRebutTiers = .array~new; settleOK = .false
  do g over grounds
    if g~kind = "UNDERCUT" then iterate
    maxUnder = 0; eqUnder = .false
    do u over grounds
      if u~kind \= "UNDERCUT" then iterate
      if u~undercutsGroundId \= g~id then iterate
      if u~tier > g~tier then maxUnder = max(maxUnder, u~tier)
      else if u~tier = g~tier then eqUnder = .true
    end
    if maxUnder > g~tier | eqUnder then iterate        /* defeated / quarantined */
    if g~kind = "SUPPORT" then do
      liveSupportTiers~append(g~tier)
      if p~settleFloorRank > 0, g~tier >= p~settleFloorRank then settleOK = .true   /* NO binding check */
    end
    else if g~kind = "REBUT" then liveRebutTiers~append(g~tier)
  end
  s = 0; do t over liveSupportTiers; if t > s then s = t; end
  r = 0; do t over liveRebutTiers; if t > r then r = t; end
  select
    when s > r then stance = "PRO"
    when r > s then stance = "CONTRA"
    when s = r, s > 0 then stance = "DISPUTED"
    otherwise stance = "UNDETERMINED"
  end
  assertible = (stance = "PRO" & s >= p~assertFloorRank)
  settled = (stance = "PRO" & p~settleFloorRank > 0 & settleOK)
  select
    when settled then status = "SETTLED"
    when stance = "DISPUTED" then status = "DISPUTED"
    when stance = "PRO", assertible then status = "SUPPORTED"
    when stance = "PRO" then status = "HINT"
    otherwise status = "UNDETERMINED"
  end
  d = .directory~new
  d["stance"] = stance; d["status"] = status; d["assertible"] = assertible; d["settled"] = settled
  d["supportTier"] = s; d["rebutTier"] = r
  d["live"] = .array~new; d["defeated"] = .set~new; d["ineligible"] = .set~new; d["disputed"] = (stance = "DISPUTED")
  d["why"] = "naive prior model: binding scope ignored"
  return d

::requires "ReasonedThought.cls"
