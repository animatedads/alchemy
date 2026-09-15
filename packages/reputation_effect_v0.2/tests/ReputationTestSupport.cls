::class ReputationTestSupport public

::method geographyCatalog class
  catalog = .ReputationGeographyCatalog~new
  if \catalog~add(.ReputationGeography~new('WORLD', 'WORLD', '', 'World')) then raise syntax 88.900 array('duplicate geography WORLD')
  if \catalog~add(.ReputationGeography~new('EUROPE', 'REGION', 'WORLD', 'Europe')) then raise syntax 88.900 array('duplicate geography EUROPE')
  if \catalog~add(.ReputationGeography~new('GB', 'COUNTRY', 'EUROPE', 'United Kingdom')) then raise syntax 88.900 array('duplicate geography GB')
  if \catalog~add(.ReputationGeography~new('SCOTLAND', 'CONSTITUENT_COUNTRY', 'GB', 'Scotland')) then raise syntax 88.900 array('duplicate geography SCOTLAND')
  if \catalog~add(.ReputationGeography~new('GR', 'COUNTRY', 'EUROPE', 'Greece')) then raise syntax 88.900 array('duplicate geography GR')
  if \catalog~add(.ReputationGeography~new('AMERICAS', 'REGION', 'WORLD', 'Americas')) then raise syntax 88.900 array('duplicate geography AMERICAS')
  if \catalog~add(.ReputationGeography~new('AR', 'COUNTRY', 'AMERICAS', 'Argentina')) then raise syntax 88.900 array('duplicate geography AR')
  if \catalog~add(.ReputationGeography~new('US', 'COUNTRY', 'AMERICAS', 'United States')) then raise syntax 88.900 array('duplicate geography US')
  return catalog

::method conceptGraph class
  graph = .ReputationConceptGraph~new
  graph~link('EXTRA_LEGROOM', 'CABIN_SPACE')
  graph~link('FLAT_BED', 'SEAT')
  graph~link('MILE_HIGH_CLUB', 'AIRCRAFT_CABIN')
  graph~link('SEXUAL_HUMOUR', 'MILE_HIGH_CLUB')
  graph~link('AIRCRAFT_CABIN', 'PASSENGER_EJECTION')
  graph~link('CABIN_OPENING', 'DECOMPRESSION')
  graph~link('DOOR', 'CABIN_OPENING')
  graph~link('WINDOW', 'CABIN_OPENING')
  return graph

::method boeingIncident class
  use arg eventId = 'BOEING-DOOR-1', moment = .nil, harm = 'SERIOUS'
  if moment == .nil then moment = .DateTime~new
  event = .ReputationEvent~new(eventId, 'AIRCRAFT_SAFETY_INCIDENT', 'Boeing cabin opening incident', moment, moment, 90, harm, 'AVIATION')
  event~addSubject('MANUFACTURER', 'BOEING', 100)
  event~addSubject('EQUIPMENT', '737-MAX-9', 100)
  event~addConcept('CABIN_SPACE')
  event~addConcept('AIRCRAFT_CABIN')
  event~addConcept('CABIN_OPENING')
  event~addConcept('DOOR')
  event~addConcept('SEAT')
  event~addConcept('DECOMPRESSION')
  event~addConcept('PASSENGER_EJECTION')
  event~addGeographicEffect(.ReputationGeographicEffect~new(eventId, 'GB', '*', 95, 'ADVERSE', 95, moment, .nil, 'DESCENDANTS'))
  event~addGeographicEffect(.ReputationGeographicEffect~new(eventId, 'GR', '*', 20, 'ADVERSE', 85, moment, .nil, 'NONE'))
  event~addEvidence(.ReputationEvidenceAnchor~new('WIRE-1', 'NEWS', 'synthetic acceptance evidence', moment, 95))
  return event~seal

::method embarrassmentEvent class
  use arg eventId = 'BA-EMBARRASS-1', moment = .nil
  if moment == .nil then moment = .DateTime~new
  event = .ReputationEvent~new(eventId, 'OPERATIONAL_EMBARRASSMENT', 'Competitor embarrassment', moment, moment, 50, 'NONE', 'AVIATION')
  event~addSubject('ACTOR', 'BRITISH_AIRWAYS', 100)
  event~addConcept('OPERATIONAL_EMBARRASSMENT')
  event~addGeographicEffect(.ReputationGeographicEffect~new(eventId, 'GB', '*', 90, 'ADVERSE', 95, moment, .nil, 'DESCENDANTS'))
  return event~seal

::method fatalCompetitorEvent class
  use arg eventId = 'BA-FATAL-1', moment = .nil
  if moment == .nil then moment = .DateTime~new
  event = .ReputationEvent~new(eventId, 'AIRCRAFT_FATAL_INCIDENT', 'Competitor fatal incident', moment, moment, 100, 'FATAL', 'AVIATION')
  event~addSubject('ACTOR', 'BRITISH_AIRWAYS', 100)
  event~addConcept('AIRCRAFT_CABIN')
  event~addConcept('PASSENGER_EJECTION')
  event~addGeographicEffect(.ReputationGeographicEffect~new(eventId, 'GB', '*', 95, 'ADVERSE', 99, moment, .nil, 'DESCENDANTS'))
  return event~seal

::method snapshot class
  use arg snapshotId, capturedAt, lastRefresh, geographies, events = .nil
  snap = .ReputationSnapshot~new(snapshotId, capturedAt, lastRefresh)
  do geo over geographies
    snap~addCoverageGeography(geo)
  end
  if events \== .nil then do event over events
    snap~addEvent(event)
  end
  return snap


::requires 'ReputationEffect.cls'
