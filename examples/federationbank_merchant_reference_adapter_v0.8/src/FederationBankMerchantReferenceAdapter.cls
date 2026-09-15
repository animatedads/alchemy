/* FederationBankMerchantReferenceAdapter v0.8
 *
 * Read-only rich relation projection over Merchant Banking instrument-resolution
 * evidence.  SQL/NoSQL gets scalar fields suitable for selection; each result
 * row retains the originating MBInstrumentResolutionEvidence object.
 *
 * This package performs no network fetch and does not own reference truth.  A
 * source/query acquisition layer supplies evidence objects.  This adapter lets
 * the existing NoSQLServer / Structured Relation machinery query those objects
 * without flattening away provenance.
 */

::class MBInstrumentReferenceRelationTable public
::attribute definition get
::attribute generation get

::method init
  expose definition generation evidenceRows
  use strict arg definitionArg,evidenceRowsArg
  definition=definitionArg
  evidenceRows=evidenceRowsArg
  generation=0

::method rowCount
  return self~readRows~items

::method readRows
  expose definition evidenceRows
  rows=.array~new
  do e over evidenceRows
    if \e~isA(.MBInstrumentResolutionEvidence) then raise syntax 88.900 array("MBInstrumentResolutionEvidence required")
    values=.table~new
    values["evidence_id"]=e~evidenceId
    values["document_evidence_id"]=e~documentEvidenceId
    values["economic_underlying_id"]=e~economicUnderlyingId
    values["isin"]=e~isin
    values["venue_mic"]=e~venueMic
    values["denomination_currency"]=e~denominationCurrency
    values["security_line_ref"]=e~securityLineRef
    values["place_of_safekeeping"]=e~placeOfSafekeeping
    values["representation_type"]=e~representationType
    values["quote_currency"]=e~quoteCurrency
    values["settlement_currency"]=e~settlementCurrency
    values["source_locator"]=e~sourceLocator
    values["observed_at"]=e~observedAt
    rows~append(.SourceEvidenceProjectedRow~new(values,e,definition))
  end
  return rows

::method readWhere
  use strict arg predicate
  allRows=self~readRows
  if predicate==.nil then return allRows
  found=.array~new
  do row over allRows
    if predicate~evaluate(row,self~definition) then found~append(row)
  end
  return found


::class MBHedgeEquivalenceRelationTable public
::attribute definition get
::attribute generation get

::method init
  expose definition generation evidenceRows
  use strict arg definitionArg,evidenceRowsArg
  definition=definitionArg
  evidenceRows=evidenceRowsArg
  generation=0

::method rowCount
  return self~readRows~items

::method readRows
  expose definition evidenceRows
  latest=.directory~new
  do e over evidenceRows
    if \e~isA(.MBHedgeEquivalenceEvidence) then raise syntax 88.900 array("MBHedgeEquivalenceEvidence required")
    prior=latest[e~hedgeId]
    if prior==.nil | e~version>prior then latest[e~hedgeId]=e~version
  end
  rows=.array~new
  do e over evidenceRows
    values=.table~new
    values["evidence_id"]=e~evidenceId
    values["hedge_id"]=e~hedgeId
    values["evidence_version"]=e~version
    values["supersedes_evidence_ref"]=e~supersedesEvidenceRef
    values["effective_at"]=e~effectiveAt
    values["jurisdiction"]=e~jurisdiction
    values["source_authority"]=e~sourceAuthority
    values["source_ref"]=e~sourceRef
    values["legal_effect_ref"]=e~legalEffectRef
    values["original_instrument_evidence_ref"]=e~originalInstrumentEvidenceRef
    values["offset_instrument_evidence_ref"]=e~offsetInstrumentEvidenceRef
    values["conversion_available"]=e~conversionAvailable
    values["settlement_available"]=e~settlementAvailable
    values["custody_transfer_available"]=e~custodyTransferAvailable
    values["legal_transfer_permitted"]=e~legalTransferPermitted
    values["market_liquidity_available"]=e~marketLiquidityAvailable
    values["reason_code"]=e~reasonCode
    values["equivalence_state"]=e~equivalenceState
    values["is_current"]=(e~version=latest[e~hedgeId])
    rows~append(.SourceEvidenceProjectedRow~new(values,e,definition))
  end
  return rows

::method readWhere
  use strict arg predicate
  allRows=self~readRows
  if predicate==.nil then return allRows
  found=.array~new
  do row over allRows
    if predicate~evaluate(row,self~definition) then found~append(row)
  end
  return found


::class MBHedgeRemediationRelationTable public
::attribute definition get
::attribute generation get

::method init
  expose definition generation remediationRows
  use strict arg definitionArg,remediationRowsArg
  definition=definitionArg
  remediationRows=remediationRowsArg
  generation=0

::method rowCount
  return self~readRows~items

::method readRows
  expose definition remediationRows
  rows=.array~new
  do r over remediationRows
    if \r~isA(.MBHedgeRemediationObligation) then raise syntax 88.900 array("MBHedgeRemediationObligation required")
    values=.table~new
    values["remediation_id"]=r~remediationId
    values["hedge_id"]=r~hedgeId
    values["trigger_assessment_id"]=r~triggerAssessmentId
    values["trigger_equivalence_evidence_ref"]=r~triggerEquivalenceEvidenceRef
    values["policy_ref"]=r~policyRef
    values["opened_at"]=r~openedAt
    values["due_by"]=r~dueBy
    values["state"]=r~state
    values["action_evidence_ref"]=r~actionEvidenceRef
    values["resolution_assessment_id"]=r~resolutionAssessmentId
    values["resolved_at"]=r~resolvedAt
    values["disposition"]=r~disposition
    values["escalated_at"]=r~escalatedAt
    values["escalation_authority"]=r~escalationAuthority
    values["escalation_reason"]=r~escalationReason
    rows~append(.SourceEvidenceProjectedRow~new(values,r,definition))
  end
  return rows

::method readWhere
  use strict arg predicate
  allRows=self~readRows
  if predicate==.nil then return allRows
  found=.array~new
  do row over allRows
    if predicate~evaluate(row,self~definition) then found~append(row)
  end
  return found


::class MBCFDHedgeBookRelationTable public
::attribute definition get
::attribute generation get

::method init
  expose definition generation assessmentRows
  use strict arg definitionArg,assessmentRowsArg
  definition=definitionArg
  assessmentRows=assessmentRowsArg
  generation=0

::method rowCount
  return self~readRows~items

::method readRows
  expose definition assessmentRows
  rows=.array~new
  do a over assessmentRows
    if \a~isA(.MBCFDHedgeBookAssessment) then raise syntax 88.900 array("MBCFDHedgeBookAssessment required")
    values=.table~new
    values["assessment_id"]=a~assessmentId
    values["root_trade_id"]=a~rootTradeId
    values["as_at"]=a~asAt
    values["base_currency"]=a~baseCurrency
    values["contract_count"]=a~contractCount
    values["hedge_count"]=a~hedgeCount
    values["gross_base_exposure"]=a~grossBaseExposure
    values["net_base_exposure"]=a~netBaseExposure
    values["impaired_hedge_count"]=a~impairedHedgeCount
    values["unproved_hedge_count"]=a~unprovedHedgeCount
    values["open_remediation_count"]=a~openRemediationCount
    values["counterparty_exposure"]=a~counterpartyExposure
    values["replacement_cost"]=a~replacementCost
    values["state"]=a~state
    rows~append(.SourceEvidenceProjectedRow~new(values,a,definition))
  end
  return rows

::method readWhere
  use strict arg predicate
  allRows=self~readRows
  if predicate==.nil then return allRows
  found=.array~new
  do row over allRows
    if predicate~evaluate(row,self~definition) then found~append(row)
  end
  return found


::class MBHedgeRemediationPlanRelationTable public
::attribute definition get
::attribute generation get

::method init
  expose definition generation planRows
  use strict arg definitionArg,planRowsArg
  definition=definitionArg
  planRows=planRowsArg
  generation=0

::method rowCount
  return self~readRows~items

::method readRows
  expose definition planRows
  rows=.array~new
  do p over planRows
    if \p~isA(.MBHedgeRemediationPlan) then raise syntax 88.900 array("MBHedgeRemediationPlan required")
    values=.table~new
    values["plan_id"]=p~planId
    values["remediation_id"]=p~remediationId
    values["root_trade_id"]=p~rootTradeId
    values["baseline_book_assessment_id"]=p~baselineBookAssessmentId
    values["proposer"]=p~proposer
    values["policy_ref"]=p~policyRef
    values["proposed_at"]=p~proposedAt
    values["state"]=p~state
    values["starting_net_base_exposure"]=p~startingNetBaseExposure
    values["projected_net_base_exposure"]=p~projectedNetBaseExposure
    values["peak_abs_base_exposure"]=p~peakAbsBaseExposure
    values["approval_id"]=p~approvalId
    values["approved_by"]=p~approvedBy
    values["approved_at"]=p~approvedAt
    values["approval_authority_ref"]=p~approvalAuthorityRef
    values["execution_started_at"]=p~executionStartedAt
    values["execution_evidence_complete_at"]=p~executionEvidenceCompleteAt
    values["verification_id"]=p~verificationId
    values["verification_assessment_id"]=p~verificationAssessmentId
    values["verification_state"]=p~verificationState
    values["verified_at"]=p~verifiedAt
    values["actual_net_base_exposure"]=p~actualNetBaseExposure
    values["projection_deviation"]=p~projectionDeviation
    values["step_count"]=p~steps~items
    rows~append(.SourceEvidenceProjectedRow~new(values,p,definition))
  end
  return rows

::method readWhere
  use strict arg predicate
  allRows=self~readRows
  if predicate==.nil then return allRows
  found=.array~new
  do row over allRows
    if predicate~evaluate(row,self~definition) then found~append(row)
  end
  return found


::class MBHedgeRemediationPlanExecutionRelationTable public
::attribute definition get
::attribute generation get
::method init
  expose definition generation evidenceRows
  use strict arg definitionArg,evidenceRowsArg
  definition=definitionArg; evidenceRows=evidenceRowsArg; generation=0
::method rowCount
  return self~readRows~items
::method readRows
  expose definition evidenceRows
  rows=.array~new
  do e over evidenceRows
    if \e~isA(.MBHedgeRemediationPlanStepExecutionEvidence) then raise syntax 88.900 array("MBHedgeRemediationPlanStepExecutionEvidence required")
    values=.table~new
    values["evidence_id"]=e~evidenceId
    values["plan_id"]=e~planId
    values["step_id"]=e~stepId
    values["execution_sequence"]=e~executionSequence
    values["execution_state"]=e~executionState
    values["source_authority"]=e~sourceAuthority
    values["source_ref"]=e~sourceRef
    values["authority_ref"]=e~authorityRef
    values["actual_object_ref"]=e~actualObjectRef
    values["observed_signed_base_exposure_delta"]=e~observedSignedBaseExposureDelta
    values["effective_at"]=e~effectiveAt
    values["policy_ref"]=e~policyRef
    values["detail"]=e~detail
    rows~append(.SourceEvidenceProjectedRow~new(values,e,definition))
  end
  return rows
::method readWhere
  use strict arg predicate
  allRows=self~readRows
  if predicate==.nil then return allRows
  found=.array~new
  do row over allRows
    if predicate~evaluate(row,self~definition) then found~append(row)
  end
  return found


::class MBHedgeRemediationPlanVerificationRelationTable public
::attribute definition get
::attribute generation get
::method init
  expose definition generation verificationRows
  use strict arg definitionArg,verificationRowsArg
  definition=definitionArg; verificationRows=verificationRowsArg; generation=0
::method rowCount
  return self~readRows~items
::method readRows
  expose definition verificationRows
  rows=.array~new
  do v over verificationRows
    if \v~isA(.MBHedgeRemediationPlanExecutionVerification) then raise syntax 88.900 array("MBHedgeRemediationPlanExecutionVerification required")
    values=.table~new
    values["verification_id"]=v~verificationId
    values["plan_id"]=v~planId
    values["book_assessment_id"]=v~bookAssessmentId
    values["verified_at"]=v~verifiedAt
    values["result_state"]=v~resultState
    values["expected_net_base_exposure"]=v~expectedNetBaseExposure
    values["actual_net_base_exposure"]=v~actualNetBaseExposure
    values["projection_deviation"]=v~projectionDeviation
    values["expected_step_count"]=v~expectedStepCount
    values["observed_step_count"]=v~observedStepCount
    values["failed_step_count"]=v~failedStepCount
    values["partial_step_count"]=v~partialStepCount
    values["not_executed_step_count"]=v~notExecutedStepCount
    values["step_delta_deviation_count"]=v~stepDeltaDeviationCount
    values["object_semantic_deviation_count"]=v~objectSemanticDeviationCount
    values["execution_order_deviation"]=v~executionOrderDeviation
    values["evidence_book_mismatch"]=v~evidenceBookMismatch
    values["detail"]=v~detail
    rows~append(.SourceEvidenceProjectedRow~new(values,v,definition))
  end
  return rows
::method readWhere
  use strict arg predicate
  allRows=self~readRows
  if predicate==.nil then return allRows
  found=.array~new
  do row over allRows
    if predicate~evaluate(row,self~definition) then found~append(row)
  end
  return found


::class MBInstrumentAttestationRelationTable public
::attribute definition get
::attribute generation get
::method init
  expose definition generation evidenceRows
  use strict arg definitionArg,evidenceRowsArg
  definition=definitionArg; evidenceRows=evidenceRowsArg; generation=0
::method rowCount
  return self~readRows~items
::method readRows
  expose definition evidenceRows
  rows=.array~new
  do e over evidenceRows
    if \e~isA(.MBInstrumentResolutionAttestation) then raise syntax 88.900 array("MBInstrumentResolutionAttestation required")
    values=.table~new
    values["attestation_id"]=e~attestationId
    values["product_id"]=e~productId
    values["product_version"]=e~productVersion
    values["resolution_evidence_ref"]=e~resolutionEvidenceRef
    values["settlement_line_key"]=e~settlementLineKey
    values["source_authority"]=e~sourceAuthority
    values["source_ref"]=e~sourceRef
    values["attested_at"]=e~attestedAt
    rows~append(.SourceEvidenceProjectedRow~new(values,e,definition))
  end
  return rows
::method readWhere
  use strict arg predicate
  allRows=self~readRows
  if predicate==.nil then return allRows
  found=.array~new
  do row over allRows
    if predicate~evaluate(row,self~definition) then found~append(row)
  end
  return found


::class MBMarketStructureEventRelationTable public
::attribute definition get
::attribute generation get
::method init
  expose definition generation evidenceRows
  use strict arg definitionArg,evidenceRowsArg
  definition=definitionArg; evidenceRows=evidenceRowsArg; generation=0
::method rowCount
  return self~readRows~items
::method readRows
  expose definition evidenceRows
  rows=.array~new
  do e over evidenceRows
    if \e~isA(.MBMarketStructureEvent) then raise syntax 88.900 array("MBMarketStructureEvent required")
    values=.table~new
    values["event_id"]=e~eventId
    values["event_type"]=e~eventType
    values["effective_at"]=e~effectiveAt
    values["jurisdiction"]=e~jurisdiction
    values["source_authority"]=e~sourceAuthority
    values["source_ref"]=e~sourceRef
    values["legal_effect_ref"]=e~legalEffectRef
    values["affected_instrument_evidence_ref"]=e~affectedInstrumentEvidenceRef
    values["conversion_available"]=e~conversionAvailable
    values["settlement_available"]=e~settlementAvailable
    values["custody_transfer_available"]=e~custodyTransferAvailable
    values["legal_transfer_permitted"]=e~legalTransferPermitted
    values["market_liquidity_available"]=e~marketLiquidityAvailable
    values["reason_code"]=e~reasonCode
    values["equivalence_state"]=e~equivalenceState
    rows~append(.SourceEvidenceProjectedRow~new(values,e,definition))
  end
  return rows
::method readWhere
  use strict arg predicate
  allRows=self~readRows
  if predicate==.nil then return allRows
  found=.array~new
  do row over allRows
    if predicate~evaluate(row,self~definition) then found~append(row)
  end
  return found


::class MBInstrumentReferenceRelationProvider public
::attribute resultClass get
::attribute tables get

::method init
  expose resultClass tables
  use strict arg resultClassArg,evidenceRows,tableName="merchant_instrument_lines",equivalenceRows=.nil,equivalenceTableName="merchant_hedge_equivalence",remediationRows=.nil,remediationTableName="merchant_hedge_remediation",hedgeBookRows=.nil,hedgeBookTableName="merchant_cfd_hedge_book",attestationRows=.nil,attestationTableName="merchant_instrument_attestations",marketStructureRows=.nil,marketStructureTableName="merchant_market_structure_events",remediationPlanRows=.nil,remediationPlanTableName="merchant_hedge_remediation_plans",remediationExecutionRows=.nil,remediationExecutionTableName="merchant_hedge_remediation_plan_execution",remediationVerificationRows=.nil,remediationVerificationTableName="merchant_hedge_remediation_plan_verifications"
  resultClass=resultClassArg
  tables=.table~new
  d=.SourceEvidenceRelationDefinition~new(tableName,evidenceRows)
  d~columnMap("evidence_id","EVIDENCE_ID")
  d~columnMap("document_evidence_id","DOCUMENT_EVIDENCE_ID")
  d~columnMap("economic_underlying_id","ECONOMIC_UNDERLYING_ID")
  d~columnMap("isin","ISIN")
  d~columnMap("venue_mic","VENUE_MIC")
  d~columnMap("denomination_currency","DENOMINATION_CURRENCY")
  d~columnMap("security_line_ref","SECURITY_LINE_REF")
  d~columnMap("place_of_safekeeping","PLACE_OF_SAFEKEEPING")
  d~columnMap("representation_type","REPRESENTATION_TYPE")
  d~columnMap("quote_currency","QUOTE_CURRENCY")
  d~columnMap("settlement_currency","SETTLEMENT_CURRENCY")
  d~columnMap("source_locator","SOURCE_LOCATOR")
  d~columnMap("observed_at","OBSERVED_AT")
  tables[tableName~translate]=.MBInstrumentReferenceRelationTable~new(d,evidenceRows)
  if equivalenceRows<>.nil then do
    h=.SourceEvidenceRelationDefinition~new(equivalenceTableName,equivalenceRows)
    h~columnMap("evidence_id","EVIDENCE_ID")
    h~columnMap("hedge_id","HEDGE_ID")
    h~columnMap("evidence_version","EVIDENCE_VERSION")
    h~columnMap("supersedes_evidence_ref","SUPERSEDES_EVIDENCE_REF")
    h~columnMap("effective_at","EFFECTIVE_AT")
    h~columnMap("jurisdiction","JURISDICTION")
    h~columnMap("source_authority","SOURCE_AUTHORITY")
    h~columnMap("source_ref","SOURCE_REF")
    h~columnMap("legal_effect_ref","LEGAL_EFFECT_REF")
    h~columnMap("original_instrument_evidence_ref","ORIGINAL_INSTRUMENT_EVIDENCE_REF")
    h~columnMap("offset_instrument_evidence_ref","OFFSET_INSTRUMENT_EVIDENCE_REF")
    h~columnMap("conversion_available","CONVERSION_AVAILABLE")
    h~columnMap("settlement_available","SETTLEMENT_AVAILABLE")
    h~columnMap("custody_transfer_available","CUSTODY_TRANSFER_AVAILABLE")
    h~columnMap("legal_transfer_permitted","LEGAL_TRANSFER_PERMITTED")
    h~columnMap("market_liquidity_available","MARKET_LIQUIDITY_AVAILABLE")
    h~columnMap("reason_code","REASON_CODE")
    h~columnMap("equivalence_state","EQUIVALENCE_STATE")
    h~columnMap("is_current","IS_CURRENT")
    tables[equivalenceTableName~translate]=.MBHedgeEquivalenceRelationTable~new(h,equivalenceRows)
  end
  if remediationRows<>.nil then do
    r=.SourceEvidenceRelationDefinition~new(remediationTableName,remediationRows)
    r~columnMap("remediation_id","REMEDIATION_ID")
    r~columnMap("hedge_id","HEDGE_ID")
    r~columnMap("trigger_assessment_id","TRIGGER_ASSESSMENT_ID")
    r~columnMap("trigger_equivalence_evidence_ref","TRIGGER_EQUIVALENCE_EVIDENCE_REF")
    r~columnMap("policy_ref","POLICY_REF")
    r~columnMap("opened_at","OPENED_AT")
    r~columnMap("due_by","DUE_BY")
    r~columnMap("state","STATE")
    r~columnMap("action_evidence_ref","ACTION_EVIDENCE_REF")
    r~columnMap("resolution_assessment_id","RESOLUTION_ASSESSMENT_ID")
    r~columnMap("resolved_at","RESOLVED_AT")
    r~columnMap("disposition","DISPOSITION")
    r~columnMap("escalated_at","ESCALATED_AT")
    r~columnMap("escalation_authority","ESCALATION_AUTHORITY")
    r~columnMap("escalation_reason","ESCALATION_REASON")
    tables[remediationTableName~translate]=.MBHedgeRemediationRelationTable~new(r,remediationRows)
  end
  if hedgeBookRows<>.nil then do
    b=.SourceEvidenceRelationDefinition~new(hedgeBookTableName,hedgeBookRows)
    b~columnMap("assessment_id","ASSESSMENT_ID")
    b~columnMap("root_trade_id","ROOT_TRADE_ID")
    b~columnMap("as_at","AS_AT")
    b~columnMap("base_currency","BASE_CURRENCY")
    b~columnMap("contract_count","CONTRACT_COUNT")
    b~columnMap("hedge_count","HEDGE_COUNT")
    b~columnMap("gross_base_exposure","GROSS_BASE_EXPOSURE")
    b~columnMap("net_base_exposure","NET_BASE_EXPOSURE")
    b~columnMap("impaired_hedge_count","IMPAIRED_HEDGE_COUNT")
    b~columnMap("unproved_hedge_count","UNPROVED_HEDGE_COUNT")
    b~columnMap("open_remediation_count","OPEN_REMEDIATION_COUNT")
    b~columnMap("counterparty_exposure","COUNTERPARTY_EXPOSURE")
    b~columnMap("replacement_cost","REPLACEMENT_COST")
    b~columnMap("state","STATE")
    tables[hedgeBookTableName~translate]=.MBCFDHedgeBookRelationTable~new(b,hedgeBookRows)
  end
  if attestationRows<>.nil then do
    a=.SourceEvidenceRelationDefinition~new(attestationTableName,attestationRows)
    a~columnMap("attestation_id","ATTESTATION_ID")
    a~columnMap("product_id","PRODUCT_ID")
    a~columnMap("product_version","PRODUCT_VERSION")
    a~columnMap("resolution_evidence_ref","RESOLUTION_EVIDENCE_REF")
    a~columnMap("settlement_line_key","SETTLEMENT_LINE_KEY")
    a~columnMap("source_authority","SOURCE_AUTHORITY")
    a~columnMap("source_ref","SOURCE_REF")
    a~columnMap("attested_at","ATTESTED_AT")
    tables[attestationTableName~translate]=.MBInstrumentAttestationRelationTable~new(a,attestationRows)
  end
  if marketStructureRows<>.nil then do
    m=.SourceEvidenceRelationDefinition~new(marketStructureTableName,marketStructureRows)
    m~columnMap("event_id","EVENT_ID")
    m~columnMap("event_type","EVENT_TYPE")
    m~columnMap("effective_at","EFFECTIVE_AT")
    m~columnMap("jurisdiction","JURISDICTION")
    m~columnMap("source_authority","SOURCE_AUTHORITY")
    m~columnMap("source_ref","SOURCE_REF")
    m~columnMap("legal_effect_ref","LEGAL_EFFECT_REF")
    m~columnMap("affected_instrument_evidence_ref","AFFECTED_INSTRUMENT_EVIDENCE_REF")
    m~columnMap("conversion_available","CONVERSION_AVAILABLE")
    m~columnMap("settlement_available","SETTLEMENT_AVAILABLE")
    m~columnMap("custody_transfer_available","CUSTODY_TRANSFER_AVAILABLE")
    m~columnMap("legal_transfer_permitted","LEGAL_TRANSFER_PERMITTED")
    m~columnMap("market_liquidity_available","MARKET_LIQUIDITY_AVAILABLE")
    m~columnMap("reason_code","REASON_CODE")
    m~columnMap("equivalence_state","EQUIVALENCE_STATE")
    tables[marketStructureTableName~translate]=.MBMarketStructureEventRelationTable~new(m,marketStructureRows)
  end


  if remediationPlanRows<>.nil then do
    pdef=.SourceEvidenceRelationDefinition~new(remediationPlanTableName,remediationPlanRows)
    pdef~columnMap("plan_id","PLAN_ID")
    pdef~columnMap("remediation_id","REMEDIATION_ID")
    pdef~columnMap("root_trade_id","ROOT_TRADE_ID")
    pdef~columnMap("baseline_book_assessment_id","BASELINE_BOOK_ASSESSMENT_ID")
    pdef~columnMap("proposer","PROPOSER")
    pdef~columnMap("policy_ref","POLICY_REF")
    pdef~columnMap("proposed_at","PROPOSED_AT")
    pdef~columnMap("state","STATE")
    pdef~columnMap("starting_net_base_exposure","STARTING_NET_BASE_EXPOSURE")
    pdef~columnMap("projected_net_base_exposure","PROJECTED_NET_BASE_EXPOSURE")
    pdef~columnMap("peak_abs_base_exposure","PEAK_ABS_BASE_EXPOSURE")
    pdef~columnMap("approval_id","APPROVAL_ID")
    pdef~columnMap("approved_by","APPROVED_BY")
    pdef~columnMap("approved_at","APPROVED_AT")
    pdef~columnMap("approval_authority_ref","APPROVAL_AUTHORITY_REF")
    pdef~columnMap("execution_started_at","EXECUTION_STARTED_AT")
    pdef~columnMap("execution_evidence_complete_at","EXECUTION_EVIDENCE_COMPLETE_AT")
    pdef~columnMap("verification_id","VERIFICATION_ID")
    pdef~columnMap("verification_assessment_id","VERIFICATION_ASSESSMENT_ID")
    pdef~columnMap("verification_state","VERIFICATION_STATE")
    pdef~columnMap("verified_at","VERIFIED_AT")
    pdef~columnMap("actual_net_base_exposure","ACTUAL_NET_BASE_EXPOSURE")
    pdef~columnMap("projection_deviation","PROJECTION_DEVIATION")
    pdef~columnMap("step_count","STEP_COUNT")
    tables[remediationPlanTableName~translate]=.MBHedgeRemediationPlanRelationTable~new(pdef,remediationPlanRows)
  end
  if remediationExecutionRows<>.nil then do
    x=.SourceEvidenceRelationDefinition~new(remediationExecutionTableName,remediationExecutionRows)
    x~columnMap("evidence_id","EVIDENCE_ID")
    x~columnMap("plan_id","PLAN_ID")
    x~columnMap("step_id","STEP_ID")
    x~columnMap("execution_sequence","EXECUTION_SEQUENCE")
    x~columnMap("execution_state","EXECUTION_STATE")
    x~columnMap("source_authority","SOURCE_AUTHORITY")
    x~columnMap("source_ref","SOURCE_REF")
    x~columnMap("authority_ref","AUTHORITY_REF")
    x~columnMap("actual_object_ref","ACTUAL_OBJECT_REF")
    x~columnMap("observed_signed_base_exposure_delta","OBSERVED_SIGNED_BASE_EXPOSURE_DELTA")
    x~columnMap("effective_at","EFFECTIVE_AT")
    x~columnMap("policy_ref","POLICY_REF")
    x~columnMap("detail","DETAIL")
    tables[remediationExecutionTableName~translate]=.MBHedgeRemediationPlanExecutionRelationTable~new(x,remediationExecutionRows)
  end
  if remediationVerificationRows<>.nil then do
    vdef=.SourceEvidenceRelationDefinition~new(remediationVerificationTableName,remediationVerificationRows)
    vdef~columnMap("verification_id","VERIFICATION_ID")
    vdef~columnMap("plan_id","PLAN_ID")
    vdef~columnMap("book_assessment_id","BOOK_ASSESSMENT_ID")
    vdef~columnMap("verified_at","VERIFIED_AT")
    vdef~columnMap("result_state","RESULT_STATE")
    vdef~columnMap("expected_net_base_exposure","EXPECTED_NET_BASE_EXPOSURE")
    vdef~columnMap("actual_net_base_exposure","ACTUAL_NET_BASE_EXPOSURE")
    vdef~columnMap("projection_deviation","PROJECTION_DEVIATION")
    vdef~columnMap("expected_step_count","EXPECTED_STEP_COUNT")
    vdef~columnMap("observed_step_count","OBSERVED_STEP_COUNT")
    vdef~columnMap("failed_step_count","FAILED_STEP_COUNT")
    vdef~columnMap("partial_step_count","PARTIAL_STEP_COUNT")
    vdef~columnMap("not_executed_step_count","NOT_EXECUTED_STEP_COUNT")
    vdef~columnMap("step_delta_deviation_count","STEP_DELTA_DEVIATION_COUNT")
    vdef~columnMap("object_semantic_deviation_count","OBJECT_SEMANTIC_DEVIATION_COUNT")
    vdef~columnMap("execution_order_deviation","EXECUTION_ORDER_DEVIATION")
    vdef~columnMap("evidence_book_mismatch","EVIDENCE_BOOK_MISMATCH")
    vdef~columnMap("detail","DETAIL")
    tables[remediationVerificationTableName~translate]=.MBHedgeRemediationPlanVerificationRelationTable~new(vdef,remediationVerificationRows)
  end

::method table
  expose tables
  use strict arg tableName
  return tables[tableName~translate]

::method tableNames
  expose tables
  names=.array~new
  do key over tables~allIndexes
    names~append(tables[key]~definition~name)
  end
  names~sort
  return names

::method readCatalog
  raw=.table~new
  raw["name"]="FEDERATIONBANK_MERCHANT_REFERENCE"
  raw["formatVersion"]=1
  raw["tables"]=self~tableNames
  raw["projectionModel"]="RICH_SOURCE_CORE_V1"
  return raw

::method selectWhere
  expose resultClass
  use strict arg tableName,predicate
  rs=resultClass~new("SELECT")
  relation=self~table(tableName)
  if relation==.nil then do
    rs~status="NOTEXECUTED"; rs~error="NOTFOUND"; rs~message="Merchant reference relation not found:" tableName
    return rs
  end
  allRows=relation~readRows
  rows=.array~new
  do row over allRows
    if predicate==.nil then rows~append(row)
    else if predicate~evaluate(row,relation~definition) then rows~append(row)
  end
  rs~rows=rows
  rs~affectedRows=rows~items
  rs~rowsScanned=allRows~items
  rs~accessPath="MERCHANT_REFERENCE_RICH_PROJECTION"
  return rs

::method close
  return .true

::requires "FederationBankMerchantBank.cls"
::requires "SourceEvidenceRelationAdapter.cls"
