/*
 * Example policy only.  These are FederationBank work-management semantics,
 * not statements of law and not Core Banking instructions.
 */
::class FederationBankCasePolicyFixtures public
::method standardPolicy class
  p = .RelationshipCasePolicy~new

  /* Opening/classification is policy, not code in the case engine. */
  p~addOpenRule(.RelationshipCaseOpenRule~new("OPEN-GENERAL", "*", "*", "NEW", "NORMAL", "INTERNAL", "SERVICE"))
  p~addOpenRule(.RelationshipCaseOpenRule~new("OPEN-COMPLAINT", "COMPLAINT", "*", "NEW", "HIGH", "INTERNAL", "COMPLAINTS"))
  p~addOpenRule(.RelationshipCaseOpenRule~new("OPEN-EXTERNAL-PRESSURE", "EXTERNAL_PRESSURE", "*", "NEW", "HIGH", "RESTRICTED", "COMPLIANCE"))

  /* Default attachments are deliberately permissive for INTERNAL evidence;
     sensitive kinds can then be narrowed by more-specific rules. */
  p~addElementRule(.RelationshipCaseElementRule~new("ELEMENT-DEFAULT", "*", "*", "*", "*", "*", .true))
  p~addElementRule(.RelationshipCaseElementRule~new("ELEMENT-CORE-CONTROL-COMPLIANCE", "*", "*", "ACCOUNT_CONTROL", "*", "COMPLIANCE", .true))
  p~addElementRule(.RelationshipCaseElementRule~new("ELEMENT-CORE-CONTROL-DENY-TELLER", "*", "*", "ACCOUNT_CONTROL", "*", "TELLER", .false))

  /* General work lifecycle. */
  p~addTransitionRule(.RelationshipCaseTransitionRule~new("TRIAGE", "*", "NEW", "START_TRIAGE", "TRIAGE", "*"))
  p~addTransitionRule(.RelationshipCaseTransitionRule~new("REVIEW", "*", "TRIAGE", "START_SPECIALIST_REVIEW", "SPECIALIST_REVIEW", "*"))
  p~addTransitionRule(.RelationshipCaseTransitionRule~new("RESOLVE-NO-ACTION", "*", "SPECIALIST_REVIEW", "RESOLVE_NO_ACTION", "RESOLVED", "*"))

  /* Action-required path demands an assessment and an authoritative decision
     reference.  An external signal by itself can never satisfy this. */
  r = .RelationshipCaseTransitionRule~new("ACTION-REQUIRED", "*", "SPECIALIST_REVIEW", "MARK_ACTION_REQUIRED", "ACTION_REQUIRED", "COMPLIANCE")
  r~requireElement("ASSESSMENT", "*")
  r~requireElement("DECISION", "*")
  p~addTransitionRule(r)
  r = .RelationshipCaseTransitionRule~new("ACTION-AUTHORISED", "*", "ACTION_REQUIRED", "AUTHORISE_EXECUTION", "AUTHORISED", "COMPLIANCE")
  r~requireElement("DECISION", "*")
  p~addTransitionRule(r)
  r = .RelationshipCaseTransitionRule~new("ACTION-EXECUTED", "*", "AUTHORISED", "RECORD_EXECUTION", "EXECUTED", "COMPLIANCE")
  r~requireElement("ACCOUNT_CONTROL", "*")
  p~addTransitionRule(r)
  p~addTransitionRule(.RelationshipCaseTransitionRule~new("ACTION-RESOLVE", "*", "EXECUTED", "RESOLVE", "RESOLVED", "COMPLIANCE"))

  /* Complaint path remains a case policy specialization. */
  r = .RelationshipCaseTransitionRule~new("COMPLAINT-INVESTIGATE", "COMPLAINT", "TRIAGE", "START_INVESTIGATION", "INVESTIGATION", "*" )
  r~requireElement("INTERACTION", "*")
  p~addTransitionRule(r)
  r = .RelationshipCaseTransitionRule~new("COMPLAINT-OUTCOME", "COMPLAINT", "INVESTIGATION", "RECORD_OUTCOME", "OUTCOME_READY", "COMPLAINTS")
  r~requireElement("ASSESSMENT", "*")
  p~addTransitionRule(r)
  r = .RelationshipCaseTransitionRule~new("COMPLAINT-COMMUNICATE", "COMPLAINT", "OUTCOME_READY", "RECORD_CUSTOMER_COMMUNICATION", "RESOLVED", "COMPLAINTS")
  r~requireElement("COMMUNICATION", "*")
  p~addTransitionRule(r)

  /* Projection rules are information-barrier policy, not random UI hiding. */
  p~addProjectionRule(.RelationshipCaseProjectionRule~new("VIEW-DEFAULT", "*", "*", "INTERNAL", "SHELL"))
  p~addProjectionRule(.RelationshipCaseProjectionRule~new("VIEW-COMPLIANCE", "*", "COMPLIANCE", "RESTRICTED", "SHELL"))
  p~addProjectionRule(.RelationshipCaseProjectionRule~new("VIEW-LEGAL", "*", "LEGAL", "RESTRICTED", "SHELL"))
  p~addProjectionRule(.RelationshipCaseProjectionRule~new("VIEW-EXTERNAL-TELLER", "EXTERNAL_PRESSURE", "TELLER", "INTERNAL", "SHELL"))
  return p~seal

::method publishedCatalog class
  p = self~standardPolicy
  c = .InstitutionalPolicyCatalog~new
  from = .DateTime~new - .TimeSpan~new(0,0,0,0,1)
  release = .InstitutionalPolicyRelease~new(.RelationshipCaseBuild~DEFAULT_POLICY_ID, "1", from, .nil, "FederationBank Service Design", "FederationBank Risk", "", p)~seal
  result = c~publish(release)
  if result~ok = .false then raise syntax 88.920 array("Could not publish case policy: " || result~code || ":" || result~detail)
  return c

::requires "RelationshipCase.cls"
::requires "InstitutionalPolicy.cls"
