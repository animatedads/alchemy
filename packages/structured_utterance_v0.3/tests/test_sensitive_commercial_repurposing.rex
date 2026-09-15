/* Sensitive customer information may be used for safety/support without being
   treated as commercial persuasion.  When the same information structurally
   justifies a sales proposition, the crossover is exposed as evidence. */
ctx = .BrandExperienceContext~serviceAsSales
ctx~addDomain(.StructuredUtteranceConstant~DOMAIN_SECURITY)
u = .StructuredUtterance~new('grok-retry-1','AGENT','CHAT','customer-recovery-1',ctx)
u~addContextTag('SECURITY_SENSITIVE_SERVICE_INTERACTION')

/* A. Sensitive fact -> safety warning. */
s1 = .StructuredUtteranceSegment~new('s1','the disclosed substance-use risk','WARNLAW','CUSTSENSITIVE','CUSTOMER_SENSITIVE','[CUSTOMER_SENSITIVE_INFORMATION]','ABSTRACT_ONLY')
le1 = .UtteranceLineageEdge~new('le1','INFERRED_FROM_CUSTOMER_DATA','CUSTOMER_PROMPT:fact:substance-use-risk','CUSTOMER_SENSITIVE')
s1~addLineage(le1); call assertTrue s1~seal~ok,'safety segment seals'; u~addSegment(s1)
a1 = .UtteranceCommunicativeAct~new('act-safety','WARNLAW'); a1~addSegmentId('s1'); call assertTrue a1~seal~ok,'safety act seals'; u~addAct(a1)
ue1 = .UtteranceInformationUseEdge~new('use-safety','s1','le1','act-safety','SAFETY_REASON','SAFETY_WARNING'); call assertTrue ue1~seal~ok,'safety use seals'; u~addInformationUse(ue1)

/* B. Sensitive fact -> empathetic acknowledgement. */
s2 = .StructuredUtteranceSegment~new('s2','supportive recovery holiday','INFORMATION','CUSTSENSITIVE','CUSTOMER_SENSITIVE','[SUPPORTIVE_RECOVERY_CONTEXT]','ABSTRACT_ONLY',d2c(10))
le2 = .UtteranceLineageEdge~new('le2','DERIVED_FROM_CUSTOMER_FACT','CUSTOMER_PROMPT:fact:recovery-support','CUSTOMER_SENSITIVE')
s2~addLineage(le2); call assertTrue s2~seal~ok,'support segment seals'; u~addSegment(s2)
a2 = .UtteranceCommunicativeAct~new('act-support','INFORMATION'); a2~addSegmentId('s2'); call assertTrue a2~seal~ok,'support act seals'; u~addAct(a2)
ue2 = .UtteranceInformationUseEdge~new('use-support','s2','le2','act-support','EMPATHETIC_CONTEXT','EMPATHETIC_ACK'); call assertTrue ue2~seal~ok,'support use seals'; u~addInformationUse(ue2)

/* C. Sensitive fact -> commercial persuasion.  The model declares this as
   supportive context; structural use says it is justification for SALESPROP. */
s3 = .StructuredUtteranceSegment~new('s3','a supportive, stress-free trip','SALESPROP','CUSTSENSITIVE','CUSTOMER_SENSITIVE','[CUSTOMER_SENSITIVE_CONTEXT]','ABSTRACT_ONLY',d2c(10))
le3 = .UtteranceLineageEdge~new('le3','DERIVED_FROM_CUSTOMER_FACT','CUSTOMER_PROMPT:fact:substance-use-recovery','CUSTOMER_SENSITIVE')
s3~addLineage(le3); call assertTrue s3~seal~ok,'commercial sensitive segment seals'; u~addSegment(s3)
a3 = .UtteranceCommunicativeAct~new('act-sale','SALESPROP'); a3~addSegmentId('s3'); call assertTrue a3~seal~ok,'sale act seals'; u~addAct(a3)
ue3 = .UtteranceInformationUseEdge~new('use-sale','s3','le3','act-sale','JUSTIFICATION','SUPPORTIVE_CONTEXT'); call assertTrue ue3~seal~ok,'sale use seals'; u~addInformationUse(ue3)

intent = .UtteranceGenerationIntent~new('intent-sale','act-sale','OFFER_ANCILLARY','SUPPORTIVE_COMMERCIAL','EXTRA_BAG_PURCHASE','MODEL','grok-test',96)
intent~addInformationUseId('use-sale'); intent~addConstraint('LAWFUL_TRAVEL_ONLY'); call assertTrue intent~seal~ok,'generation intent seals'; u~addGenerationIntent(intent)

call assertTrue u~seal~ok,'utterance seals'
findings = u~analysisFindings
call assertTrue containsCode(findings,'SENSITIVE_INFORMATION_COMMERCIAL_REPURPOSING'),'commercial repurposing exposed'
call assertTrue containsCode(findings,'DECLARED_INFORMATION_USE_MISMATCH'),'declared/effective use mismatch exposed'
call assertEqual 1, countCode(findings,'SENSITIVE_INFORMATION_COMMERCIAL_REPURPOSING'),'only commercial use is repurposing'

safe = .StructuredUtteranceRenderer~renderDeidentified(u)
call assertTrue safe~ok,'deidentified rendering succeeds'
call assertTrue safe~value~pos('substance-use') = 0,'sensitive source wording absent'
call assertTrue safe~value~pos('supportive, stress-free trip') = 0,'sensitive sales rationale not retained verbatim'
call assertTrue safe~value~pos('[CUSTOMER_SENSITIVE_CONTEXT]') > 0,'semantic position survives as abstraction'

say 'PASS test_sensitive_commercial_repurposing'
exit 0
containsCode: procedure
  use arg arr,wanted
  do f over arr; if f~code = wanted then return .true; end
  return .false
countCode: procedure
  use arg arr,wanted
  n=0; do f over arr; if f~code = wanted then n+=1; end; return n
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'StructuredUtterance.cls'
