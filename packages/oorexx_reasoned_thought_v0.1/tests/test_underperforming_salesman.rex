/* Reasoned Thought qualification 14: "The Underperforming Salesman".
 * A fourth, everyday domain (HR / employment) for the SAME engine - no new
 * classes. A synthetic red-team scenario in which sparse, mostly-neutral facts
 * plus a slanted brief tempt a naive reasoner (cf. a real Gemini transcript)
 * into collusion, gross-misconduct and intent findings. The FactsMatrix refuses
 * every leap, and - the point of the exercise - is NOT partisan:
 *
 *   - off-point smears against the employee are ineligible;
 *   - the employer's OWN admitted conduct (refusing statutory paternity leave)
 *     is an on-point CHECKED fact that topples the "clean dismissal" plan and
 *     cannot be laundered by fixing the file after the event;
 *   - the most PARSIMONIOUS explanation (a newborn, hence exhaustion) is the
 *     surviving explanatory decision - yet stays LEADING-BUT-UNCONFIRMED: it is
 *     never a checked fact until he is actually asked. Occam selects the
 *     hypothesis to test; it does not confirm it.
 *
 * Synthetic. No real person. Legal characterisations are illustrative, not advice.
 * Architecture: Tom Dyer. Engine & test: Claude (Opus 4.8). Pure ooRexx 5.3.
 * Scopes: PERFORMANCE, PERSONAL, CONTRACT, INFORMAL, CONDUCT, INTENT, RIGHTS.
 */
signal on syntax name onSyntax
m = .FactsMatrix~new

/* ---- the genuine, checkable facts: all NEUTRAL, PERFORMANCE, or the admission ---- */
call confirmFact m, "F_REVENUE_DROP",    "recorded revenue fell from last year's 3.2m",      "PERFORMANCE"
call confirmFact m, "F_MARRIED",         "married last autumn",                              "PERSONAL"
call confirmFact m, "F_WIFE_COMPETITOR", "spouse is an HR executive at a competitor",        "PERSONAL"
call confirmFact m, "F_MGR_DRAFTED",     "a prior manager drafted a generous contract",      "CONTRACT"
call confirmFact m, "F_MGR_LEFT",        "that manager has since moved to the competitor",   "PERSONAL"
call confirmFact m, "F_NEWBORN",         "has a newborn child",                              "PERSONAL"
call confirmFact m, "F_LEAVE_REFUSED",   "employer refused the paternity request, required annual leave", "RIGHTS"

/* ---- the asserted leaps: entered only as assumptions (TESTIMONY) ---- */
m~fact("F_FLEXI_DOCUMENTED",  "a DOCUMENTED contractual 2-day flexi variation exists", 0, "CONTRACT")
m~fact("F_INFORMAL_FLEXI",    "an informal verbal flexi understanding may have existed",0, "INFORMAL")
m~fact("F_COORDINATION",      "James coordinated a collusive exit with the ex-manager", 0, "CONDUCT")
m~fact("F_ATTITUDE_MISCONDUCT","customer conduct rises to GROSS MISCONDUCT",            0, "CONDUCT")
m~fact("F_INTENT_DECEIVE",    "James is acting dishonestly",                            0, "INTENT")
m~fact("F_INTENT_ENGINEER",   "James is engineering his own misconduct exit",           0, "INTENT")

/* ---- the parsimonious explanation: on-point, unrefuted, but UNCONFIRMED ---- */
m~fact("F_EXHAUSTION", "newborn-related exhaustion explains the dip and the flexi request", 0, "PERFORMANCE")

/* ---- premises the employer's preferred decisions would need ---- */
m~fact("F_NO_DETRIMENT",     "no detriment was imposed for exercising a statutory right",   0, "RIGHTS")
m~fact("F_DETRIMENT_ERASED", "a past detriment can be retroactively un-made by fixing the file", 0, "RIGHTS")

/* ---- the on-point record searches a disciplined process actually runs ---- */
call rebut m, "M_NO_VARIATION","HR/board contract file: NO documented variation recorded","F_FLEXI_DOCUMENTED","CONTRACT"
call rebut m, "M_NO_COORD",    "scoped review of available records: no evidence of coordination","F_COORDINATION","CONDUCT"
call rebut m, "M_ADMIT",       "the admitted refusal IS a detriment tied to a statutory-right request","F_NO_DETRIMENT","RIGHTS"
call rebut m, "M_PAST",        "remedying the leave is right, but the past instruction stays on the record","F_DETRIMENT_ERASED","RIGHTS"
/* the Gemini move made explicit: marriage as misconduct is OFF-POINT => ineligible */
call rebut m, "M_SMEAR",       "treat the marriage as if it evidenced misconduct","F_MARRIED","MISCONDUCT"

/* ---- decisions: the leaps, the employer's exit plan, and the sound ones ---- */
m~decision("D_FLEXI_RIGHT",        "treat the 2-day flexi right as contractually established")
m~needs("D_FLEXI_RIGHT","F_FLEXI_DOCUMENTED")
m~decision("D_SACK_FOR_COLLUSION", "dismiss for a collusive side-agreement")
m~needs("D_SACK_FOR_COLLUSION","F_COORDINATION")
m~decision("D_GROSS_MISCONDUCT",   "dismiss for gross misconduct (conduct + collusion)")
m~needs("D_GROSS_MISCONDUCT","F_ATTITUDE_MISCONDUCT"); m~needs("D_GROSS_MISCONDUCT","F_COORDINATION")
m~decision("D_DISMISS_LOW_RISK",   "treat dismissal now as a clean, low-risk matter")
m~needs("D_DISMISS_LOW_RISK","F_NO_DETRIMENT")
m~decision("D_LAUNDER",            "assume correcting the record neutralises the retaliation claim")
m~needs("D_LAUNDER","F_DETRIMENT_ERASED")
m~decision("D_HE_LIED",            "conclude he lied"); m~needs("D_HE_LIED","F_INTENT_DECEIVE")
m~decision("D_ENGINEERED_EXIT",    "conclude he is engineering his own exit"); m~needs("D_ENGINEERED_EXIT","F_INTENT_ENGINEER")
m~decision("D_SUPPORT_NOT_DISCIPLINE","treat the dip as fatigue/capability, pending a conversation")
m~needs("D_SUPPORT_NOT_DISCIPLINE","F_EXHAUSTION")
m~decision("D_FAIR_REVIEW",        "open an evidence-led performance review and put fair questions")
m~needs("D_FAIR_REVIEW","F_REVENUE_DROP")

rev = m~review
say "THE UNDERPERFORMING SALESMAN / REASONED THOUGHT, EVERYDAY DOMAIN"
say "fallen decisions:"
do d over rev["fallenDecisions"]; say "   - " d["id"]; end
say ""

/* 1. every CHECKED fact is neutral, performance, the newborn, or the admission */
call check inList(rev["checkedFacts"],"F_REVENUE_DROP") & inList(rev["checkedFacts"],"F_MARRIED") -
   & inList(rev["checkedFacts"],"F_WIFE_COMPETITOR") & inList(rev["checkedFacts"],"F_MGR_DRAFTED") -
   & inList(rev["checkedFacts"],"F_MGR_LEFT") & inList(rev["checkedFacts"],"F_NEWBORN"), -
  "the only CHECKED facts are neutral/performance - none is on-point to misconduct or collusion"

/* 2. the leaps rest on claims an on-point search refutes as established */
call check inList(rev["refutedFacts"],"F_FLEXI_DOCUMENTED") & inList(rev["refutedFacts"],"F_COORDINATION"), -
  "documented-variation and coordination claims are not established on the records searched"
call check fellIn(rev,"D_FLEXI_RIGHT") & fellIn(rev,"D_SACK_FOR_COLLUSION") & fellIn(rev,"D_GROSS_MISCONDUCT"), -
  "contractual-flexi, collusion-dismissal and gross-misconduct decisions all fall"

/* 3. NOT partisan: the employer's own admitted conduct is enforced against the operator */
call check inList(rev["checkedFacts"],"F_LEAVE_REFUSED"), -
  "the employer's admitted paternity refusal is an on-point CHECKED fact"
call check inList(rev["refutedFacts"],"F_NO_DETRIMENT") & fellIn(rev,"D_DISMISS_LOW_RISK"), -
  "the 'clean, low-risk dismissal' plan falls on the employer's own conduct"
call check fellIn(rev,"D_LAUNDER"), -
  "papering the record does not erase a past checked fact - the exposure is not laundered away"

/* 4. scope gate: an off-point smear stays ineligible, same engine, same turn */
call check inList(rev["checkedFacts"],"F_MARRIED") & \ inList(rev["refutedFacts"],"F_MARRIED"), -
  "off-point 'marriage=misconduct' measure is ineligible; marriage stays a neutral checked fact"

/* 5. absence is not disproof */
call check \ inList(rev["refutedFacts"],"F_INFORMAL_FLEXI") & \ inList(rev["checkedFacts"],"F_INFORMAL_FLEXI"), -
  "'no contract variation' leaves an informal understanding UNDETERMINED, not disproven"

/* 6. intent: neither established nor refuted, and symmetric */
call check \ inList(rev["checkedFacts"],"F_INTENT_DECEIVE") & \ inList(rev["checkedFacts"],"F_INTENT_ENGINEER"), -
  "neither 'he lied' nor 'he is engineering an exit' is established - intent is not read from records"
call check \ inList(rev["checkedFacts"],"F_ATTITUDE_MISCONDUCT"), -
  "the 'unprofessional attitude' allegation is unexamined, never a checked fact"

/* 7. parsimony: the newborn-exhaustion explanation is the surviving explanatory
      decision - yet LEADING-BUT-UNCONFIRMED: never a checked fact until he is asked */
call check \ fellIn(rev,"D_SUPPORT_NOT_DISCIPLINE") & \ fellIn(rev,"D_FAIR_REVIEW"), -
  "the fatigue/capability reading and a fair review survive; the exit routes do not"
call check \ inList(rev["checkedFacts"],"F_EXHAUSTION") & \ inList(rev["refutedFacts"],"F_EXHAUSTION"), -
  "Occam selects the exhaustion hypothesis to TEST; it stays unconfirmed until he is actually asked"

say ""
say "UNDERPERFORMING SALESMAN: PASS (" || checks || " checks)"
say "Leaps fall; off-point smears refused; the operator's own admission enforced;"
say "the parsimonious explanation leads but is not assumed. The discipline is not partisan."
exit 0

confirmFact: procedure
  use arg mx, id, stmt, scope
  mx~fact(id, stmt, 0, scope)
  d = .directory~new; d[id] = scope
  mx~confirm("C_" || id, "on-point confirmation", d, 1)
  return
rebut: procedure
  use arg mx, mid, stmt, factId, scope
  d = .directory~new; d[factId] = scope
  mx~measure(mid, stmt, d, 2)
  return
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
