source = .directory~new
source["kind"] = "CONTRACT"
source["documentId"] = "demo-sale-terms"
text = "Customer shall not assign this Agreement without Supplier's prior written consent, except to an Affiliate."

session = .LegalInterrogationSession~new("DEMO", "demo-sale-terms:v1", source, "CONTRACT")
clause = .LegalInterrogationClause~new("12", source, "clause 12", text)
session~addClause(clause)
director = .LegalInterrogationDirector~new
director~seedClauseQuestions(clause)
provider = .LegalInterrogationIntentionProvider~new

say "SOURCE:" clause~exactText
say
say "The intention service currently discovers:"
do i over provider~discover(session)
  say " -" i~name ":" i~reason
end
say
say "First interrogatory:" clause~questions[1]~text

::requires "LegalInterrogation.cls"
