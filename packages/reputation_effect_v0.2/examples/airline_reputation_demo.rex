now = .DateTime~new
eventTime = now - .TimeSpan~new(0, 0, 2, 0, 0)

catalog = .ReputationGeographyCatalog~new
catalog~add(.ReputationGeography~new('WORLD','WORLD'))
catalog~add(.ReputationGeography~new('EUROPE','REGION','WORLD'))
catalog~add(.ReputationGeography~new('GB','COUNTRY','EUROPE','United Kingdom'))
catalog~add(.ReputationGeography~new('SCOTLAND','CONSTITUENT_COUNTRY','GB','Scotland'))
catalog~add(.ReputationGeography~new('GR','COUNTRY','EUROPE','Greece'))

graph = .ReputationConceptGraph~new
graph~link('EXTRA_LEGROOM','CABIN_SPACE')
graph~link('MILE_HIGH_CLUB','AIRCRAFT_CABIN')
graph~link('AIRCRAFT_CABIN','PASSENGER_EJECTION')

event = .ReputationEvent~new('DEMO-DOOR','AIRCRAFT_SAFETY_INCIDENT','Synthetic cabin opening incident',eventTime,eventTime,90,'SERIOUS','AVIATION')
event~addSubject('MANUFACTURER','BOEING',100)
event~addSubject('EQUIPMENT','737-MAX-9',100)
event~addConcept('CABIN_SPACE')
event~addConcept('AIRCRAFT_CABIN')
event~addConcept('PASSENGER_EJECTION')
event~addGeographicEffect(.ReputationGeographicEffect~new('DEMO-DOOR','GB','*',95,'ADVERSE',95,eventTime,.nil,'DESCENDANTS'))
event~addGeographicEffect(.ReputationGeographicEffect~new('DEMO-DOOR','GR','*',20,'ADVERSE',85,eventTime,.nil,'NONE'))
event~seal

snapshot = .ReputationSnapshot~new('DEMO-SNAPSHOT',now,now)
snapshot~addCoverageGeography('GB')
snapshot~addCoverageGeography('GR')
snapshot~addEvent(event)
snapshot~seal

ourLady = .ReputationActionSurface~new('OLA-LEGROOM','OURLADYAIR','ADVERTISING',now,'NORMAL')
ourLady~addGeography('SCOTLAND')
ourLady~addGeography('GR')
ourLady~addAudience('GENERAL_PUBLIC')
ourLady~addAssociation('MANUFACTURER','BOEING',90)
ourLady~addAssociation('EQUIPMENT','737-MAX-9',100)
ourLady~addConcept('EXTRA_LEGROOM')
ourLady~seal

flyLo = .ReputationActionSurface~new('FLYLO-LEGROOM','FLYLO','ADVERTISING',now,'NORMAL')
flyLo~addGeography('SCOTLAND')
flyLo~addAudience('GENERAL_PUBLIC')
flyLo~addAssociation('MANUFACTURER','AIRBUS',100)
flyLo~addAssociation('EQUIPMENT','A320',100)
flyLo~addAssociation('SECTOR','AVIATION',25)
flyLo~addConcept('EXTRA_LEGROOM')
flyLo~seal

engine = .ReputationEngine~new
call showDecision 'OurLadyAir', engine~evaluate(ourLady,snapshot,catalog,graph)~value
call showDecision 'FlyLo', engine~evaluate(flyLo,snapshot,catalog,graph)~value
exit 0

showDecision: procedure
  use arg label, decision
  say label 'overall='decision~overallDisposition
  do geoDecision over decision~geographicDecisions
    say '  'geoDecision~geographyId '=>' geoDecision~disposition 'maxConcern='geoDecision~maximumConcernSeverity
    do item over geoDecision~items
      say '     'item~itemKind item~code 'severity='item~severity
    end
  end
  return

::requires 'ReputationEffect.cls'
