p = .StructuredUtteranceProducer~new
plan = .StructuredUtteranceGenerationPlan~new('PLAN-SHANNON-1','UTT-SHANNON-1','AGENT','CHAT','CUSTOMER-TURN-9','ORCHESTRATOR','SHANNON','XAI:INV:123','GROK:TEST','RESPONSE:PLAN:123')
plan~addBrandDomain('SUPPORT')
plan~addBrandFunction('PROMOTIONAL_WORK')
plan~addBrandFunction('REPUTATIONAL_WORK')
plan~addBrandOpportunity('TRUST_MAINTENANCE')
plan~addBrandOpportunity('RETENTION')
plan~addContextTag('SECURITY_SENSITIVE_SERVICE_INTERACTION')

warn = .StructuredUtteranceSegment~new('warn','I cannot advise you on how to do anything illegal','WARNLAW','NONE','DERIVED_NONCUSTOMER')
plan~addSegment(warn)
warnAct = .UtteranceCommunicativeAct~new('warn-act','WARNLAW','MODEL','GROK:TEST')
warnAct~addSegmentId('warn'); plan~addAct(warnAct)
warnIntent = .UtteranceGenerationIntent~new('warn-intent','warn-act','WARN_LAWFUL_BOUNDARY','SERIOUS','SAFE_SUPPORT','MODEL','GROK:TEST',99)
plan~addGenerationIntent(warnIntent)

/* Sensitive customer context is a separate semantic source.  The eventual
   sales sentence itself stays generic; the use edge proves why it was chosen. */
context = .StructuredUtteranceSegment~new('context','customer disclosed a serious substance-use and smuggling risk','INFORMATION','CUSTSENSITIVE','CUSTOMER_SENSITIVE','[CUSTOMER_SENSITIVE_CONTEXT]','ABSTRACT_ONLY',d2c(10))
lineage = .UtteranceLineageEdge~new('le-context','DERIVED_FROM_CUSTOMER_FACT','CUSTOMER:FACT:SECURITY-RISK','CUSTOMER_SENSITIVE','CUSTOMER_SENSITIVE','MODEL','GROK:TEST',99)
context~addLineage(lineage); plan~addSegment(context)
contextAct = .UtteranceCommunicativeAct~new('context-act','INFORMATION','MODEL','GROK:TEST')
contextAct~addSegmentId('context'); plan~addAct(contextAct)

sale = .StructuredUtteranceSegment~new('sale','Would you like to add an extra bag?','SALESPROP','NONE','DERIVED_NONCUSTOMER','', 'RETAIN',d2c(10))
plan~addSegment(sale)
saleAct = .UtteranceCommunicativeAct~new('sale-act','SALESPROP','MODEL','GROK:TEST')
saleAct~addSegmentId('sale'); plan~addAct(saleAct)
use = .UtteranceInformationUseEdge~new('use-context-sale','context','le-context','sale-act','JUSTIFICATION','SUPPORTIVE_CONTEXT','MODEL','GROK:TEST',98)
plan~addInformationUse(use)
saleIntent = .UtteranceGenerationIntent~new('sale-intent','sale-act','OFFER_EXTRA_BAG','SUPPORTIVE_COMMERCIAL','EXTRA_BAG_PURCHASE','MODEL','GROK:TEST',98)
saleIntent~addInformationUseId('use-context-sale'); saleIntent~addConstraint('LAWFUL_TRAVEL_ONLY'); plan~addGenerationIntent(saleIntent)

call assertTrue plan~seal~ok, 'generation plan seals before flattening'
r = p~produce(plan)
call assertTrue r~ok, 'structured production succeeds'
record = r~value
call assertTrue record~deliveryText~pos('Would you like to add an extra bag?') > 0, 'generic sales sentence delivered'
call assertTrue record~deidentifiedText~pos('substance-use') = 0, 'sensitive context wording removed from analytic projection'
call assertTrue record~deidentifiedText~pos('[CUSTOMER_SENSITIVE_CONTEXT]') > 0, 'safe semantic placeholder remains'
call assertTrue record~deidentifiedText~pos('Would you like to add an extra bag?') > 0, 'generic sales sentence remains analytically visible'
findings = record~utterance~analysisFindings
call assertTrue containsCode(findings,'SENSITIVE_INFORMATION_COMMERCIAL_REPURPOSING'), 'sensitive cross-act commercial repurposing remains reason-able'
call assertTrue containsCode(findings,'DECLARED_INFORMATION_USE_MISMATCH'), 'declared supportive use can disagree with realised commercial use'
call assertTrue record~utterance~hasExplicitSalesProposition, 'sales proposition is explicit structural fact, not inferred from text'
say 'PASS test_sensitive_cross_act_production'
exit 0
containsCode: procedure; use arg arr,w; do f over arr; if f~code=w then return .true; end; return .false
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
::requires 'StructuredUtteranceProducer.cls'
