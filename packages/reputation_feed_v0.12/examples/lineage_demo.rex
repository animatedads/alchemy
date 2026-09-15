now=.DateTime~new
a=.ReputationFeedArticle~new('A','A','GROUP-X','Original wording',now)~seal
b=.ReputationFeedArticle~new('B','B','GROUP-X','AI rewrite',now)~seal
c=.ReputationFeedArticle~new('C','C','GROUP-Y','Independent report',now)~seal
ab=.ReputationArticleComparison~new('AB','A','B','AVIATION-CORPUS-V1',95,98)
ab~addParagraphComparison(.ReputationParagraphComparison~new(1,1,'AVIATION-CORPUS-V1',25,97,97,96,100,100,100))
ab~addParagraphComparison(.ReputationParagraphComparison~new(2,2,'AVIATION-CORPUS-V1',20,96,95,94,100,100,98))
ab~seal
lineage=.ReputationLineageEngine~new~group(.array~of(a,b,c),.array~of(ab))
say 'publication articles=3'
say 'independent lineage families=' lineage~independentSourceCount
say 'A family=' lineage~familyForArticle('A')~familyId
say 'B family=' lineage~familyForArticle('B')~familyId
say 'C family=' lineage~familyForArticle('C')~familyId
exit 0
::requires 'ReputationFeed.cls'
