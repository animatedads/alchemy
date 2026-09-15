/* A weak signal whose cohort basis is sound but confidence interval crosses
   the null remains an observation problem.  v0.2 must not misclassify every
   WEAK_SIGNAL as a cohort-quality repair. */
pop=.BrandJourneyPopulation~new('confidence-weak')
call assertTrue pop~configureProvenance('ANALYTICS_STORE','NOSQLSERVER_V077','JOURNEY','ALL_SUPPORT_V2','ALL_ELIGIBLE','SUPPORT_SCOPE_V2','OUT_OF_SCOPE_V2','OPAQUE_JOURNEY_ID','JOURNEY_ID','CANCELLATION_EVENT_V1')~ok,'complete provenance'
b=.BrandJourneyPopulationAggregateBucket~new('b','2026-08-01T00:00:00Z','2026-08-20T23:59:59Z','UNRESOLVED_SUPPORT','HIGH_SASS','CANCELLATION',1000,20,25,1,'TONE-V8','STYLE-05','PROC-9','MODEL-7',86400)
b~addSupportPoint('BRAND_JOURNEY:POPULATION_OBSERVATION:S'); b~addCounterPoint('BRAND_JOURNEY:POPULATION_OBSERVATION:C'); call assertTrue b~seal~ok,'bucket'; call assertTrue pop~addBucket(b)~ok,'add bucket'; call assertTrue pop~seal~ok,'population'
c=.BrandJourneyCohortDefinition~new('c','CURRENT','UNRESOLVED_SUPPORT','2026-08-01T00:00:00Z','2026-08-20T23:59:59Z',20,'HIGH_SASS','CANCELLATION',86400,'TONE-V8','STYLE-05','PROC-9','MODEL-7'); call assertTrue c~seal~ok,'cohort'
t=.BrandEvidenceThreshold~new('CONFIDENCE-GATE',1000,25,20,1,14,1,1.25,80,95,.true,.true,100,0,0,.true)
a=.BrandJourneyPopulationAnalyzer~new; ar=a~analyze(pop,c,t); call assertTrue ar~ok,'analysis'; ass=ar~value~assessment
call assertTrue ass~statisticalSufficient,'size/time gate passes'
call assertTrue ass~effectGate,'point-estimate effect gate passes'
call assertFalse ass~confidenceGate,'confidence gate fails'
call assertTrue ass~cohortQualityGate,'cohort quality passes'
call assertEqual 'WEAK_SIGNAL',ass~status,'confidence-only weak signal'
rr=a~reasoningReport(ar~value); call assertTrue rr~ok,'reasoning report'
binding=.BrandInterventionEvidenceBinding~new('binding-confidence',rr~value,'2026-08-21T12:00:00Z',1,'CLOCK'); call assertTrue binding~seal~ok,'binding'
ctx=.BrandInterventionContext~new('ctx-confidence','BRAND_JOURNEY:JC','2026-08-21T12:00:00Z','SUPPORT','UNRESOLVED',.true,'FRUSTRATED',70,.false); ctx~addObligation('PRESERVE_TRUTHFULNESS'); call assertTrue ctx~seal~ok,'context'
r=.BrandInterventionEngine~new~decide(ctx,binding); call assertTrue r~ok,'decision'; d=r~value
call assertEqual 'OBSERVE_ONLY',d~mode,'confidence-only weak signal remains observation'
call assertEqual 'OBSERVE_AND_COLLECT',d~proposal~proposalKind,'ordinary weak-signal proposal retained'
call assertTrue d~proposal~hasObjective('OBSERVE_SIGNAL_AND_COLLECT_COMPARABLE_EVIDENCE'),'collect comparable evidence'
call assertTrue d~proposal~hasAvoidance('TREAT_WEAK_SIGNAL_AS_BEHAVIOURAL_RULE'),'weak signal not rule'
call assertFalse d~proposal~hasObjective('REPAIR_COHORT_EVIDENCE_BEFORE_BEHAVIOURAL_INFERENCE'),'no false cohort-repair objective'
call assertNotContains d~rationales,'COHORT_QUALITY_GATE_FAILED','no cohort-quality rationale'
say 'PASS test_confidence_weak_observe_only'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
assertNotContains: procedure; use arg arr,needle,label; do x over arr; if x==needle then do; say 'FAIL:' label 'unexpected='needle; exit 1; end; end; return
::requires 'BrandIntervention.cls'
