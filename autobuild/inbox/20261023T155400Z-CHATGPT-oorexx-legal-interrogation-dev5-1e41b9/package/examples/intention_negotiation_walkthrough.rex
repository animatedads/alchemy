/* Minimal ANSWER -> REVIEW -> REVISE -> ANSWER walkthrough. */
source = .directory~new
source["kind"] = "CONTRACT_FIXTURE"
source["name"] = "demo"
session = .LegalInterrogationSession~new("DEMO", "fixture:demo", source, "CONTRACT")
port = .LegalInterrogationIntentionPort~new

surface = port~discover(session)~value
say "NEXT:" surface~intentions[1]~name
clause = .LegalInterrogationClause~new("C1", source, "clause 1", "Customer shall not assign this Agreement without Supplier consent, except to an Affiliate.")
port~execute(session, surface~intentions[1], clause, "SOURCE_INGESTOR")

surface = port~discover(session)~value
say "NEXT:" surface~intentions[1]~name
port~execute(session, surface~intentions[1], .LegalInterrogationAnswer~new("Assignment is prohibited.", "first proposal", "ANSWERED", .array~new, "LLM_PROPOSER"), "LLM_PROPOSER")

surface = port~discover(session)~value
say "NEXT:" surface~intentions[1]~name
port~execute(session, surface~intentions[1], .LegalInterrogationAnswerReview~new("REVISE", "Affiliate exception omitted", "LEGAL_REVIEWER"), "LEGAL_REVIEWER")

surface = port~discover(session)~value
say "NEXT:" surface~intentions[1]~name
say "HISTORY:" session~negotiationHistory~items
say "CLAUSE STATE:" clause~closureState

::requires "LegalInterrogationIntentionPort.cls"
