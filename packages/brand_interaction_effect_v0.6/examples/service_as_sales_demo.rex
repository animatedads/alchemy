o=.BrandInteractionObservation~new('support','support-1','AGENT_UTTERANCE','INTERACTION_EVENT:support-1','CHAT','OUTBOUND')
o~addTag('BRAND_FUNCTION/BRAND_ENGAGEMENT'); o~addTag('BRAND_FUNCTION/PROMOTIONAL_WORK'); o~addTag('BRAND_FUNCTION/REPUTATIONAL_WORK'); o~addTag('BRAND_FUNCTION/COMMERCIAL_RELATIONSHIP_WORK'); o~addTag('NO_EXPLICIT_SALES_PROPOSITION'); o~addPurpose('SERVICE_RESOLUTION'); o~seal
ep=.BrandInteractionEpisode~new('demo-service'); ep~addObservation(o); ep~seal
d=.BrandInteractionEngine~new~evaluate(ep)~value
say .BrandInteractionExplainer~concise(d)
say .BrandInteractionExplainer~informal(d)
::requires 'BrandInteractionEffect.cls'
