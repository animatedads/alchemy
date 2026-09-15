say "FLYLO LEGAL MODEL START"
gen=.FlyLoLegalRules~build
call yes gen~sealed,"generation sealed"
call yes gen~publicationEligible,"compiler-certified generation"
call no gen~sourceAuthorityAttestationsPresent,"publisher authority attestation deliberately not fabricated"

facts=.LegalFactSet~new
ignored = facts~putKnown("DEPARTS_UK",.true,"test","OPS")
ignored = facts~putKnown("FLIGHT_CANCELLED",.true,"test","OPS")
r=.FlyLoLegalRules~assess(gen,"OFFER_REFUND_OR_REROUTE","F-CANCEL","2026-08-24",facts,.true,.false)
call okresult r,"UK cancel eval"
call eq "CONDITIONAL",r~value~status,"UK cancellation creates obligation"

facts=.LegalFactSet~new
ignored = facts~putKnown("DEPARTS_UK",.true,"test","OPS")
ignored = facts~putKnown("ARRIVAL_DELAY_AT_LEAST_3H",.true,"test","OPS")
r=.FlyLoLegalRules~assess(gen,"ASSESS_FIXED_COMPENSATION","F-DELAY","2026-08-24",facts,.true,.false)
call okresult r,"UK delay eval"
call eq "REVIEW_REQUIRED",r~value~status,"unknown extraordinary circumstances forces review"
ignored = facts~putKnown("EXTRAORDINARY_CIRCUMSTANCES",.false,"ops investigation","OPS")
r=.FlyLoLegalRules~assess(gen,"ASSESS_FIXED_COMPENSATION","F-DELAY","2026-08-24",facts,.true,.false)
call eq "CONDITIONAL",r~value~status,"known no extraordinary circumstance creates compensation obligation"

facts=.LegalFactSet~new
ignored = facts~putKnown("US_COVERED_FLIGHT",.true,"test","OPS")
ignored = facts~putKnown("FLYLO_MERCHANT_OF_RECORD",.true,"test","BOOKING")
ignored = facts~putKnown("CANCELLED_OR_US_SIGNIFICANT_CHANGE",.true,"test","OPS")
ignored = facts~putKnown("PASSENGER_DID_NOT_ACCEPT_ALTERNATIVE",.true,"test","CUSTOMER")
r=.FlyLoLegalRules~assess(gen,"ISSUE_US_REFUND","US-CANCEL","2026-08-24",facts,.false,.true)
call eq "CONDITIONAL",r~value~status,"US refund obligation"

facts=.LegalFactSet~new
ignored = facts~putKnown("FLIGHT_MERELY_RENUMBERED",.true,"test","OPS")
ignored = facts~putKnown("PASSENGER_REBOOKED_ON_RENUMBERED_FLIGHT",.true,"test","OPS")
ignored = facts~putKnown("NO_US_SIGNIFICANT_CHANGE_OR_DELAY",.true,"test","OPS")
r=.FlyLoLegalRules~assess(gen,"ASSESS_US_ENFORCEMENT_POSTURE","US-REN","2026-08-24",facts,.false,.true)
call eq "REVIEW_REQUIRED",r~value~status,"enforcement discretion is a status effect, not entitlement suppression"

say "FLYLO LEGAL MODEL: OK"
exit 0

eq: procedure; use arg e,a,l; if e \== a then do; say "FAIL" l "expected="e "actual="a; exit 41; end; return
yes: procedure; use arg v,l; if \v then do; say "FAIL" l; exit 42; end; return
no: procedure; use arg v,l; if v then do; say "FAIL" l; exit 43; end; return
okresult: procedure; use arg r,l; if \r~ok then do; say "FAIL" l r~code r~detail; exit 44; end; return
::requires "FlyLoLegalRules.cls"
