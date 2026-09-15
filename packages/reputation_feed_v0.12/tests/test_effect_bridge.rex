now = .DateTime~new
article = .ReputationFeedArticle~new('A', 'SOURCE-A', 'GROUP-ONE', 'Synthetic article', now)
article~addSurface(.ReputationPublicationSurface~new('SURF-A', 'Masthead A', 'GROUP-ONE', 'GB', now))
article~seal
family = .ReputationArticleFamily~new('FAMILY-1'); family~addArticle(article)
obs = .ReputationFeedEffectBridge~new~observationFromArticle('OBS-1', 'EVENT-1', article, family, 'GB', 'SCOTLAND', now, 80, 'CORROBORATING', 'synthetic bridge')
call assertEqual 'GB', obs~observedGeographyId, 'observed geography retained'
call assertEqual 'SCOTLAND', obs~affectedGeographyId, 'affected geography remains distinct'
meta = obs~sourceAnchor~metadata
call assertEqual 'FAMILY-1', meta['lineage_family'], 'lineage family retained in effect evidence metadata'
call assertEqual '1', meta['family_article_count'], 'family article count retained'
say 'PASS test_effect_bridge'
exit 0
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'ReputationFeedEffectBridge.cls'
