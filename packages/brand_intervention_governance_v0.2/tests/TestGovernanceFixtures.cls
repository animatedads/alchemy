::class GovernanceFixture public
::method study class
  use arg prefix="F", statusKind="PROMISING", assignment="OBSERVATIONAL", model="MODEL-6.4", roleGuardrail=.true, primaryAppliedOutcomes=30, primaryNotAppliedOutcomes=80, guardAppliedOutcomes=40, guardNotAppliedOutcomes=50
  eng=.BrandInterventionEffectivenessEngine~new
  t=.BrandInterventionEffectivenessThreshold~new("T-"||prefix,1000,100,100,0,0,14,1,20)
  p=.BrandInterventionEffectivenessAggregate~new(prefix||"-P","SERVICE_RECOVERY_GUIDANCE","CANCELLATION","DECREASE","PRIMARY","UNRESOLVED_SUPPORT","2026-08-01","2026-08-21",21,2000,1000,primaryAppliedOutcomes,1000,primaryNotAppliedOutcomes,86400,assignment,"OPS-ASSIGNMENT","JCLASS","JTAX","PROC-8",model)
  p~addSupportPoint("BRAND_INTERVENTION:OUTCOME:"||prefix||"P1"); p~addCounterPoint("BRAND_INTERVENTION:OUTCOME:"||prefix||"P2"); p~seal
  pa=eng~analyze(p,t)~value
  s=.BrandInterventionEffectivenessStudy~new(prefix||"-STUDY",pa)
  if roleGuardrail then do
    g=.BrandInterventionEffectivenessAggregate~new(prefix||"-G","SERVICE_RECOVERY_GUIDANCE","DISENGAGEMENT","DECREASE","GUARDRAIL","UNRESOLVED_SUPPORT","2026-08-01","2026-08-21",21,2000,1000,guardAppliedOutcomes,1000,guardNotAppliedOutcomes,86400,assignment,"OPS-ASSIGNMENT","JCLASS","JTAX","PROC-8",model)
    g~addSupportPoint("BRAND_INTERVENTION:OUTCOME:"||prefix||"G1"); g~addCounterPoint("BRAND_INTERVENTION:OUTCOME:"||prefix||"G2"); g~seal
    ga=eng~analyze(g,t)~value
    s~addGuardrail(ga)
  end
  s~addSupportPoint("BRAND_INTERVENTION:OUTCOME:"||prefix||"S1")
  s~addCounterPoint("BRAND_INTERVENTION:OUTCOME:"||prefix||"S2")
  s~seal
  return s

::method rules class
  r=.BrandInterventionGovernanceRuleSet~new; r~seal; return r

::method temporal class
  use arg current,previous,baseline,idArg="TEMP-1"
  return .BrandInterventionEffectivenessTemporalReport~new(idArg,current,previous,baseline)
::requires "BrandInterventionEffectiveness.cls"

::requires "BrandInterventionGovernance.cls"
