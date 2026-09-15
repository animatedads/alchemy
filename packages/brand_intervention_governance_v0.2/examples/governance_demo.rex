/* Synthetic demonstration only. */
eng=.BrandInterventionEffectivenessEngine~new
t=.BrandInterventionEffectivenessThreshold~new('DEMO-T',1000,100,100,0,0,14,1,20)
p=.BrandInterventionEffectivenessAggregate~new('DEMO-P','SERVICE_RECOVERY_GUIDANCE','CANCELLATION','DECREASE','PRIMARY','UNRESOLVED_SUPPORT','2026-08-01','2026-08-21',21,2000,1000,30,1000,80,86400,'OBSERVATIONAL','OPS','JCLASS','JTAX','PROC-8','MODEL-6.4'); p~seal
pa=eng~analyze(p,t)~value
g=.BrandInterventionEffectivenessAggregate~new('DEMO-G','SERVICE_RECOVERY_GUIDANCE','DISENGAGEMENT','DECREASE','GUARDRAIL','UNRESOLVED_SUPPORT','2026-08-01','2026-08-21',21,2000,1000,40,1000,50,86400,'OBSERVATIONAL','OPS','JCLASS','JTAX','PROC-8','MODEL-6.4'); g~seal
ga=eng~analyze(g,t)~value
s=.BrandInterventionEffectivenessStudy~new('DEMO-STUDY',pa); s~addGuardrail(ga); s~addSupportPoint('BRAND_INTERVENTION:OUTCOME:DEMO1'); s~addCounterPoint('BRAND_INTERVENTION:OUTCOME:DEMO2'); s~seal
b=.BrandInterventionGovernanceEvidenceBinding~new('DEMO-BINDING',s,'2026-08-24',3,'DEMO-CLOCK'); b~seal

/* Institutional Policy selects the exact reviewed governance rule-set artefact. */
rules=.BrandInterventionGovernanceRuleSet~new; rules~seal
now=.DateTime~new; start=now-.InstitutionalPolicyTime~seconds(60); finish=now+.InstitutionalPolicyTime~seconds(7200)
policy=.InstitutionalPolicyRelease~new('BRAND-INTERVENTION-GOVERNANCE','2.0',start,finish,'DEMO-AUTHOR','DEMO-APPROVER','',rules)~seal
catalog=.InstitutionalPolicyCatalog~new
ignored=catalog~publish(policy)
selection=.BrandInterventionGovernancePolicySelection~fromCatalog(catalog,'BRAND-INTERVENTION-GOVERNANCE',now)~value
r=.BrandInterventionGovernanceEngine~new~recommendUnderInstitutionalPolicy(b,selection)~value
say r~reasoningMaterial
::requires 'BrandInterventionGovernance.cls'
::requires 'InstitutionalPolicy.cls'
