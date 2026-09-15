a=.BrandInteractionObservation~new('reply','reply','AGENT_UTTERANCE','INTERACTION_EVENT:reply','CHAT','OUTBOUND'); a~putDimension('SASS',84); a~putDimension('ABRUPTNESS',93); a~putDimension('DISMISSIVENESS',90); a~putDimension('CLOSURE_STRENGTH',95); a~seal
x=.BrandInteractionObservation~new('cancel','cancel','SUBSCRIPTION_CANCELLED','INTERACTION_EVENT:cancel','BILLING','INBOUND'); x~seal
ep=.BrandInteractionEpisode~new('demo-sass'); ep~addObservation(a); ep~addObservation(x); ep~seal
d=.BrandInteractionEngine~new~evaluate(ep)~value
say .BrandInteractionExplainer~concise(d)
say .BrandInteractionExplainer~informal(d)
say 'causal='d~hypotheses[1]~causalStatus
::requires 'BrandInteractionEffect.cls'
