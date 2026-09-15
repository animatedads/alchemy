say "FLYLO TRAVEL INFORMATION START"
a = .FlyLoTravelInformationAuthority~new
entry = a~usEntryEvidence("COL")
call eq "COL", entry["documentCountry"], "Colombia evidence selected"
call no entry["visaWaiverProgram"], "Colombia not represented as VWP"
call yes entry["governmentAdmissionAuthority"], "government admission authority explicit"
call yes entry["airlineDocumentCheckOnly"], "airline boundary explicit"

t = a~usTobaccoEvidence(.true, 0, .true)
call eq 21, t["adultMinimumAge"], "adult tobacco age"
call eq 200, t["publishedCigaretteQuantity"], "published cigarette quantity"
call yes t["checkedBaggageDoesNotChangeCustomsAllowance"], "bag location does not change customs"
call yes t["dutyFreeShopDoesNotOverrideImportRules"], "duty free is not customs free"
call yes t["ageClarificationNeeded"], "child age clarification required"

b = a~cigaretteBaggageEvidence
call yes b["ordinaryCigarettesCheckedBaggagePermitted"], "ordinary cigarettes permitted in checked baggage"
call yes b["customsRulesRemainSeparate"], "customs separate from security baggage rule"

p = a~checkedBagProductEvidence
call eq "CHECKED_BAG", p["product"], "checked bag product"
call yes p["transactionRequired"], "adding bag is a transaction"
call no p["quietTransactionPermitted"], "assistant cannot quietly add bag"
say "FLYLO TRAVEL INFORMATION: OK"
exit 0

yes: procedure; use arg v,l; if \v then do; say "FAIL" l; exit 61; end; return
no: procedure; use arg v,l; if v then do; say "FAIL" l; exit 62; end; return
eq: procedure; use arg e,a,l; if e \== a then do; say "FAIL" l "expected="e "actual="a; exit 63; end; return

::requires "FlyLoTravelInformation.cls"
