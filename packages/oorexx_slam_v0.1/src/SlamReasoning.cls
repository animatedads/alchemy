/* SlamReasoning.cls - SLAM's evidence argued by the Reasoned Thought engine, and SLAM's actions resting
 * on the conclusions.
 *
 * Architecture: Tom Dyer ("SLAM would be dangerously effective if it could engage the rational thinking
 * engine").  Code: Claude (Opus 5.5), 2026-10-29.  The engine (oorexx_reasoned_thought_v0.1) is used as it
 * is, not changed: object model and journal by Claude (Opus 4.8), combiner design by ChatGPT (GPT-6).
 *
 * SLAM finds evidence; the engine decides what that evidence settles.  Every piece of SLAM evidence becomes
 * a Ground with an evidence TIER (how strong) and a BINDING scope (what it is about):
 *
 *   SLAM evidence                                   tier           why that tier
 *   a shape resembles another; an edge's prior      STYLOMETRIC    resemblance is a hunch
 *   a credit line, a README, a contract read from   TESTIMONY      something asserts it
 *     code, a model's statement
 *   a recorded run, two ways agreeing, a commit     DOCUMENTARY    a dated record
 *   an exact certificate, PROVED or DISPROVED       PROVENANCE     anyone can re-check it
 *
 *   binding        what the evidence proves                      accepted by
 *   VALUE          the claim holds for one stated input          the claim about that input
 *   COUNTEREXAMPLE one input where it fails                      the claim about that input, and the
 *                                                                 claim about every input
 *   AUTHORSHIP     who wrote the code                            "T wrote U"
 *   COMMIT         who committed it                              "T committed U"
 *
 * So the engine, not SLAM, enforces what SLAM had to hand-code: per-value proofs never settle "for every
 * input" (they bind VALUE: recorded INELIGIBLE), while one counterexample refutes it; agreement between two
 * routines (DOCUMENTARY) never outranks a certificate (PROVENANCE); a commit trailer is not authorship.
 *
 * Decisions ("the fix is justified", "use this routine here") are BeliefJournal decisions resting on
 * claims; SLAM asks mayAct before acting, and gets the reason when the answer is no.
 */
::requires 'ReasonedThought.cls'
::requires 'BeliefJournal.cls'

::class SlamReasoning public
::attribute net get
::attribute journal get
::method init
  expose net journal seq
  net = .ThoughtNetwork~new
  journal = .BeliefJournal~new(net)
  seq = 0

::method nextId private
  expose seq
  use strict arg stem
  seq += 1
  return stem || '.' || seq

/* A claim, made once: ID, statement, floor to settle, bindings it accepts.  Returns the id used (blanks
   become _: the journal names a failed claim by its first word). */
::method claim
  expose net journal
  use strict arg id, statement, settleFloor = 'DOCUMENTARY', accepted = .nil
  id = id~translate('_', ' ')
  if net~proposition(id) == .nil then journal~claim(id, statement, settleFloor, 'TESTIMONY', accepted)
  return id

/* ---- correctness: one input, and every input ---- */
::method valueClaim
  use strict arg unit, x
  return self~claim('CORRECT:' || unit || ':' || x, unit 'gives a correct result for' x, 'PROVENANCE', .array~of('VALUE', 'COUNTEREXAMPLE'))
::method allClaim
  use strict arg unit
  return self~claim('CORRECT_ALL:' || unit, unit 'gives a correct result for every input', 'PROVENANCE', .array~of('COUNTEREXAMPLE', 'ALL_INPUTS'))
::method failsClaim
  use strict arg unit
  return self~claim('FAILS_SOMEWHERE:' || unit, unit 'gives a false result for some input', 'PROVENANCE', .array~of('COUNTEREXAMPLE'))

/* A certificate about UNIT at X (a Maths MathProof from SlamCertify).  PROVED supports the claim about X,
   and is offered to the claim about every input too, where its binding (VALUE) makes it INELIGIBLE: on the
   record, not counted.  DISPROVED is a counterexample: it rebuts both, and supports "fails somewhere". */
::method certificate
  expose net
  use strict arg unit, x, proof
  vc = self~valueClaim(unit, x); ac = self~allClaim(unit); fc = self~failsClaim(unit)
  u = .Utterance~new(self~nextId('cert'), proof~claim~kind 'for' unit 'at' x || ':' proof~outcome)
  select
    when proof~outcome == 'PROVED' then do
      u~assert('SUPPORT', 'PROVENANCE', vc, , 'VALUE', 'certificate checked in exact rationals')
      u~assert('SUPPORT', 'PROVENANCE', ac, , 'VALUE', 'one value proved is not every value')
    end
    when proof~outcome == 'DISPROVED' then do
      u~assert('REBUT', 'PROVENANCE', vc, , 'COUNTEREXAMPLE', 'certificate: false at' x)
      u~assert('REBUT', 'PROVENANCE', ac, , 'COUNTEREXAMPLE', 'a counterexample at' x)
      u~assert('SUPPORT', 'PROVENANCE', fc, , 'COUNTEREXAMPLE', 'false at' x)
    end
    otherwise return vc                      /* INDETERMINATE: no ground, nothing to weigh */
  end
  net~admit(u)
  return vc

/* Two routines gave the same number at X (a recorded run): DOCUMENTARY support for each one's value claim.
   Never enough to settle it, and outranked by a certificate that says otherwise (Maths rule 9). */
::method agreement
  expose net
  use strict arg unit, other, x, agreed
  vc = self~valueClaim(unit, x)
  u = .Utterance~new(self~nextId('agree'), unit 'and' other 'at' x)
  if agreed then u~assert('SUPPORT', 'DOCUMENTARY', vc, , 'VALUE', 'agrees with' other)
  else u~assert('REBUT', 'DOCUMENTARY', vc, , 'VALUE', 'disagrees with' other)
  net~admit(u)
  return vc

/* ---- who wrote it, who committed it ---- */
::method authorClaim
  use strict arg unit, tool
  return self~claim('WROTE:' || tool || ':' || unit, tool 'wrote' unit, 'DOCUMENTARY', .array~of('AUTHORSHIP'))
::method committerClaim
  use strict arg unit, tool
  return self~claim('COMMITTED:' || tool || ':' || unit, 'a' tool 'session committed' unit, 'DOCUMENTARY', .array~of('COMMIT'))

/* A provenance record from SlamProvenance (TOOL LEVEL EVIDENCE).  A credit line is TESTIMONY about
   authorship; a git trailer is a DOCUMENTARY record of a commit, offered to the authorship claim too,
   where its binding makes it INELIGIBLE. */
::method provenance
  expose net
  use strict arg unit, prov
  tool = prov['TOOL']
  if tool == 'NOT_RECORDED' then return ''
  u = .Utterance~new(self~nextId('prov'), prov['EVIDENCE']~left(120))
  if prov['LEVEL'] == 'GIT' then do
    u~assert('SUPPORT', 'DOCUMENTARY', self~committerClaim(unit, tool), , 'COMMIT', 'Co-Authored-By trailer')
    u~assert('SUPPORT', 'DOCUMENTARY', self~authorClaim(unit, tool), , 'COMMIT', 'a commit is not authorship')
  end
  else u~assert('SUPPORT', 'TESTIMONY', self~authorClaim(unit, tool), , 'AUTHORSHIP', prov['LEVEL'] 'credit line')
  net~admit(u)
  return self~authorClaim(unit, tool)

/* ---- a statement made to SLAM (by a model, a reviewer, a person), and what SLAM's evidence says ---- */
::method statement
  expose net
  use strict arg id, text, who
  cid = self~claim('SAID:' || id, text, 'DOCUMENTARY', .nil)
  u = .Utterance~new(self~nextId('said'), who || ':' text)
  u~assert('SUPPORT', 'TESTIMONY', cid, , 'GENERAL', who 'says so')
  net~admit(u)
  return cid
::method evidenceAgainst
  expose net
  use strict arg claimId, tierName, note, binds = 'GENERAL'
  u = .Utterance~new(self~nextId('against'), note)
  u~assert('REBUT', tierName, claimId, , binds, note)
  net~admit(u)
::method evidenceFor
  expose net
  use strict arg claimId, tierName, note, binds = 'GENERAL'
  u = .Utterance~new(self~nextId('for'), note)
  u~assert('SUPPORT', tierName, claimId, , binds, note)
  net~admit(u)

/* ---- decisions SLAM acts on ---- */
::method decide
  expose journal
  use strict arg id, statement, rests
  journal~decision(id, statement)
  do r over rests                         /* each: .array(claimId, 'assertible' | 'settled') */
    journal~restsOn(id, r[1], r[2])
  end
  return id
/* May SLAM act on decision ID?  A Directory: OK, STATUS, WHY (the claims that fail, and each one's why). */
::method mayAct
  expose net journal
  use strict arg id
  s = journal~status(id)
  out = .directory~new
  out['OK'] = s['ok'] == .true
  out['STATUS'] = s['status']
  why = ''
  do f over s['failedDeps']
    cid = f~word(1)
    why = why '|' f
    if net~proposition(cid) \== .nil then why = why '->' self~assess(cid)['status']
  end
  out['WHY'] = why~strip
  return out
::method assess
  expose net
  use strict arg id
  return net~assess(id)
