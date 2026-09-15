j=.BrandJourney~new("lost-bag-demo")
report=.BrandJourneyTouchpoint~new("report","SUPPORT","E:REPORT","CHAT",.nil,"OPEN","UNRESOLVED",.true,.true,.false); report~addBrandFunction("PROMOTIONAL_WORK"); report~addBrandFunction("REPUTATIONAL_WORK"); report~seal; j~addTouchpoint(report)
delivery=.BrandJourneyTouchpoint~new("delivery","DELIVERY","E:DELIVERY","DELIVERY_UPDATE",.nil,"UNRESOLVED","RESOLVED",.true,.false,.false); delivery~addBrandFunction("PROMOTIONAL_WORK"); delivery~seal; j~addTouchpoint(delivery)
h=.BrandJourneyHandoff~new("support-to-delivery","report","delivery","SUPPORT","DELIVERY","CONTEXT_CARRIED",.false,.true,1800); h~seal; j~addHandoff(h); j~seal
a=.BrandJourneyEngine~new~evaluate(j)~value
say a~canonicalText
::requires "BrandJourney.cls"
