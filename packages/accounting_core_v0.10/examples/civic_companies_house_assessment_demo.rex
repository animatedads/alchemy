/* Illustrative only: Civic will eventually produce this normalized projection
 * from Companies House filed accounts evidence. Accounting never fetches it. */
p = .directory~new
p["contract_generation"] = "civic.companieshouse.accounts/0.1"
p["mapping_generation"] = "companieshouse.accounts.uk-gaap/0.1"
p["evidence_identity"] = "CIVICAPI-EVIDENCE-V1:DEMO"
p["body_sha512"] = copies("0", 128)
p["company_number"] = "01234567"
p["company_name"] = "EXAMPLE LIMITED"
p["period_end"] = "2025-12-31"
p["statement_kind"] = "ANNUAL_ACCOUNTS"
p["filing_identity"] = "DEMO-FILING-1"
p["facts"] = .array~new
f = .directory~new; f["concept_id"]="uk-gaap:TurnoverRevenue"; f["lexical_value"]="1000000"; f["currency"]="GBP"; p["facts"]~append(f)

s = .AccountingCivicCompaniesHouseImport~fromProjection(p)
a = .AccountingAssessmentBook~new("DEMO-ASSESSOR")
say a~importStatement(s)~status s~sourceEntityName s~periodEnd s~factCount

::options digits 50

::requires "AccountingCivicImport.cls"
