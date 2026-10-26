/*
 * Proof of Analysis: an LLM ships a STRUCTURED, self-describing proof of its reasoning instead of
 * prose, so a second instance can RE-RUN it rather than re-read it, and any disagreement localises
 * to a single typed statement or a single warrant. (Tom's requirement, 2026-10-26.)
 *
 * Three independently contestable layers:
 *   statements     - the shared substrate (raw claims).
 *   categorisation - how each statement is TYPED (evidence class + binding), by an explicit,
 *                    versioned CategorisationPolicy. Open to debate, but a pure function once the
 *                    policy is fixed: two instances that disagree disagree about the POLICY, legibly.
 *   proof nature   - the structure (role: SUPPORT/REBUT/UNDERCUT, target, warrant). Disputing this
 *                    is "arguing about the nature of the proof itself".
 *
 * run() is self-describing: it emits a ProofCertificate (policy, per-statement categorisation,
 * per-proposition decision) that replays to a deterministic fingerprint. review() diffs two
 * certificates and classifies the divergence: WARRANT > CATEGORISATION > CONCLUSION_ONLY > AGREE.
 *
 * Author: Claude (Opus 4.8), 2026-10-26. Architecture: Tom Dyer.
 * Built on ReasonedThought.cls. Pure ooRexx 5.3; the replay fingerprint is a deterministic digest,
 * NOT cryptographic - a crypto hash (crypto.cls) is the later, optional hardening.
 */

/* --------------------------------------------- categorisation (the debatable-but-definitional layer) */

::class CategorisationPolicy public
::method init
  expose name version rules defaultClass defaultBinds
  use strict arg name, version = "1"
  rules = .directory~new            /* natureTag -> directory{class, binds} */
  defaultClass = "STYLOMETRIC"; defaultBinds = "GENERAL"
::attribute name get
::attribute version get
::method rule
  expose rules
  use strict arg natureTag, className, binds = "GENERAL"
  .EvidenceClass~of(className)       /* validate the class name now */
  d = .directory~new; d["class"] = className; d["binds"] = binds
  rules[natureTag] = d
  return self
::method categorise
  expose rules defaultClass defaultBinds
  use strict arg natureTag
  if rules~hasIndex(natureTag) then return rules[natureTag]
  d = .directory~new; d["class"] = defaultClass; d["binds"] = defaultBinds; d["default"] = .true
  return d

/* ------------------------------------------------------------------------------- a statement */

::class ProofStatement public
::method init
  expose id text nature role target undercutsId binds
  use strict arg id, text, nature, role, target, undercutsId = "", binds = .nil
  if \ .array~of("SUPPORT","REBUT","UNDERCUT")~hasItem(role) then -
    raise syntax 93.900 array("role must be SUPPORT, REBUT or UNDERCUT, not " role)
::attribute id get
::attribute text get
::attribute nature get
::attribute role get
::attribute target get
::attribute undercutsId get
::attribute binds get            /* intrinsic binding override (e.g. a Message-ID), else policy supplies */

/* ------------------------------------------------------------------------------------ a proof */

::class Proof public
::method init
  expose id theory statements policy combiner
  use strict arg id, policy, combiner = .nil
  theory = .array~new             /* proposition specs (directories) */
  statements = .array~new
::attribute id get
::method policy
  expose policy
  return policy
::method addProposition
  expose theory
  use strict arg spec
  theory~append(spec)
  return self
::method addStatement
  expose statements
  use strict arg s
  statements~append(s)
  return self
::method statements
  expose statements
  return statements
::method theory
  expose theory
  return theory

::method assemble
  expose id theory statements policy combiner
  net = .ThoughtNetwork~new(combiner)
  do spec over theory
    net~propose(spec["id"], spec["statement"], optOf(spec,"settleFloor",""), -
                optOf(spec,"assertFloor","TESTIMONY"), optOf(spec,"accepted",.nil))
  end
  u = .Utterance~new("proof:" || id, "assembled proof " || id)
  do s over statements
    cat = policy~categorise(s~nature)
    binds = s~binds; if binds == .nil then binds = cat["binds"]
    u~assert(s~role, cat["class"], s~target, s~undercutsId, binds, s~text, s~id)
  end
  net~admit(u)
  return net

::method run
  expose id theory statements policy principal
  use strict arg principal = ""
  net = self~assemble
  cert = .ProofCertificate~new(id, policy~name, policy~version, principal)
  do s over statements
    cat = policy~categorise(s~nature)
    binds = s~binds; if binds == .nil then binds = cat["binds"]
    cert~addCategorisation(s~id, s~nature, cat["class"], binds, s~role, s~target)
  end
  do spec over theory
    cert~addDecision(spec["id"], net~assess(spec["id"]))
  end
  cert~seal
  return cert

/* ------------------------------------------------------------------------- a self-describing certificate */

::class ProofCertificate public
::method init
  expose proofId policyName policyVersion principal cats decisions fingerprint
  use strict arg proofId, policyName, policyVersion, principal = ""
  cats = .directory~new; decisions = .directory~new; fingerprint = ""
::attribute proofId get
::attribute policyName get
::attribute policyVersion get
::attribute cats get
::attribute decisions get
::method addCategorisation
  expose cats
  use strict arg id, nature, className, binds, role, target
  d = .directory~new
  d["nature"] = nature; d["class"] = className; d["binds"] = binds; d["role"] = role; d["target"] = target
  cats[id] = d
::method addDecision
  expose decisions
  use strict arg id, belief
  d = .directory~new
  d["stance"] = belief["stance"]; d["status"] = belief["status"]
  d["assertible"] = belief["assertible"]; d["settled"] = belief["settled"]
  d["S"] = belief["supportTier"]; d["R"] = belief["rebutTier"]
  decisions[id] = d
::method seal
  expose fingerprint
  fingerprint = proofFingerprint(self~render)
  return fingerprint
::method fingerprint
  expose fingerprint
  return fingerprint
::method render
  expose proofId policyName policyVersion principal cats decisions
  out = .array~new
  out~append("PROOF" proofId "policy=" || policyName || "/" || policyVersion "by=" || principal)
  out~append("CATEGORISATION:")
  do id over sortedKeys(cats)
    c = cats[id]
    out~append("  " || id "nature=" || c["nature"] "=>" c["class"] "binds=" || c["binds"] "role=" || c["role"] "target=" || c["target"])
  end
  out~append("DECISIONS:")
  do id over sortedKeys(decisions)
    d = decisions[id]
    out~append("  " || id d["stance"] d["status"] "assertible=" || d["assertible"] "settled=" || d["settled"] "S=" || d["S"] "R=" || d["R"])
  end
  return joinLines(out)

/* --------------------------------------------------------- the reviewer (the second instance) */

::class ProofReview public
/* compare(certA, certB [, objections]) -> directory. objections: array of directories
   {on, reason, by} disputing a warrant/the proof's nature. */
::method compare class
  use strict arg a, b, objections = .nil
  catDiffs = .array~new; concDiffs = .array~new
  /* categorisation divergence: same statement typed differently */
  do id over sortedKeys(a~cats)
    if \ b~cats~hasIndex(id) then iterate
    ca = a~cats[id]; cb = b~cats[id]
    if ca["class"] \= cb["class"] | ca["binds"] \= cb["binds"] then do
      d = .directory~new
      d["id"] = id; d["a"] = ca["class"] "/" ca["binds"]; d["b"] = cb["class"] "/" cb["binds"]
      catDiffs~append(d)
    end
  end
  /* conclusion divergence: same proposition decided differently */
  do id over sortedKeys(a~decisions)
    if \ b~decisions~hasIndex(id) then iterate
    da = a~decisions[id]; db = b~decisions[id]
    if da["status"] \= db["status"] | da["assertible"] \= db["assertible"] | da["settled"] \= db["settled"] then do
      d = .directory~new
      d["id"] = id; d["a"] = da["status"] "(assertible=" || da["assertible"] || ",settled=" || da["settled"] || ")"
      d["b"] = db["status"] "(assertible=" || db["assertible"] || ",settled=" || db["settled"] || ")"
      concDiffs~append(d)
    end
  end
  obj = objections; if obj == .nil then obj = .array~new
  select
    when obj~items > 0 then classification = "WARRANT"           /* a dispute about the proof's nature */
    when catDiffs~items > 0 then classification = "CATEGORISATION" /* they typed a statement differently */
    when concDiffs~items > 0 then classification = "CONCLUSION_ONLY" /* same inputs, different decision rule */
    otherwise classification = "AGREE"
  end
  r = .directory~new
  r["classification"] = classification
  r["categorisationDiffs"] = catDiffs
  r["conclusionDiffs"] = concDiffs
  r["objections"] = obj
  r["sameFingerprint"] = (a~fingerprint = b~fingerprint)
  return r

/* ----------------------------------------------------------------- the MCP service surface */

::class ProofExchangeMcpOperations public
/* dispatch(op, request, principal). The certificate render() string is the wire form; a real
   transport ships text and parses it back. ops: proof.review, proof.run. */
::method dispatch
  use strict arg op, request, principal = ""
  select
    when op = "proof.run" then do
      cert = request["proof"]~run(principal)
      reply = .directory~new; reply["ok"] = 1; reply["fingerprint"] = cert~fingerprint
      reply["certificate"] = cert~render; reply["cert"] = cert
      return reply
    end
    when op = "proof.review" then do
      if request~hasIndex("objections") then objs = request["objections"]
      else objs = .nil
      rv = .ProofReview~compare(request["a"], request["b"], objs)
      rv["ok"] = 1; rv["reviewer"] = principal
      return rv
    end
    otherwise do
      reply = .directory~new; reply["ok"] = 0; reply["error"] = "unknown op " || op
      return reply
    end
  end

/* ----------------------------------------------------------------------------- routines */

::routine optOf
  use strict arg dir, key, default
  if dir~hasIndex(key) then return dir[key]
  return default

::routine joinLines
  use strict arg arr
  out = ""
  do i = 1 to arr~items
    if i = 1 then out = arr[i]
    else out = out || "0a"x || arr[i]
  end
  return out

::routine sortedKeys
  use strict arg dir
  a = .array~new
  do k over dir~allIndexes; a~append(k); end
  a~sort
  return a

::routine proofFingerprint
  /* deterministic, order-stable digest for replay equality; not cryptographic */
  use strict arg str
  numeric digits 20            /* keep the running hash an exact whole number, not float */
  h = 0
  do i = 1 to length(str)
    h = (h * 131 + c2d(substr(str, i, 1))) // 2147483647
  end
  return d2x(h, 8)

::requires "ReasonedThought.cls"
