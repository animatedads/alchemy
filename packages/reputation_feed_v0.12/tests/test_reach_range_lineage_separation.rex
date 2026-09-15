now = .DateTime~new
expiry = now + .TimeSpan~new(1)

a = .ReputationFeedArticle~new('A', 'SOURCE-A', 'GROUP-ONE', 'Base', now)
sa = .ReputationPublicationSurface~new('SA', 'Glasgow title', 'GROUP-ONE', 'SCOTLAND', now)
sa~setReachEvidence(.ReputationReachEvidence~new(120000, 'PERSONS', 'AUDIT-A', now, 90, expiry))
ra = .ReputationRangeEvidence~new('RANGE-A', 90, now); ra~addGeography('SCOTLAND'); sa~setRangeEvidence(ra)
a~addSurface(sa); a~seal

b = .ReputationFeedArticle~new('B', 'SOURCE-B', 'GROUP-ONE', 'AI variant', now)
sb = .ReputationPublicationSurface~new('SB', 'Manchester title', 'GROUP-ONE', 'ENGLAND', now)
sb~setReachEvidence(.ReputationReachEvidence~new(180000, 'PERSONS', 'AUDIT-B', now, 90, expiry))
rb = .ReputationRangeEvidence~new('RANGE-B', 90, now); rb~addGeography('ENGLAND'); sb~setRangeEvidence(rb)
b~addSurface(sb); b~seal

c = .ReputationFeedArticle~new('C', 'SOURCE-C', 'GROUP-TWO', 'Independent', now)
sc = .ReputationPublicationSurface~new('SC', 'Athens title', 'GROUP-TWO', 'GR', now)
/* Deliberately no reach evidence: summary must not pretend reach is complete. */
rc = .ReputationRangeEvidence~new('RANGE-C', 85, now); rc~addGeography('GR'); sc~setRangeEvidence(rc)
c~addSurface(sc); c~seal

ab = .ReputationArticleComparison~new('AB', 'A', 'B', 'NEWS-CORPUS', 95, 95)
ab~addParagraphComparison(.ReputationParagraphComparison~new(1,1,'NEWS-CORPUS',30,96,96,95,95,95,95,100))
ab~addParagraphComparison(.ReputationParagraphComparison~new(2,2,'NEWS-CORPUS',25,97,95,96,100,95,95,100))
ab~seal
lineage = .ReputationLineageEngine~new~group(.array~of(a,b,c), .array~of(ab))
summary = .ReputationReachRangeSummary~build(.array~of(a,b,c), lineage, now)
call assertEqual 3, summary~publicationSurfaceCount, 'three publication surfaces retained'
call assertEqual 2, summary~lineageFamilyCount, 'only two independent lineage families'
call assertEqual 2, summary~validatedReachSurfaceCount, 'only validated reach evidence counted'
call assertEqual 300000, summary~grossValidatedReach, 'gross validated reach is explicit rather than independent-source count'
call assertFalse summary~reachComplete, 'missing reach evidence makes reach incomplete'
call assertTrue summary~rangeComplete, 'all three surfaces have validated range evidence'
call assertEqual 3, summary~rangeGeographies~items, 'range is geographic union, independent of lineage count'
say 'PASS test_reach_range_lineage_separation'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'ReputationFeed.cls'
