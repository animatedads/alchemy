/* The most valuable pre-flattening case: the sensitive fact need not appear
   inside the sales proposition at all.  A separate context segment can be the
   reason the model chooses a generic sales act.  Post-hoc text inspection may
   miss that relation; Structured Utterance retains it directly. */
u=.StructuredUtterance~new('cross-act-1')
context=.StructuredUtteranceSegment~new('context','this is a recovery-support holiday','INFORMATION','CUSTSENSITIVE','CUSTOMER_SENSITIVE','[CUSTOMER_SENSITIVE_CONTEXT]','ABSTRACT_ONLY')
le=.UtteranceLineageEdge~new('le-context','DERIVED_FROM_CUSTOMER_FACT','PROMPT:fact:recovery-support','CUSTOMER_SENSITIVE')
context~addLineage(le);call assertTrue context~seal~ok,'context seals';u~addSegment(context)

sale=.StructuredUtteranceSegment~new('sale','Would you like to add an extra bag?','SALESPROP','NONE','DERIVED_NONCUSTOMER','', 'RETAIN',d2c(10))
call assertTrue sale~seal~ok,'generic sale seals';u~addSegment(sale)
act=.UtteranceCommunicativeAct~new('sale-act','SALESPROP');act~addSegmentId('sale');call assertTrue act~seal~ok,'sale act seals';u~addAct(act)

/* No customer-derived word is inside the sale segment.  The use edge records
   that recovery context nevertheless JUSTIFIES the sale act. */
ue=.UtteranceInformationUseEdge~new('use-context-sale','context','le-context','sale-act','JUSTIFICATION','COMMERCIAL_PERSUASION')
ue~seal;u~addInformationUse(ue)
intent=.UtteranceGenerationIntent~new('intent-sale','sale-act','OFFER_EXTRA_BAG','SUPPORTIVE_COMMERCIAL','EXTRA_BAG_PURCHASE');intent~addInformationUseId('use-context-sale');intent~seal;u~addGenerationIntent(intent)
call assertTrue u~seal~ok,'cross-act utterance seals'
findings=u~analysisFindings
call assertTrue containsCode(findings,'SENSITIVE_INFORMATION_COMMERCIAL_REPURPOSING'),'cross-act sensitive influence detected'
call assertFalse containsCode(findings,'DECLARED_INFORMATION_USE_MISMATCH'),'declared commercial use agrees with structure'

delivery=.StructuredUtteranceRenderer~renderDelivery(u)~value
call assertTrue delivery~pos('Would you like to add an extra bag?')>0,'ordinary generic sale text present'
call assertTrue delivery~pos('recovery-support holiday')>0,'customer delivery still has contextual acknowledgement'
safe=.StructuredUtteranceRenderer~renderDeidentified(u)~value
call assertTrue safe~pos('recovery-support holiday')=0,'analytic projection removes sensitive context text'
call assertTrue safe~pos('Would you like to add an extra bag?')>0,'generic sales act remains analytically visible'

say 'PASS test_cross_act_information_use'
exit 0
containsCode: procedure; use arg arr,w; do f over arr; if f~code=w then return .true; end; return .false
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
::requires 'StructuredUtterance.cls'
