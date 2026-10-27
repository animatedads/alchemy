/* Adversarial falsifier for StandardApplicationAudit (Claude, Opus 4.8), targeting
 * the ONE property ChatGPT proposed (REQ-00000255, NEPO-3) but did not test in its
 * own contract: the auditor must itself be invariant to party LABELS and insertion
 * ORDER. A disparate-treatment auditor that depends on which chain is named first,
 * or on which label sits on the rejected row, has its own thumb on the scale.
 *
 * Each check compares two structurally identical bundles that differ only by order
 * or by a label permutation; the classification must be identical. A degenerate
 * "compare applications[1] vs applications[2] in insertion order" operator fails F1/F5.
 *
 * Architecture: Tom Dyer. Operator under test: ChatGPT GPT-6 (v0.2). This fixture: Claude (Opus 4.8).
 */
signal on syntax name onSyntax

/* F1: ORDER INVARIANCE on a disparate case - rejected added first vs accepted first */
m1 = .StandardApplicationAudit~new
m1~standard('S','DISQUALIFY','problem')
m1~applied('S','A',2,'REJECTED'); m1~applied('S','B',2,'ACCEPTED')
m2 = .StandardApplicationAudit~new
m2~standard('S','DISQUALIFY','problem')
m2~applied('S','B',2,'ACCEPTED'); m2~applied('S','A',2,'REJECTED')
call check m1~audit('S')['classification'] = m2~audit('S')['classification'] -
       & m1~audit('S')['classification'] = 'DISPARATE_TREATMENT', -
  "order invariance: disparity found regardless of which row was entered first"

/* F2: ORDER INVARIANCE on a consistent case */
c1 = .StandardApplicationAudit~new
c1~standard('S','DISQUALIFY','problem')
c1~applied('S','A',2,'REJECTED'); c1~applied('S','B',2,'REJECTED')
c2 = .StandardApplicationAudit~new
c2~standard('S','DISQUALIFY','problem')
c2~applied('S','B',2,'REJECTED'); c2~applied('S','A',2,'REJECTED')
call check c1~audit('S')['classification'] = c2~audit('S')['classification'] -
       & c1~audit('S')['classification'] = 'CONSISTENT_APPLICATION', -
  "order invariance: consistency unaffected by insertion order"

/* F3: LABEL-SWAP INVARIANCE (NEPO-3): own-system vs competitor must not change the
       verdict when the labels are exchanged on the same value/disposition rows */
own = .StandardApplicationAudit~new
own~standard('S','DISQUALIFY','problem')
own~applied('S','OWN_SYSTEM',2,'REJECTED'); own~applied('S','COMPETITOR',2,'ACCEPTED')
swp = .StandardApplicationAudit~new
swp~standard('S','DISQUALIFY','problem')
swp~applied('S','COMPETITOR',2,'REJECTED'); swp~applied('S','OWN_SYSTEM',2,'ACCEPTED')
call check own~audit('S')['classification'] = swp~audit('S')['classification'] -
       & own~audit('S')['classification'] = 'DISPARATE_TREATMENT', -
  "label-swap invariance: disparity is in the structure, not in which party is named"

/* F4: LABEL-SWAP INVARIANCE on a JUSTIFIED (consistent) difference - the 'worse
       problem rejected' logic must be label-independent */
j1 = .StandardApplicationAudit~new
j1~standard('S','DISQUALIFY','problem')
j1~applied('S','P',3,'REJECTED'); j1~applied('S','Q',1,'ACCEPTED')
j2 = .StandardApplicationAudit~new
j2~standard('S','DISQUALIFY','problem')
j2~applied('S','Q',3,'REJECTED'); j2~applied('S','P',1,'ACCEPTED')
call check j1~audit('S')['classification'] = j2~audit('S')['classification'] -
       & j1~audit('S')['classification'] = 'CONSISTENT_APPLICATION', -
  "label-swap invariance: justified differentiation stays consistent under relabelling"

/* F5: MULTI-CHAIN non-adjacent disparate pair, under two insertion orders - the
       violating pair (A rej2 vs C acc3) is not the adjacent pair */
p1 = .StandardApplicationAudit~new
p1~standard('S','DISQUALIFY','problem')
p1~applied('S','A',2,'REJECTED'); p1~applied('S','B',5,'REJECTED'); p1~applied('S','C',3,'ACCEPTED')
p2 = .StandardApplicationAudit~new
p2~standard('S','DISQUALIFY','problem')
p2~applied('S','C',3,'ACCEPTED'); p2~applied('S','B',5,'REJECTED'); p2~applied('S','A',2,'REJECTED')
call check p1~audit('S')['classification'] = p2~audit('S')['classification'] -
       & p1~audit('S')['classification'] = 'DISPARATE_TREATMENT', -
  "multi-chain: a non-adjacent violating pair is found under either insertion order"

say ""
say "STANDARD APPLICATION FAIRNESS (identity/order invariance): PASS (" || checks || " checks)"
say "The auditor itself is label- and order-invariant - no thumb on its own scale."
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
