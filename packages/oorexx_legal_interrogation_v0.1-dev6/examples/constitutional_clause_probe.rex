/* Demonstrates interrogation of a difficult source without pretending to settle it. */

source = .directory~new
source["kind"] = "CONSTITUTION_FIXTURE"
source["documentId"] = "us-constitution-amendment-ii"
text = "A well regulated Militia, being necessary to the security of a free State, the right of the people to keep and bear Arms, shall not be infringed."

session = .LegalInterrogationSession~new("A2-PROBE", "fixture:us-constitution:a2", source, "CONSTITUTION")
clause = .LegalInterrogationClause~new("A2", source, "Amendment II", text)
session~addClause(clause)
director = .LegalInterrogationDirector~new
director~seedClauseQuestions(clause)

/* The proposer may offer this interpretation, but proposal is not authority. */
pResult = director~newProposition(clause, -
  "The prefatory militia proposition conditions the operative right on militia participation.", -
  "INTERPRETIVE", "prefatory militia proposition", "CONDITIONS", "operative right", "")
p = pResult~value
director~challengeProposition(clause, p)

/* Record the disputed semantic relation as requiring review rather than accepting it. */
p~resolve("REQUIRES_LEGAL_REVIEW", -
  "The source text alone does not allow this component to promote the proposed relationship to established legal meaning.")

tResult = director~newPropositionTest(clause, p, "CONDITION", -
  "militia participation is a necessary condition of the operative right")
t = tResult~value
t~resolve("REQUIRES_LEGAL_REVIEW", -
  "Requires authoritative legal interpretation; an LLM assertion is insufficient.")

say "SOURCE:"
say text
say
say "PROPOSED INTERPRETATION:"
say p~text
say
say "PROPOSITION TEST:"
say t~assertion
say "RESULT:" t~result
say
say "CLAUSE CLOSURE:" clause~closureState
say "DOCUMENT COMPILE ELIGIBLE:" session~eligibleForCompilation
say
say "The source is retained; the disputed semantic relationship is not silently compiled."

::requires "LegalInterrogation.cls"
