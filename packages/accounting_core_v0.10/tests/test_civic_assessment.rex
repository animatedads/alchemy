t = .AccountingTest~new

/* This shape is intentionally a future Civic normalized accounts projection,
 * not raw Companies House iXBRL/PDF/HTTP. */
p = .directory~new
p["contract_generation"] = "civic.companieshouse.accounts/0.1"
p["mapping_generation"] = "companieshouse.accounts.uk-gaap/0.1"
p["evidence_identity"] = "CIVICAPI-EVIDENCE-V1:CH-ACCOUNTS:abc"
p["body_sha512"] = copies("a", 128)
p["source_url"] = "https://example.invalid/company/01234567/accounts/document/ABC"
p["company_number"] = "01234567"
p["company_name"] = "EXAMPLE AIRLINE LIMITED"
p["period_start"] = "2025-01-01"
p["period_end"] = "2025-12-31"
p["statement_kind"] = "ANNUAL_ACCOUNTS"
p["reporting_basis"] = "UK_GAAP"
p["units_description"] = "GBP"
p["retrieved_at"] = "2026-08-28T14:51:00+01:00"
p["filing_identity"] = "CH-FILING-2026-04-30-ABC"
p["access_state"] = "HEALTHY"
p["cache_state"] = "FRESH"
p["body_record_id"] = "BODY-1"
p["observation_record_id"] = "OBS-1"

facts = .array~new
f1 = .directory~new
f1["concept_id"] = "uk-gaap:TurnoverRevenue"
f1["label"] = "Turnover"
f1["lexical_value"] = "125000000"
f1["value_type"] = "DECIMAL"
f1["currency"] = "GBP"
f1["unit"] = "GBP"
f1["period_start"] = "2025-01-01"
f1["period_end"] = "2025-12-31"
f1["source_pointer"] = "ix:nonFraction#fact-42"
facts~append(f1)

f2 = .directory~new
f2["concept_id"] = "uk-gaap:NetAssetsLiabilities"
f2["label"] = "Net assets"
f2["lexical_value"] = "34000000"
f2["value_type"] = "DECIMAL"
f2["currency"] = "GBP"
f2["unit"] = "GBP"
f2["instant_date"] = "2025-12-31"
f2["source_pointer"] = "ix:nonFraction#fact-77"
d = .directory~new
d["consolidationScope"] = "COMPANY"
f2["dimensions"] = d
facts~append(f2)
p["facts"] = facts

statement = .AccountingCivicCompaniesHouseImport~fromProjection(p)
t~assertEq("CIVIC", statement~sourceSystem, "source system retained")
t~assertEq("01234567", statement~sourceEntityId, "company number retained")
t~assertEq(2, statement~factCount, "facts imported")
t~assertEq("CIVICAPI-EVIDENCE-V1:CH-ACCOUNTS:abc", statement~evidenceIdentity, "Civic evidence retained")
t~assertEq("ix:nonFraction#fact-42", statement~facts[1]~sourcePointer, "source fact pointer retained")

assessment = .AccountingAssessmentBook~new("ANALYST:DEMO")
r = assessment~importStatement(statement)
t~assertEq("IMPORTED", r~status, "statement imports into assessment book")
t~assertEq(1, assessment~statementCount, "one assessment statement")
t~assertEq("DUPLICATE", assessment~importStatement(statement)~status, "assessment import idempotent")

/* Loading an external filing never posts a company journal. */
companyBook = .AccountingBook~new("EXAMPLE_AIRLINE_LIMITED", "EXAMPLE-GL")
t~assertEq(0, companyBook~entryCount, "external assessment does not mutate GL")


engine = .AccountingEngine~new("EXAMPLE_AIRLINE_LIMITED", "EXAMPLE-GL")
er = engine~importCivicCompaniesHouseProjection(p)
t~assertEq("IMPORTED", er~status, "AccountingEngine facade imports Civic evidence for assessment")
t~assertEq(1, engine~assessments~statementCount, "engine assessment store receives filing")
t~assertEq(0, engine~book~entryCount, "engine native book remains untouched by Civic import")

/* Same filing identity/mapping with changed evidence fails closed. */
p2 = p~copy
p2["body_sha512"] = copies("b", 128)
conflicting = .AccountingCivicCompaniesHouseImport~fromProjection(p2)
conflict = assessment~importStatement(conflicting)
t~assertEq("EXTERNAL_IDENTITY_CONFLICT", conflict~errorCode, "changed external evidence conflicts")

say "civic assessment assertions=" t~assertions "failures=" t~failures
if t~failures > 0 then exit 1
exit 0

::options digits 50

::requires "AccountingEngine.cls"
::requires "TestSupport.cls"
