/* SLAM's evidence argued by the Reasoned Thought engine; SLAM's actions resting on the conclusions.
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-29.  Engine: oorexx_reasoned_thought_v0.1
 * (Claude (Opus 4.8); combiner design ChatGPT (GPT-6)), used unchanged.
 * Args: scratch dir | alchemy checkout
 *
 *  1. one input and every input: per-value proofs settle each value; "every input" stays UNDETERMINED with
 *     the proofs on record as INELIGIBLE; one counterexample REBUTS it
 *  2. agreement is not accuracy, as tiers: two routines agreeing (DOCUMENTARY) lose to a certificate
 *     (PROVENANCE) that says the shared answer is not the nearest 9-digit root
 *  3. who wrote it and who committed it: a credit line supports authorship; a commit trailer settles who
 *     committed and is INELIGIBLE for authorship
 *  4. decisions SLAM acts on: the FDSqrt fix is justified; using the old FDSqrt on large inputs is refused,
 *     with the reason; SLAM then picks the routine it may use
 *  5. a statement made to SLAM, checked: Gemini's "a tested score is the count of true results divide by
 *     the count of all results" is REBUTTED by SLAM's own code run; saying it again does not move it
 *  6. the overclaim a weaker thinking model makes: without binding scopes, the per-value proofs would
 *     SETTLE "correct for every input"
 */
signal on syntax name onSyntax
parse arg work '|' repo
checks = 0
P = repo || '/packages'
fixture = P || '/oorexx_slam_v0.1/tests/fixtures/fdsqrt_fixed14.cls'
door = P || '/fd_door_micro_motion_v0.2-dev8/src/FDDoorMicroMotion.cls'
c = .SlamComposer~new
old = c~lift(fixture, 'FDSqrt', 'OLD')
now = c~lift(door, 'FDSqrt', 'NOW')
vs = c~lift(P || '/oorexx_vision/src/Vision.cls', 'rx_vision_sqrt', 'VSQRT')
r = .SlamReasoning~new
tol = 0.00000001
small = .array~of(0.25, 2, 10, 1000, 999999, 1000000)
large = .array~of(1000001, 10000000, 99999999, 100000000, 1000000000, 1E12, 4E18)
values = small~union(large)

say '== 1. one input, and every input'
do x over values
  ignored = r~certificate('FDSqrt.now', x, .SlamCertify~sqrtWithin(x, now~routine~call(x), tol))
  ignored = r~certificate('FDSqrt.old', x, .SlamCertify~sqrtWithin(x, old~routine~call(x), tol))
end
v = r~assess(r~valueClaim('FDSqrt.now', 100000000))
call check v['status'] == 'SETTLED', 'FDSqrt.now at 1e8: SETTLED by its certificate'
a = r~assess(r~allClaim('FDSqrt.now'))
call check a['status'] == 'UNDETERMINED' & a['ineligible']~items = values~items, 'FDSqrt.now for every input: UNDETERMINED; all' values~items 'proofs on record as INELIGIBLE (they bind one value each)'
a = r~assess(r~allClaim('FDSqrt.old'))
call check a['status'] == 'REBUTTED', 'FDSqrt.old for every input: REBUTTED by its counterexamples'
f = r~assess(r~failsClaim('FDSqrt.old'))
call check f['status'] == 'SETTLED', 'FDSqrt.old gives a false result for some input: SETTLED'

say '== 2. agreement is not accuracy, as tiers'
do x over .array~of(0.5, 2)
  rn = now~routine~call(x); rv = vs~routine~call(x)
  ignored = r~agreement('FDSqrt.now.nearest9', 'rx_vision_sqrt', x, rn = rv)
  ignored = r~certificate('FDSqrt.now.nearest9', x, .SlamCertify~sqrtNearest(x, rn, 9))
end
h = r~assess(r~valueClaim('FDSqrt.now.nearest9', 0.5))
call check h['status'] == 'REBUTTED' & h['supportTier'] = 3 & h['rebutTier'] = 4, 'x=0.5: the two routines agree (DOCUMENTARY, tier 3); the certificate says not the nearest (PROVENANCE, tier 4): REBUTTED'
h = r~assess(r~valueClaim('FDSqrt.now.nearest9', 2))
call check h['status'] == 'SETTLED', 'x=2: agreement and certificate both say yes: SETTLED (by the certificate, not the agreement)'

say '== 3. who wrote it, who committed it'
unit = 'FDSqrt.old'
ignored = r~provenance(unit, .SlamProvenance~ofFile(fixture))
lines = findLines(fixture, '::routine FDSqrt public')
g = .SlamProvenance~ofLines(repo, fixture~substr(repo~length + 2), lines[1], lines[2], .directory~new)
ignored = r~provenance(unit, g)
w1 = r~assess(r~authorClaim(unit, 'ChatGPT'))
w2 = r~assess(r~authorClaim(unit, g['TOOL']))
c2 = r~assess(r~committerClaim(unit, g['TOOL']))
call check w1['status'] == 'SUPPORTED' & \w1['settled'], 'ChatGPT wrote it: SUPPORTED by its header (TESTIMONY), not settled'
call check w2['status'] == 'UNDETERMINED' & w2['ineligible']~items = 1, g['TOOL'] 'wrote it: UNDETERMINED; the commit trailer is on record as INELIGIBLE (it binds the commit)'
call check c2['status'] == 'SETTLED', 'a' g['TOOL'] 'session committed it: SETTLED by the commit record'

say '== 4. decisions SLAM acts on'
newTested = .array~new
do x over values
  newTested~append(.array~of(r~valueClaim('FDSqrt.now', x), 'settled'))
end
ignored = r~decide('D.now.tested', 'FDSqrt.now is right on every value tested', newTested)
same = .array~new
do x over small
  sid = r~claim('SAME:' || x, 'FDSqrt.now gives the same output as FDSqrt.old at' x)
  if now~routine~call(x) == old~routine~call(x) then r~evidenceFor(sid, 'DOCUMENTARY', 'both run at' x || ': same output')
  else r~evidenceAgainst(sid, 'DOCUMENTARY', 'both run at' x || ': outputs differ')
  same~append(.array~of(sid, 'assertible'))
end
ignored = r~decide('D.same.small', 'the change keeps every small result the same', same)
ignored = r~decide('D.fix', 'the FDSqrt change is justified', .array~of(.array~of(r~failsClaim('FDSqrt.old'), 'settled'), .array~of('D.now.tested', 'assertible'), .array~of('D.same.small', 'assertible')))
m = r~mayAct('D.fix')
call check m['OK'], 'the FDSqrt change is justified: SUPPORTED (old fails somewhere, settled; new right on every value tested; small results unchanged)'
useOld = .array~new
do x over large
  useOld~append(.array~of(r~valueClaim('FDSqrt.old', x), 'assertible'))
end
ignored = r~decide('D.use.old.large', 'use FDSqrt.old on inputs above 1e6', useOld)
m = r~mayAct('D.use.old.large')
say '       refused:' m['WHY']~left(150)
call check \m['OK'] & m['WHY']~pos('REBUTTED') > 0, 'use FDSqrt.old on inputs above 1e6: refused, and the reason names the rebutted claims'
choice = ''
do cand over .array~of('old', 'now')
  ignored = r~decide('D.use.' || cand, 'use FDSqrt.' || cand 'on 1e8', .array~of(.array~of(r~valueClaim('FDSqrt.' || cand, 100000000), 'settled')))
  if choice == '' & r~mayAct('D.use.' || cand)['OK'] then choice = cand
end
call check choice == 'now', 'asked to take a square root of 1e8, SLAM may not use FDSqrt.old and takes FDSqrt.now'

say '== 5. a statement made to SLAM, checked'
said = r~statement('gemini.score', 'a tested score is the count of true results divide by the count of all results', 'Gemini')
s1 = r~assess(said)
call check s1['status'] == 'SUPPORTED', 'on Gemini''s word alone (TESTIMONY): SUPPORTED, as any assertion is until checked'
w = .SlamStore~wilson(1, 1)
r~evidenceAgainst(said, 'DOCUMENTARY', 'SlamStore~wilson(1, 1) runs to' w || ', not 1 of 1 = 1: the score is the Wilson lower bound')
s2 = r~assess(said)
call check s2['status'] == 'REBUTTED', 'after SLAM runs its own scoring code (DOCUMENTARY: 1 of 1 scores' w || '): REBUTTED'
ignored = r~statement('gemini.score', 'a tested score is the count of true results divide by the count of all results', 'Gemini, again, more firmly')
s3 = r~assess(said)
call check s3['status'] == 'REBUTTED', 'said again, more firmly: still REBUTTED (more testimony is not a higher tier)'

say '== 6. the overclaim a weaker thinking model makes'
naive = r~net~assess(r~allClaim('FDSqrt.now'), .NaiveEvidenceCombiner~new)
say '       naive model, FDSqrt.now for every input:' naive['status']
call check naive['status'] == 'SETTLED', 'ignoring binding scope, the' values~items 'per-value proofs would SETTLE "correct for every input": the overclaim the binding scope stops'
say 'REASONING TEST: PASS (' || checks || ' checks)'
exit 0

findLines: procedure
  use arg path, head
  s = .stream~new(path); s~open('READ'); n = 0; first = 0; last = 0
  do while s~lines > 0
    t = s~linein; n += 1
    if first = 0 then do
      if t~strip == head then first = n
      iterate
    end
    if t~strip~left(2) == '::' then leave
    if t~strip \== '' then last = n
  end
  s~close
  return .array~of(first, last)

check: procedure expose checks
  use arg ok, label
  checks += 1
  if ok then say 'PASS ' label
  else do
    say 'FAIL ' label
    exit 1
  end
  return

onSyntax:
  say 'SYNTAX rc=' || rc 'sigl=' || sigl condition('C') condition('D')
  exit 1

::requires 'SlamReasoning.cls'
::requires 'SlamProvenance.cls'
::requires 'SlamCompose.cls'
::requires 'SlamProof.cls'
::requires 'SlamStore.cls'
