context=.ReputationFeedAlchemyContext~new(.nil,.nil)
articleA=.ReputationFeedArticle~new('A','SRC-A','GROUP-A','Article A',.nil,context)
articleB=.ReputationFeedArticle~new('B','SRC-B','GROUP-B','Article B',.nil,context)
articleA~seal; articleB~seal
comparison=.ReputationArticleComparison~new('AB','A','B','AVIATION-CORPUS',95,95,'SRC-A',context)
comparison~addParagraphComparison(.ReputationParagraphComparison~new(1,1,'AVIATION-CORPUS',20,98,97,95,100,100,95,100,context))
comparison~addParagraphComparison(.ReputationParagraphComparison~new(2,2,'AVIATION-CORPUS',15,97,96,94,100,100,94,100,context))
comparison~seal
engine=.ReputationLineageEngine~new(context)
lineage=engine~group(.array~of(articleA,articleB),.array~of(comparison))
call assertTrue articleA~isA(.AlchemyObject),'feed article inherits AlchemyObject'
call assertTrue comparison~isA(.AlchemyObject),'comparison inherits AlchemyObject'
call assertTrue engine~isA(.AlchemyObject),'lineage engine inherits AlchemyObject'
call assertEqual 'REPUTATIONFEEDARTICLE',articleA~domainObjectKind,'feed domain kind retained'
call assertEqual 1,lineage~independentSourceCount,'lineage behaviour retained'
call assertEqual 1,engine~alchemyMetrics['use_count'],'group touches inherited telemetry'
call assertTrue articleA~checkSurfaceContract~ok,'registered Alchemy surface contract is sound'
adoption=.AlchemyAdoptionVerifier~verify(articleA,'STANDARD')
call assertTrue adoption~ok,'feed article satisfies Alchemy v0.8 STANDARD adoption'
call assertEqual '0.8', adoption~evidence['base_version'],'Alchemy base version retained in adoption evidence'
baseState=articleA~alchemyBaseState
call assertEqual '0.8',baseState['metadata']['BASE_VERSION'],'base metadata identity retained'
say 'PASS test_reputation_feed_alchemy_base base=0.8 api=' || .ReputationFeedBuild~API_VERSION
exit 0
assertTrue: procedure; use arg v,l; if v \== .true then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'ReputationFeed.cls'
::requires 'AlchemyAdoption.cls'
