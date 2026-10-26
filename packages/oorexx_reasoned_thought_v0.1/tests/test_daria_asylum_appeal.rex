/* test_daria_asylum_appeal.rex
 * STRUCTURAL map of a real first-instance asylum decision (IP/413777/03-07-2026) and the grounds
 * raised on appeal. Models the SHAPE of the reasoning - which findings rest on documentary grounds
 * and which on credibility assessments - and keeps appeal grounds as PENDING, not established.
 *
 * PROVENANCE: drafted by Gemini (2026-10-26); cleaned up and corrected for faithfulness and
 * neutrality by Claude (Opus 4.8); engine / architecture Tom Dyer. Pure ooRexx 5.3.
 *
 * WHAT THIS IS NOT: it asserts NO facts about the applicant, establishes NO evidence, and does NOT
 * predict the appeal. A credibility finding typed here is an ASSESSMENT, never proof that an account
 * is false. Whether any appeal ground succeeds is for the Appeals Authority, not this model.
 *
 * Corrections to the draft: the draft treated unadjudicated appeal assertions (toxicology report,
 * COI on passport lag, named adversaries) as established 'measure' refutations and overturned every
 * finding; it also mischaracterised two grounds. Per the decision as read: (a) it did NOT find "the
 * lab showed only cosmetics" - the lab reportedly found organophosphates/pesticides, and the
 * poisoning account was handled within the overall internal-incoherence finding; (b) "Lea Family"
 * was rejected because no such organisation was found AND the account lacked internal coherence - the
 * LEA (Law Enforcement Agencies) acronym was an aside, not the stated ground. This version represents
 * the findings as recorded and the appeal grounds as PROPOSED and PENDING.
 */
signal on syntax name onSyntax

m = .FactsMatrix~new

/* ---- first-instance findings ACCEPTED on documentary grounds (stand independent of the appeal) ---- */
m~fact("K_identity_doc", "applicant produced a valid Russian passport; COI corroborates identity, origin, religion, route", 0, "DOC")
id = .directory~new; id["K_identity_doc"] = "DOC"
m~confirm("A_identity", "documentary: passport + country-of-origin information", id, 0)
m~decision("D_accept_identity", "first-instance ACCEPTED identity / nationality / route")
m~needs("D_accept_identity", "K_identity_doc")

m~fact("K_child_doc", "Greek birth certificate records the child as Russian (father unknown); no proof of UK paternity was submitted", 0, "DOC")
ch = .directory~new; ch["K_child_doc"] = "DOC"
m~confirm("A_child", "documentary: birth certificate + Russian nationality law", ch, 0)
m~decision("D_accept_child_russian", "first-instance ACCEPTED the child's Russian nationality via the mother")
m~needs("D_accept_child_russian", "K_child_doc")

/* ---- the DECISIVE rejections rest on CREDIBILITY (internal-consistency) assessments, NOT on any
        documentary refutation. Typed as TESTIMONY-tier assumptions, deliberately NOT confirmed. ---- */
m~fact("K_internal_incoherence", "the GRU / Lea-Family targeting account was found vague, lacking logical coherence and self-contradictory", 0, "CREDIBILITY")
m~decision("D_reject_targeting", "first-instance REJECTED the GRU / Lea-Family targeting")
m~needs("D_reject_targeting", "K_internal_incoherence")

m~fact("K_release_undercuts_fear", "her own account - released by the FSB at the airport, renewed her passport, left legally - was treated as inconsistent with being a target", 0, "CREDIBILITY")
m~decision("D_reject_future_risk", "first-instance found the forward-looking fear of persecution unfounded")
m~needs("D_reject_future_risk", "K_release_undercuts_fear")

/* ---- appeal grounds: PROPOSED defeaters, currently UNADJUDICATED. Entered as assertions, NOT as
        established evidence, and they refute NOTHING here - admissibility is for the Authority. ---- */
m~fact("K_appeal_named_actors",  "APPEAL ASSERTS: named individuals / private threat actors, not an acronym confusion", 0, "APPEAL")
m~fact("K_appeal_toxicology",    "APPEAL ASSERTS: supplemental toxicological opinion on organophosphate markers", 0, "APPEAL")
m~fact("K_appeal_coi_passport",  "APPEAL ASSERTS: COI that municipal passport offices do not sync with active intelligence inquiries", 0, "APPEAL")
m~fact("K_appeal_paternity",     "APPEAL ASSERTS: a pending judicial paternity action + best-interests-of-the-child (Art. 5)", 0, "APPEAL")

rev = m~review

say "== 1. Findings accepted on DOCUMENTARY grounds - they stand regardless of the appeal"
call check inList(rev["checkedFacts"], "K_identity_doc") & inList(rev["checkedFacts"], "K_child_doc") -
         & \ fellIn(rev, "D_accept_identity") & \ fellIn(rev, "D_accept_child_russian"), -
  "identity and the child's Russian nationality rest on documents; the appeal does not disturb them"

say ""
say "== 2. The DECISIVE rejections rest on CREDIBILITY, not documentary refutation"
call check \ inList(rev["checkedFacts"], "K_internal_incoherence") & \ inList(rev["checkedFacts"], "K_release_undercuts_fear") -
         & \ fellIn(rev, "D_reject_targeting") & \ fellIn(rev, "D_reject_future_risk"), -
  "the targeting and future-risk rejections stand on the record but on TESTIMONY-tier assessments - inherently contestable, NOT proof the account is false"

say ""
say "== 3. Appeal grounds are PROPOSED and PENDING - assertion is not establishment"
call check \ inList(rev["checkedFacts"], "K_appeal_toxicology") & \ inList(rev["checkedFacts"], "K_appeal_coi_passport") -
         & \ fellIn(rev, "D_reject_targeting") & \ fellIn(rev, "D_reject_future_risk"), -
  "the appeal grounds overturn NOTHING in this model; whether they are admitted and verified is for the Appeals Authority, not FactsMatrix"

say ""
say "== What the model does - and does not - say"
say "   It isolates the load-bearing step (a credibility assessment: the airport-release contradiction"
say "   and the universal 'Russia persecutes critics' not bridging to the individual claim) and shows"
say "   it is NOT a documentary refutation. It records the appeal's grounds as pending. It does not"
say "   decide the appeal, and 'rejected on credibility' is not 'false'."

say ""
say "DARIA ASYLUM APPEAL STRUCTURAL MAP: PASS (" || checks || " checks)"
exit 0

fellIn: procedure
  use arg rev, id
  do d over rev["fallenDecisions"]; if d["id"] = id then return .true; end
  return .false

inList: procedure
  use arg arr, id
  do d over arr; if d["id"] = id then return .true; end
  return .false

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

::requires "FactsMatrix.cls"
