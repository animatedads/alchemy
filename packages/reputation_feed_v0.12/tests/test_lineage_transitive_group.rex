now = .DateTime~new
a=.ReputationFeedArticle~new('A','A','','',now)~seal
b=.ReputationFeedArticle~new('B','B','','',now)~seal
c=.ReputationFeedArticle~new('C','C','','',now)~seal
ab=.ReputationArticleComparison~new('AB','A','B','C',95,95); ab~addParagraphComparison(.ReputationParagraphComparison~new(1,1,'C',20,98,98,98,100,100,100)); ab~addParagraphComparison(.ReputationParagraphComparison~new(2,2,'C',20,98,98,98,100,100,100)); ab~seal
bc=.ReputationArticleComparison~new('BC','B','C','C',95,95); bc~addParagraphComparison(.ReputationParagraphComparison~new(1,1,'C',20,98,98,98,100,100,100)); bc~addParagraphComparison(.ReputationParagraphComparison~new(2,2,'C',20,98,98,98,100,100,100)); bc~seal
r=.ReputationLineageEngine~new~group(.array~of(a,b,c),.array~of(ab,bc))
call assertEqual 1,r~independentSourceCount,'transitively derived variants form one lineage family'
call assertEqual 3,r~families[1]~articleCount,'family contains all variants'
say 'PASS test_lineage_transitive_group'
exit 0
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'ReputationFeed.cls'
