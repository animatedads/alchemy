e=.BrandInterventionEffectivenessEngine~new
t=.BrandInterventionEffectivenessThreshold~new('DEMO',1000,100,100,10,10,14,1)
p=.BrandInterventionEffectivenessAggregate~new('cancel','TONE_APPROPRIATENESS_GUIDANCE','CANCELLATION','DECREASE','PRIMARY','UNRESOLVED_SUPPORT','2026-08-01','2026-08-21',21,4000,2000,40,2000,100,86400,'OBSERVATIONAL','OPS','TONE-V7','STYLE-0.4','PROC-8','MODEL-6.4'); p~seal
g=.BrandInterventionEffectivenessAggregate~new('disengage','TONE_APPROPRIATENESS_GUIDANCE','CUSTOMER_DISENGAGEMENT','DECREASE','GUARDRAIL','UNRESOLVED_SUPPORT','2026-08-01','2026-08-21',21,4000,2000,180,2000,80,86400,'OBSERVATIONAL','OPS','TONE-V7','STYLE-0.4','PROC-8','MODEL-6.4'); g~seal
s=.BrandInterventionEffectivenessStudy~new('demo',e~analyze(p,t)~value); s~addGuardrail(e~analyze(g,t)~value); s~addConfounder('INTERVENTION_SELECTION_BIAS'); s~addCounterPoint('BRAND_INTERVENTION:OUTCOME:COUNTER-17'); s~seal
say s~reasoningMaterial
::requires 'BrandInterventionEffectiveness.cls'
