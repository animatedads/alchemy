/* Brand Interaction Effect v0.6 can have sufficient counts, effect and
   confidence while refusing support because cohort-selection quality failed.
   Intervention must treat that as an evidence-construction review, not as a
   behavioural/tone signal to observe or apply. */
pop=.BrandJourneyPopulation~new('cohort-quality')
call assertTrue pop~configureProvenance('ANALYTICS_STORE','NOSQLSERVER_V077','JOURNEY','UNSPECIFIED','ALL_ELIGIBLE','SUPPORT_SCOPE_V2','OUT_OF_SCOPE_V2','OPAQUE_JOURNEY_ID','JOURNEY_ID','CANCELLATION_EVENT_V1')~ok,'provenance configured with explicitly unknown selection rule'
b=.BrandJourneyPopulationAggregateBucket~new('b','2026-08-01T00:00:00Z','2026-08-20T23:59:59Z','UNRESOLVED_SUPPORT','HIGH_SASS','CANCELLATION',1000,100,100,30,'TONE-V8','STYLE-05','PROC-9','MODEL-7',86400)
b~addSupportPoint('BRAND_JOURNEY:POPULATION_OBSERVATION:S'); b~addCounterPoint('BRAND_JOURNEY:POPULATION_OBSERVATION:C'); call assertTrue b~seal~ok,'bucket'; call assertTrue pop~addBucket(b)~ok,'add bucket'; call assertTrue pop~seal~ok,'population'
c=.BrandJourneyCohortDefinition~new('c','CURRENT','UNRESOLVED_SUPPORT','2026-08-01T00:00:00Z','2026-08-20T23:59:59Z',20,'HIGH_SASS','CANCELLATION',86400,'TONE-V8','STYLE-05','PROC-9','MODEL-7'); call assertTrue c~seal~ok,'cohort'
t=.BrandEvidenceThreshold~new('QUALITY-GATE',1000,25,20,5,14,1,1.25,80,95,.true,.true,100,0,0,.true)
a=.BrandJourneyPopulationAnalyzer~new; ar=a~analyze(pop,c,t); call assertTrue ar~ok,'analysis'; ass=ar~value~assessment
call assertTrue ass~statisticalSufficient,'size/time gate passes'
call assertTrue ass~effectGate,'effect gate passes'
call assertTrue ass~confidenceGate,'confidence gate passes'
call assertFalse ass~cohortQualityGate,'cohort quality gate fails'
call assertEqual 'WEAK_SIGNAL',ass~status,'cohort gate blocks supported claim'
call assertContains ass~reasons,'COHORT_SELECTION_RULE_REQUIRED','selection reason retained'
rr=a~reasoningReport(ar~value); call assertTrue rr~ok,'reasoning report'
binding=.BrandInterventionEvidenceBinding~new('binding-quality',rr~value,'2026-08-21T12:00:00Z',1,'CLOCK'); call assertTrue binding~seal~ok,'binding'
ctx=.BrandInterventionContext~new('ctx-quality','BRAND_JOURNEY:JQ','2026-08-21T12:00:00Z','SUPPORT','UNRESOLVED',.true,'FRUSTRATED',70,.false); ctx~addObligation('PRESERVE_TRUTHFULNESS'); call assertTrue ctx~seal~ok,'context'
r=.BrandInterventionEngine~new~decide(ctx,binding); call assertTrue r~ok,'decision'; d=r~value
call assertEqual 'REVIEW_REQUIRED',d~mode,'cohort-quality failure routes to review'
call assertEqual 'COHORT_EVIDENCE_QUALITY_REVIEW',d~proposal~proposalKind,'evidence-quality proposal kind'
call assertTrue d~proposal~hasObjective('REPAIR_COHORT_EVIDENCE_BEFORE_BEHAVIOURAL_INFERENCE'),'repair evidence first'
call assertTrue d~proposal~hasObjective('ESTABLISH_EXPLICIT_COHORT_SELECTION_PROVENANCE'),'selection provenance objective'
call assertTrue d~proposal~hasObjective('REANALYZE_AFTER_COHORT_QUALITY_REVIEW'),'reanalyze after repair'
call assertTrue d~proposal~hasAvoidance('ALTER_BEHAVIOUR_FROM_COHORT_QUALITY_FAILED_EVIDENCE'),'no behaviour change from bad cohort basis'
call assertTrue d~proposal~hasAvoidance('TREAT_ANALYZABLE_SUBSET_AS_SOURCE_POPULATION'),'no denominator overclaim'
call assertTrue d~proposal~hasAvoidance('INFER_REPRESENTATIVENESS_FROM_SAMPLE_SIZE'),'large sample not automatically representative'
call assertFalse d~proposal~hasObjective('REDUCE_DISMISSIVE_REGISTER'),'tone guidance not inferred from failed cohort basis'
call assertContains d~rationales,'COHORT_QUALITY_GATE_FAILED','decision rationale explicit'
text=d~reasoningMaterial
call assertTrue text~pos('COHORT_QUALITY_GATE=0')>0,'failed gate survives to reasoning material'
call assertTrue text~pos('SOURCE_SYSTEM=NOSQLSERVER_V077')>0,'source-system provenance survives'
call assertTrue text~pos('SELECTION_RULE_ID=UNSPECIFIED')>0,'unknown selection rule survives without invention'
call assertTrue text~pos('REASON=COHORT_SELECTION_RULE_REQUIRED')>0,'upstream failure reason survives'
say 'PASS test_cohort_quality_review'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
assertContains: procedure; use arg arr,needle,label; do x over arr; if x==needle then return; end; say 'FAIL:' label 'missing='needle; exit 1
::requires 'BrandIntervention.cls'
