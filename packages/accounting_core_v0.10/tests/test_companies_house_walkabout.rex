t = .AccountingTest~new
fixture = "fixtures/companies_house/16024067_aa_2026-07-17.projection.json"
s = .stream~new(fixture)
ignore = s~open("read")
text = s~charin(1, s~chars)
ignore = s~close
p = .json~fromJSON(text)

statement = .AccountingCivicCompaniesHouseImport~fromProjection(p)
t~assertEq("16024067", statement~sourceEntityId, "real filing company number")
t~assertEq("WALKABOUT LTD", statement~sourceEntityName, "real filing company name")
t~assertEq("2024-10-17", statement~periodStart, "real filing period start")
t~assertEq("2025-10-31", statement~periodEnd, "real filing period end")
t~assertEq(89, statement~factCount, "all iXBRL facts retained")
t~assertEq(1, statement~taxonomyRefs~items, "taxonomy reference retained")
t~assertTrue(statement~completeness~hasIndex("income_statement_delivered"), "income statement completeness flag retained")

cash = statement~factsByLocalConcept("CashBankOnHand")
t~assertEq(1, cash~items, "cash fact found by canonical local concept")
t~assertEq("421,521", cash[1]~lexicalValue, "cash source lexical retained")
t~assertEq("421521", cash[1]~normalizedValue, "cash exact normalized decimal retained")
t~assertEq("ns5:CashBankOnHand", cash[1]~sourceConcept, "source qname retained")
t~assertEq("cfwd_31_10_2025", cash[1]~provenance["source_context_ref"], "source context retained")

creditors = statement~factsByLocalConcept("Creditors")
t~assertEq(2, creditors~items, "duplicate visible/hidden creditors retained")
primaryCreditors = 0
duplicateCreditors = 0
do fact over creditors
  if fact~isDuplicate then duplicateCreditors += 1
  else primaryCreditors += 1
end
t~assertEq(1, primaryCreditors, "one primary creditors fact")
t~assertEq(1, duplicateCreditors, "one duplicate creditors fact")

engine = .AccountingEngine~new("ASSESSMENT-DEMO", "NATIVE-GL")
r = engine~importCivicCompaniesHouseProjection(p)
t~assertEq("IMPORTED", r~status, "real filing imports into assessment store")
t~assertEq(0, engine~book~entryCount, "real filing does not post to native GL")

/* Conflict detection includes nested completeness arrays, not just scalar
 * top-level evidence fields. */
pConflict = .json~fromJSON(text)
pConflict["completeness"]["accounts_status_members"] = .array~of("CHANGED-FOR-CONFLICT-PROBE")
conflict = engine~importCivicCompaniesHouseProjection(pConflict)
t~assertTrue(\conflict~ok, "nested completeness change conflicts with existing external identity")
t~assertEq("EXTERNAL_IDENTITY_CONFLICT", conflict~errorCode, "nested evidence conflict code")

/* Verify JSONBoolean TRUE is not misread as false by policy logic. */
pDelivered = .json~fromJSON(text)
pDelivered["completeness"]["income_statement_delivered"] = .json~true
deliveredStatement = .AccountingCivicCompaniesHouseImport~fromProjection(pDelivered)
deliveredReport = .AccountingCompaniesHouseAssessment~assess(deliveredStatement)
t~assertTrue(deliveredReport~finding("INCOME_STATEMENT_NOT_DELIVERED") == .nil, "JSONBoolean true completeness is honoured")

report = .AccountingCompaniesHouseAssessment~assess(r~statement)
t~assertEq("PASS", report~finding("CURRENT_ASSET_ARITHMETIC")~status, "current asset arithmetic")
t~assertEq("PASS", report~finding("TOTAL_ASSET_ARITHMETIC")~status, "total asset arithmetic")
t~assertEq("PASS", report~finding("CREDITOR_DETAIL_ARITHMETIC")~status, "creditor detail arithmetic")
t~assertEq("PASS", report~finding("EQUITY_ARITHMETIC")~status, "equity arithmetic")
t~assertEq("INFO", report~finding("INCOME_STATEMENT_NOT_DELIVERED")~status, "filing completeness warning is informational")
t~assertEq("INFO", report~finding("DIRECTOR_ADVANCE_BALANCE_REPORTED")~status, "director advance surfaced without judgment")
t~assertEq("96320", report~finding("DIRECTOR_ADVANCE_BALANCE_REPORTED")~actual, "director advance exact value")
t~assertEq("INFO", report~finding("PROFIT_DISCLOSED_OUTSIDE_UNDELIVERED_INCOME_STATEMENT")~status, "profit in notes surfaced")
t~assertEq("580379", report~finding("PROFIT_DISCLOSED_OUTSIDE_UNDELIVERED_INCOME_STATEMENT")~actual, "profit exact value")
t~assertEq("PASS", report~finding("REPORTING_FRAMEWORK_DISCLOSURE")~status, "reporting framework disclosure found")
t~assertEq(0, report~countStatus("FAIL"), "no arithmetic consistency failures")

say "walkabout filing assertions=" t~assertions "failures=" t~failures
if t~failures > 0 then exit 1
exit 0

::options digits 50

::requires "AccountingEngine.cls"
::requires "AccountingCompaniesHouseAssessment.cls"
::requires "TestSupport.cls"
::requires "json.cls"
