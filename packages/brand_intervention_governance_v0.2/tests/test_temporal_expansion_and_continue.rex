/* 20% already applied, current+prior+baseline promising => bounded expansion review. */
curr=makeStudy('C',400,12,1600,120)
prev=makeStudy('P',400,14,1600,120)
base=makeStudy('B',400,15,1600,120)
t=.BrandInterventionEffectivenessTemporalReport~new('TEMP-EXP',curr,prev,base)
b=.BrandInterventionGovernanceEvidenceBinding~new('B-EXP',t,'2026-08-24',2,'CLOCK'); b~seal
rules=.BrandInterventionGovernanceRuleSet~new('R',45,25,.true,.true); rules~seal
r=.BrandInterventionGovernanceEngine~new~recommend(b,rules)~value
call assertEqual 'CONTROLLED_EXPANSION_REVIEW',r~disposition,'below cap may be reviewed for controlled expansion'
call assertTrue r~candidateExposureCapPct=25,'cap preserved'
call assertTrue r~reasoningMaterial~pos('MAINTAIN_COMPARATOR_AND_GUARDRAILS_DURING_EXPANSION')>0,'comparator retained'

/* 50% already applied: evidence may support continuing current exposure, not automatic expansion. */
curr2=.GovernanceFixture~study('C2')
prev2=.GovernanceFixture~study('P2')
base2=.GovernanceFixture~study('B2')
t2=.BrandInterventionEffectivenessTemporalReport~new('TEMP-CONT',curr2,prev2,base2)
b2=.BrandInterventionGovernanceEvidenceBinding~new('B-CONT',t2,'2026-08-24',2,'CLOCK'); b2~seal
r2=.BrandInterventionGovernanceEngine~new~recommend(b2,rules)~value
call assertEqual 'CONTINUE_CURRENT_REVIEW',r2~disposition,'at/above cap means continue-current review, not more rollout'
say 'PASS test_temporal_expansion_and_continue'
exit 0

makeStudy: procedure
  use arg prefix, applied, appliedOut, notApplied, notAppliedOut
  eng=.BrandInterventionEffectivenessEngine~new
  t=.BrandInterventionEffectivenessThreshold~new('T-'||prefix,1000,100,100,0,0,14,1,20)
  eligible=applied+notApplied
  p=.BrandInterventionEffectivenessAggregate~new(prefix||'-P','SERVICE_RECOVERY_GUIDANCE','CANCELLATION','DECREASE','PRIMARY','UNRESOLVED_SUPPORT','2026-08-01','2026-08-21',21,eligible,applied,appliedOut,notApplied,notAppliedOut,86400,'OBSERVATIONAL','OPS','J','T','P','MODEL-6.4'); p~seal
  pa=eng~analyze(p,t)~value
  /* Guardrail has the same favourable direction in this synthetic fixture. */
  g=.BrandInterventionEffectivenessAggregate~new(prefix||'-G','SERVICE_RECOVERY_GUIDANCE','DISENGAGEMENT','DECREASE','GUARDRAIL','UNRESOLVED_SUPPORT','2026-08-01','2026-08-21',21,eligible,applied,appliedOut,notApplied,notAppliedOut,86400,'OBSERVATIONAL','OPS','J','T','P','MODEL-6.4'); g~seal
  ga=eng~analyze(g,t)~value
  s=.BrandInterventionEffectivenessStudy~new(prefix||'-S',pa); s~addGuardrail(ga); s~seal
  return s

assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'TestGovernanceFixtures.cls'
::requires 'BrandInterventionGovernance.cls'
