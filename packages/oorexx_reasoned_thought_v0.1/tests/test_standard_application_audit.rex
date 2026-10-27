/* Reasoned Thought qualification 15: disparate-treatment / even-handedness (Sonnet #5).
 * ADVERSARIAL fixture: written to try to BREAK the StandardApplicationAudit operator,
 * per Sonnet #6 - the implementer must not write its own pass-test. Each case is chosen
 * to FAIL against a degenerate operator, so passing means the operator actually reasons:
 *   - an always-CONSISTENT operator fails cases 1,2 (misses real disparity);
 *   - an always-DISPARATE operator fails case 3 (false positive);
 *   - an "any outcome difference = disparate" operator fails case 4 (the real discriminator:
 *     a bigger problem justifying rejection is even-handed, not disparate);
 *   - an operator that ignores the decision-maker's own reach fails case 5 (unmeetable bar).
 *
 * Synthetic and domain-neutral (CHAIN_X / CHAIN_Y). It asks only "was the stated standard
 * applied evenly", never "is the underlying claim true" - the scope ceiling (Sonnet #4).
 *
 * Architecture: Tom Dyer. Reference operator: Claude (Opus 4.8, strawman for ChatGPT's
 * authoritative version). This adversarial test: Claude (Opus 4.8). Pure ooRexx 5.3.
 */
signal on syntax name onSyntax

/* 1. equal problem, opposite disposition -> DISPARATE (kills always-CONSISTENT) */
a = .StandardApplicationAudit~new
a~standard('S_INCON','DISQUALIFY','internal_inconsistency')
a~applied('S_INCON','CHAIN_X', 2, 'REJECTED')
a~applied('S_INCON','CHAIN_Y', 2, 'ACCEPTED')
r = a~audit('S_INCON')
call check r['classification']='DISPARATE_TREATMENT', -
  "equal inconsistency, one rejected one accepted => disparate treatment"
call check r['pairs']~items=1 & r['pairs'][1]['rejected']='CHAIN_X' & r['pairs'][1]['accepted']='CHAIN_Y', -
  "the finding NAMES the asymmetric pair (structural, not a verdict)"

/* 2. the accepted chain's problem is WORSE, yet it was accepted -> DISPARATE */
b = .StandardApplicationAudit~new
b~standard('S2','DISQUALIFY','internal_inconsistency')
b~applied('S2','CHAIN_X', 2, 'REJECTED')
b~applied('S2','CHAIN_Y', 3, 'ACCEPTED')
call check b~audit('S2')['classification']='DISPARATE_TREATMENT', -
  "rejecting the milder problem while accepting the worse one is disparate"

/* 3. same problem, same disposition -> CONSISTENT (kills always-DISPARATE) */
c = .StandardApplicationAudit~new
c~standard('S3','DISQUALIFY','internal_inconsistency')
c~applied('S3','CHAIN_X', 2, 'REJECTED')
c~applied('S3','CHAIN_Y', 2, 'REJECTED')
call check c~audit('S3')['classification']='CONSISTENT_APPLICATION', -
  "same problem, same outcome => consistent (no false positive)"

/* 4. THE DISCRIMINATOR: outcomes differ but the rejected chain is genuinely worse
      -> CONSISTENT (kills 'any outcome difference = disparate') */
d = .StandardApplicationAudit~new
d~standard('S4','DISQUALIFY','internal_inconsistency')
d~applied('S4','CHAIN_X', 3, 'REJECTED')
d~applied('S4','CHAIN_Y', 1, 'ACCEPTED')
call check d~audit('S4')['classification']='CONSISTENT_APPLICATION', -
  "different outcomes justified by different problem size is even-handed, NOT disparate"

/* 5. a bar set higher than the decision-maker's own material can reach -> UNMEETABLE_BAR */
e = .StandardApplicationAudit~new
e~standard('S_CORR','THRESHOLD','corroboration_tier', 4)   /* demands PROVENANCE(4) */
e~selfMaterial('S_CORR', 3)                                /* own material only reaches DOCUMENTARY(3) */
call check e~audit('S_CORR')['classification']='UNMEETABLE_BAR', -
  "a corroboration bar above the decision-maker's own reach is special pleading by impossible standard"

/* 6. threshold the decision-maker can actually meet -> CONSISTENT */
f = .StandardApplicationAudit~new
f~standard('S_CORR2','THRESHOLD','corroboration_tier', 3)
f~selfMaterial('S_CORR2', 3)
call check f~audit('S_CORR2')['classification']='CONSISTENT_APPLICATION', -
  "a bar the decision-maker's own material meets is not an unmeetable standard"

/* 7. scope ceiling (Sonnet #4): never a verdict on the underlying question */
call check r['validatedTruth']=.false & r['scope']='STANDARD_APPLICATION_CONSISTENCY_ONLY' -
         & e~audit('S_CORR')['validatedTruth']=.false, -
  "every finding is about even-handedness only; no truth/credibility/outcome verdict is emitted"

say ""
say "STANDARD APPLICATION AUDIT: PASS (" || checks || " checks)"
say "Disparity caught; justified differentiation NOT mislabelled; unmeetable bar flagged;"
say "no verdict on the underlying claim. (Reference operator - ChatGPT's authoritative version to follow.)"
exit 0

check:
  use arg ok, label
  if symbol("checks") = "LIT" then checks = 0
  checks += 1
  if ok == 1 | ok == .true then do; say "PASS" label; return; end
  say "FAIL" label
  exit 1
onSyntax:
  co = condition("O")
  say "SYNTAX rc=" || rc "line" sigl":" condition("D")
  if co \== .nil, co~hasIndex("ADDITIONAL") then do e over co["ADDITIONAL"]; say "  A=" || e; end
  exit 1
::requires "StandardApplicationAudit.cls"
