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
::method allRules
  expose rules
  return rules
::method defaultClass
  expose defaultClass
  return defaultClass
::method defaultBinds
  expose defaultBinds
  return defaultBinds
::method setDefault
  expose defaultClass defaultBinds
  use strict arg className, binds
  defaultClass = className; defaultBinds = binds
  return self
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
    cert~addCategorisation(s~id, s~nature, cat["class"], binds, s~role, s~target, s~undercutsId)
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
  use strict arg id, nature, className, binds, role, target, undercuts = ""
  d = .directory~new
  d["nature"] = nature; d["class"] = className; d["binds"] = binds
  d["role"] = role; d["target"] = target; d["undercuts"] = undercuts
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
  /* principal is metadata, deliberately NOT in the fingerprinted body: a proof's identity is its
     inputs and decisions, so an independent replay by another principal yields the same fingerprint */
  out~append("PROOF" proofId "policy=" || policyName || "/" || policyVersion)
  out~append("CATEGORISATION:")
  do id over sortedKeys(cats)
    c = cats[id]
    uc = c["undercuts"]; if uc == .nil then uc = ""
    out~append("  " || id "nature=" || c["nature"] "=>" c["class"] "binds=" || c["binds"] "role=" || c["role"] "target=" || c["target"] "undercuts=" || uc)
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
  catDiffs = .array~new; structDiffs = .array~new; concDiffs = .array~new
  missing = .array~new    /* statements in A, absent from B */
  extra = .array~new      /* statements in B, absent from A */
  do id over sortedKeys(a~cats)
    if \ b~cats~hasIndex(id) then do; missing~append(id); iterate; end
    ca = a~cats[id]; cb = b~cats[id]
    if ca["class"] \= cb["class"] | ca["binds"] \= cb["binds"] then do
      d = .directory~new; d["id"] = id
      d["a"] = ca["class"] "/" ca["binds"]; d["b"] = cb["class"] "/" cb["binds"]
      catDiffs~append(d)
    end
    /* structure: role, target, and the undercut link - NOT just categorisation (REQ-00000201) */
    if ca["role"] \= cb["role"] | ca["target"] \= cb["target"] | self~uc(ca) \= self~uc(cb) then do
      d = .directory~new; d["id"] = id
      d["a"] = ca["role"] "->" ca["target"] self~ucTag(ca)
      d["b"] = cb["role"] "->" cb["target"] self~ucTag(cb)
      structDiffs~append(d)
    end
  end
  do id over sortedKeys(b~cats)
    if \ a~cats~hasIndex(id) then extra~append(id)
  end
  do id over sortedKeys(a~decisions)
    if \ b~decisions~hasIndex(id) then iterate
    da = a~decisions[id]; db = b~decisions[id]
    if da["status"] \= db["status"] | da["assertible"] \= db["assertible"] | da["settled"] \= db["settled"] then do
      d = .directory~new; d["id"] = id
      d["a"] = da["status"] "(assertible=" || da["assertible"] || ",settled=" || da["settled"] || ")"
      d["b"] = db["status"] "(assertible=" || db["assertible"] || ",settled=" || db["settled"] || ")"
      concDiffs~append(d)
    end
  end
  /* An objection is a CLAIM, not a verdict: only an ACCEPTED rebuttal overturns the proof; a
     pending objection is recorded and reported, nothing more (REQ-00000201). */
  accepted = .array~new; pending = .array~new
  if objections \== .nil then do o over objections
    st = "PENDING"
    if o~hasIndex("status") then st = o["status"]
    if o~hasIndex("accepted"), o["accepted"] == .true then st = "ACCEPTED"
    if st = "ACCEPTED" then accepted~append(o); else pending~append(o)
  end
  structural = (structDiffs~items > 0 | missing~items > 0 | extra~items > 0)
  select
    when accepted~items > 0 then classification = "WARRANT"
    when structural then classification = "STRUCTURE"
    when catDiffs~items > 0 then classification = "CATEGORISATION"
    when concDiffs~items > 0 then classification = "CONCLUSION_ONLY"
    otherwise classification = "AGREE"
  end
  r = .directory~new
  r["classification"] = classification
  r["categorisationDiffs"] = catDiffs
  r["structuralDiffs"] = structDiffs
  r["missing"] = missing; r["extra"] = extra
  r["conclusionDiffs"] = concDiffs
  r["acceptedObjections"] = accepted; r["pendingObjections"] = pending
  r["sameFingerprint"] = (a~fingerprint = b~fingerprint)
  return r

::method uc class private
  use strict arg c
  u = c["undercuts"]; if u == .nil then return ""
  return u

::method ucTag class private
  use strict arg c
  u = self~uc(c); if u = "" then return ""
  return "(undercuts " || u || ")"

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

/* ----------------------------------------------------- self-contained wire bundle (REQ-00000199) */

::class ProofBundle public
/* Canonical, versioned TEXT form of a whole proof: policy + theory + statements AND the claimed
   decisions, sealed with a hash over the body. serialize -> parse -> rebuild -> run lets a second
   PROCESS verify that the decisions follow from the stated inputs, working only from the text and
   without trusting the first agent. This is the self-contained proof, not just a summary. */
::method serialize class
  use strict arg proof
  pol = proof~policy
  L = .array~new
  L~append("PROOFBUNDLE/1")
  L~append("PROOF" proof~id)
  L~append("POLICY" pol~name pol~version)
  L~append("POLICYDEFAULT" pol~defaultClass pol~defaultBinds)
  rt = pol~allRules
  do nat over sortedKeys(rt)
    r = rt[nat]; L~append("RULE" nat r["class"] r["binds"])
  end
  specs = .directory~new
  do spec over proof~theory; specs[spec["id"]] = spec; end
  do pid over sortedKeys(specs)
    spec = specs[pid]
    sf = optOf(spec, "settleFloor", ""); if sf = "" then sf = "*"
    af = optOf(spec, "assertFloor", "TESTIMONY"); if af = "" then af = "*"
    acc = "*"
    if spec~hasIndex("accepted"), spec["accepted"] \== .nil then acc = joinCsv(spec["accepted"])
    L~append("PROP" pid "|" sf "|" af "|" acc "|" spec["statement"])
  end
  smap = .directory~new
  do s over proof~statements; smap[s~id] = s; end
  do sid over sortedKeys(smap)
    s = smap[sid]
    uc = s~undercutsId; if uc = "" then uc = "*"
    bd = s~binds; if bd == .nil then bd = "*"
    L~append("STMT" sid "|" s~role "|" s~target "|" uc "|" s~nature "|" bd "|" s~text)
  end
  cert = proof~run("")
  do pid over sortedKeys(cert~decisions)
    d = cert~decisions[pid]
    L~append("DECISION" pid "|" d["stance"] "|" d["status"] "|" d["assertible"] "|" d["settled"] "|" d["S"] "|" d["R"])
  end
  body = joinLines(L)
  return body || "0a"x || "BUNDLEHASH" proofFingerprint(body)

::method parse class
  use strict arg text
  p = .directory~new
  p["policyName"] = ""; p["policyVersion"] = "1"; p["defClass"] = "STYLOMETRIC"; p["defBinds"] = "GENERAL"
  p["proofId"] = ""; p["rules"] = .array~new; p["props"] = .array~new; p["statements"] = .array~new
  p["decisions"] = .directory~new; p["bundleHash"] = ""
  bodyL = .array~new
  do line over text~makeArray("0a"x)
    w = word(line, 1)
    select
      when w = "BUNDLEHASH" then do; parse var line . hh; p["bundleHash"] = hh; end
      when w = "PROOFBUNDLE/1" then bodyL~append(line)
      when w = "PROOF" then do; parse var line . pid; p["proofId"] = pid; bodyL~append(line); end
      when w = "POLICY" then do; parse var line . nm vr; p["policyName"] = nm; p["policyVersion"] = vr; bodyL~append(line); end
      when w = "POLICYDEFAULT" then do; parse var line . dc db; p["defClass"] = dc; p["defBinds"] = db; bodyL~append(line); end
      when w = "RULE" then do
        parse var line . nat cls bnds
        d = .directory~new; d["nat"] = nat; d["class"] = cls; d["binds"] = bnds
        p["rules"]~append(d); bodyL~append(line)
      end
      when w = "PROP" then do
        parse var line "PROP " rest
        parse var rest pid " | " sf " | " af " | " acc " | " statement
        d = .directory~new; d["id"] = pid; d["statement"] = statement
        if sf \= "*" then d["settleFloor"] = sf
        if af \= "*" then d["assertFloor"] = af; else d["assertFloor"] = "TESTIMONY"
        if acc \= "*" then d["accepted"] = splitCsv(acc)
        p["props"]~append(d); bodyL~append(line)
      end
      when w = "STMT" then do
        parse var line "STMT " rest
        parse var rest sid " | " role " | " target " | " uc " | " nat " | " bd " | " txt
        if uc = "*" then uc = ""
        if bd = "*" then bindsV = .nil; else bindsV = bd
        p["statements"]~append(.ProofStatement~new(sid, txt, nat, role, target, uc, bindsV))
        bodyL~append(line)
      end
      when w = "DECISION" then do
        parse var line "DECISION " rest
        parse var rest pid " | " stance " | " status " | " assertible " | " settled " | " ss " | " rr
        d = .directory~new; d["stance"] = stance; d["status"] = status
        d["assertible"] = (assertible = 1); d["settled"] = (settled = 1); d["S"] = ss; d["R"] = rr
        p["decisions"][pid] = d; bodyL~append(line)
      end
      otherwise nop
    end
  end
  p["body"] = joinLines(bodyL)
  return p

::method rebuild class
  use strict arg p
  pol = .CategorisationPolicy~new(p["policyName"], p["policyVersion"])
  pol~setDefault(p["defClass"], p["defBinds"])
  do r over p["rules"]; pol~rule(r["nat"], r["class"], r["binds"]); end
  proof = .Proof~new(p["proofId"], pol)
  do spec over p["props"]; proof~addProposition(spec); end
  do s over p["statements"]; proof~addStatement(s); end
  return proof

::method verify class
  use strict arg text
  p = self~parse(text)
  integrity = (proofFingerprint(p["body"]) = p["bundleHash"])
  proof = self~rebuild(p)
  cert = proof~run("")
  mism = .array~new
  do pid over p["decisions"]~allIndexes
    claimed = p["decisions"][pid]; got = cert~decisions[pid]
    if got == .nil then do; mism~append(pid "absent on recompute"); iterate; end
    if got["status"] \= claimed["status"] | got["stance"] \= claimed["stance"] -
       | got["assertible"] \== claimed["assertible"] | got["settled"] \== claimed["settled"] then -
      mism~append(pid "claimed " || claimed["status"] " got " || got["status"])
  end
  soundness = (mism~items = 0)
  r = .directory~new
  r["ok"] = (integrity & soundness); r["integrity"] = integrity; r["soundness"] = soundness
  r["mismatches"] = mism; r["fingerprint"] = cert~fingerprint
  return r

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

::routine joinCsv
  use strict arg arr
  out = ""
  do i = 1 to arr~items
    if i = 1 then out = arr[i]
    else out = out || "," || arr[i]
  end
  return out

::routine splitCsv
  use strict arg str
  a = .array~new
  rest = str
  do while rest \= ""
    parse var rest item "," rest
    if item \= "" then a~append(item)
  end
  return a

::requires "ReasonedThought.cls"
