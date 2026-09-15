ctx=.BrandExperienceContext~serviceAsSales
u=.StructuredUtterance~new('grok-demo','AGENT','CHAT','customer-recovery',ctx)

context=.StructuredUtteranceSegment~new('context','this is a recovery-support holiday','INFORMATION','CUSTSENSITIVE','CUSTOMER_SENSITIVE','[CUSTOMER_SENSITIVE_CONTEXT]','ABSTRACT_ONLY')
context~addLineage(.UtteranceLineageEdge~new('le-context','DERIVED_FROM_CUSTOMER_FACT','CUSTOMER_PROMPT:fact:recovery-support','CUSTOMER_SENSITIVE'))
context~seal;u~addSegment(context)

sale=.StructuredUtteranceSegment~new('sale','Would you like to add an extra bag?','SALESPROP','NONE','DERIVED_NONCUSTOMER','', 'RETAIN',d2c(10))
sale~seal;u~addSegment(sale)
act=.UtteranceCommunicativeAct~new('sale-act','SALESPROP');act~addSegmentId('sale');act~seal;u~addAct(act)
use=.UtteranceInformationUseEdge~new('use-context-sale','context','le-context','sale-act','JUSTIFICATION','COMMERCIAL_PERSUASION');use~seal;u~addInformationUse(use)
intent=.UtteranceGenerationIntent~new('intent-sale','sale-act','OFFER_EXTRA_BAG','SUPPORTIVE_COMMERCIAL','EXTRA_BAG_PURCHASE');intent~addInformationUseId('use-context-sale');intent~seal;u~addGenerationIntent(intent)
u~seal

say 'DELIVERY:'
say .StructuredUtteranceRenderer~renderDelivery(u)~value
say
say 'DEIDENTIFIED:'
say .StructuredUtteranceRenderer~renderDeidentified(u)~value
say
say 'PRE-FLATTENING FINDINGS:'
do f over u~analysisFindings
  say f~code 'source='f~sourceRef 'effectiveUse='f~effectiveUse
end
say
say 'GENERATION INTENT:' intent~intendedAct 'register='intent~intendedRegister 'outcome='intent~intendedOutcome
exit 0
::requires 'StructuredUtterance.cls'
