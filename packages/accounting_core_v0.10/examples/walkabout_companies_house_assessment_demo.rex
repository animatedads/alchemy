/* Real-file qualification example.
 * The JSON projection is reference-generated from the supplied Companies House
 * iXBRL filing. Production retrieval/parsing belongs in Civic. */
fixture = "fixtures/companies_house/16024067_aa_2026-07-17.projection.json"
s = .stream~new(fixture)
ignore = s~open("read")
projection = .json~fromJSON(s~charin(1, s~chars))
ignore = s~close

engine = .AccountingEngine~new("ASSESSOR-DEMO", "NATIVE-GL")
import = engine~importCivicCompaniesHouseProjection(projection)
if \import~ok then do
  say "IMPORT FAILED" import~errorCode import~message
  exit 1
end

statement = import~statement
say "company:" statement~sourceEntityName "("statement~sourceEntityId")"
say "period:" statement~periodStart "to" statement~periodEnd
say "facts:" statement~factCount
say "native GL entries after import:" engine~book~entryCount
say

report = .AccountingCompaniesHouseAssessment~assess(statement)
do finding over report~findings
  say finding~status finding~code "-" finding~message
  if finding~actual \= "" then say "  actual:" finding~actual
end

::options digits 50

::requires "AccountingEngine.cls"
::requires "AccountingCompaniesHouseAssessment.cls"
::requires "json.cls"
