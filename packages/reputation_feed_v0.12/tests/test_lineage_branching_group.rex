now=.DateTime~new
a=.ReputationFeedArticle~new('A','A','','',now)~seal
b=.ReputationFeedArticle~new('B','B','','',now)~seal
c=.ReputationFeedArticle~new('C','C','','',now)~seal
ab=.ReputationArticleComparison~new('AB','A','B','C',95,95)
ab~addParagraphComparison(.ReputationParagraphComparison~new(1,1,'C',20,98,98,98,100,100,100)); ab~addParagraphComparison(.ReputationParagraphComparison~new(2,2,'C',20,98,98,98,100,100,100)); ab~seal
ac=.ReputationArticleComparison~new('AC','A','C','C',95,95)
ac~addParagraphComparison(.ReputationParagraphComparison~new(1,1,'C',20,98,98,98,100,100,100)); ac~addParagraphComparison(.ReputationParagraphComparison~new(2,2,'C',20,98,98,98,100,100,100)); ac~seal
r=.ReputationLineageEngine~new~group(.array~of(a,b,c),.array~of(ab,ac))
call assertEqual 1,r~independentSourceCount,'branching lineage remains one connected component'
call assertEqual 3,r~families[1]~articleCount,'branching queue visits both siblings'
say 'PASS test_lineage_branching_group'
exit 0
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'ReputationFeed.cls'
