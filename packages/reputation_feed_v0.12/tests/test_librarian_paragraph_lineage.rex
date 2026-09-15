now = .DateTime~new
/* Three publication surfaces; A and B are AI-reworded variants of the same underlying article. */
a = .ReputationFeedArticle~new('A', 'SOURCE-A', 'GROUP-ONE', 'Door incident report', now)
a~addSurface(.ReputationPublicationSurface~new('SURF-A', 'Masthead A', 'GROUP-ONE', 'GB', now))
a~seal
b = .ReputationFeedArticle~new('B', 'SOURCE-B', 'GROUP-ONE', 'Rewritten door incident report', now)
b~addSurface(.ReputationPublicationSurface~new('SURF-B', 'Masthead B', 'GROUP-ONE', 'GB-SCT', now))
b~seal
c = .ReputationFeedArticle~new('C', 'SOURCE-C', 'GROUP-TWO', 'Independent witness report', now)
c~addSurface(.ReputationPublicationSurface~new('SURF-C', 'Masthead C', 'GROUP-TWO', 'GR', now))
c~seal

ab = .ReputationArticleComparison~new('AB', 'A', 'B', 'AVIATION-CORPUS-V1', 94, 96, 'SOURCE-A')
/* Low lexical similarity, high semantic/claim/entity/fact alignment: same article, different words. */
ab~addParagraphComparison(.ReputationParagraphComparison~new(1, 1, 'AVIATION-CORPUS-V1', 28, 97, 96, 95, 100, 95, 100, 98))
ab~addParagraphComparison(.ReputationParagraphComparison~new(2, 2, 'AVIATION-CORPUS-V1', 22, 95, 94, 93, 100, 100, 98, 98))
ab~addParagraphComparison(.ReputationParagraphComparison~new(3, 3, 'AVIATION-CORPUS-V1', 31, 96, 97, 94, 95, 100, 97, 98))
ab~seal

ac = .ReputationArticleComparison~new('AC', 'A', 'C', 'AVIATION-CORPUS-V1', 30, 10)
ac~addParagraphComparison(.ReputationParagraphComparison~new(1, 2, 'AVIATION-CORPUS-V1', 20, 45, 20, 35, 0, 20, 25, 90))
ac~addParagraphComparison(.ReputationParagraphComparison~new(2, 4, 'AVIATION-CORPUS-V1', 15, 35, 15, 30, 0, 15, 20, 90))
ac~seal

lineage = .ReputationLineageEngine~new~group(.array~of(a,b,c), .array~of(ab,ac))
call assertEqual 2, lineage~independentSourceCount, 'AI-reworded A/B collapse to one lineage family while C remains independent'
call assertTrue lineage~familyForArticle('A') == lineage~familyForArticle('B'), 'A and B grouped'
call assertFalse lineage~familyForArticle('A') == lineage~familyForArticle('C'), 'C not grouped with A'
call assertTrue ab~articleScore >= 78, 'paragraph/corpus evidence clears lineage cut despite low lexical match'
say 'PASS test_librarian_paragraph_lineage'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'ReputationFeed.cls'
