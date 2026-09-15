now=.DateTime~new
news=.ReputationSourceIdentity~new('NEWS-GLA','NEWS','Glasgow Daily','GROUP-A','OWNER-A','GB-SCT','EDITORIAL_REPORTING','news-feed')~seal
newsEnvelope=.ReputationRawEnvelope~new('ENV-NEWS-1',news,now,now,'TEXT/HTML','https://example.invalid/news/1','EN','sha256:news')
newsEnvelope~addField('TITLE','Cabin incident reported')
newsEnvelope~addField('OBSERVED_GEOGRAPHY','GB-SCT')
newsEnvelope~addField('SURFACE_ID','SURFACE-GLA')
newsEnvelope~addSegment('HEADLINE','Cabin incident reported')
newsEnvelope~addSegment('BODY','Operator says an aircraft returned safely after a cabin event.')
newsEnvelope~addSegment('BODY','Regulator has been informed.')
newsEnvelope~seal

official=.ReputationSourceIdentity~new('REG-AA','REGULATOR','Air Accident Office','','','GB','OFFICIAL_NOTICE','official-feed')~seal
officialEnvelope=.ReputationRawEnvelope~new('ENV-OFFICIAL-1',official,now,now,'APPLICATION/XML','https://example.invalid/notice/1','EN','sha256:official')
officialEnvelope~addField('TITLE','Investigation opened')
officialEnvelope~addSegment('TITLE','Investigation opened')
officialEnvelope~addSegment('BODY','An investigation has been opened. Cause has not been determined.')
officialEnvelope~seal

social=.ReputationSourceIdentity~new('PUBLIC-FIREHOSE','PUBLIC_STREAM','Public Stream','','','WORLD','DISCOVERY','jetstream-like')~seal
socialEnvelope=.ReputationRawEnvelope~new('ENV-SOCIAL-1',social,now,now,'APPLICATION/JSON','at://example/post/1','EN','sha256:social')
socialEnvelope~addSegment('POST','Something happened near the airport; looking for confirmation.')
socialEnvelope~seal

router=.ReputationAcquisitionRouter~new
router~registerAdapter(.ReputationOfficialNoticeAdapter~new)
router~registerAdapter(.ReputationNewsPublicationAdapter~new)
router~registerAdapter(.ReputationPublicStreamAdapter~new)
call assertEqual 3,router~adapterCount,'router has three materially different source-class adapters'

newsResult=router~adapt(newsEnvelope)
call assertTrue newsResult~accepted,'news accepted'
call assertEqual 'NEWS-PUBLICATION',newsResult~adapterId,'news adapter selected'
call assertEqual 'NEWS_ARTICLE',newsResult~document~documentKind,'news document kind'
call assertEqual 3,newsResult~librarianHandoff~paragraphCount,'news paragraph structure retained for Librarian'
call assertEqual 'NEWS_LINEAGE',newsResult~librarianHandoff~corpora[1],'news custom corpus requested'
call assertTrue newsResult~feedArticle \== .nil,'news adapter creates publication-lineage article'
call assertEqual 1,newsResult~feedArticle~surfaces~items,'news publication surface retained'
call assertTrue newsResult~feedArticle~surfaces[1]~reachEvidence == .nil,'adapter does not invent reach evidence'
call assertTrue newsResult~feedArticle~surfaces[1]~rangeEvidence == .nil,'adapter does not invent range evidence'

noticeResult=router~adapt(officialEnvelope)
call assertTrue noticeResult~accepted,'official notice accepted'
call assertEqual 'OFFICIAL-NOTICE',noticeResult~adapterId,'official adapter selected'
call assertEqual 'OFFICIAL_NOTICE',noticeResult~document~documentKind,'official document kind'
call assertEqual 'OFFICIAL_NOTICES',noticeResult~librarianHandoff~corpora[1],'official corpus retained'
call assertTrue noticeResult~feedArticle == .nil,'official source does not masquerade as independent publication article'
call assertEqual 'OFFICIAL_NOTICE',official~evidentialRole,'official role is descriptive evidence only'

socialResult=router~adapt(socialEnvelope)
call assertTrue socialResult~accepted,'public stream accepted'
call assertEqual 'PUBLIC-STREAM',socialResult~adapterId,'stream adapter selected'
call assertEqual 'PUBLIC_POST',socialResult~document~documentKind,'stream document kind'
call assertEqual 'PUBLIC_STREAM',socialResult~librarianHandoff~corpora[1],'public stream corpus retained'
call assertTrue socialResult~feedArticle == .nil,'public post does not become a news article automatically'

unknown=.ReputationSourceIdentity~new('UNKNOWN','SENSOR','Unknown sensor','','','GB','DISCOVERY','sensor')~seal
unknownEnvelope=.ReputationRawEnvelope~new('ENV-UNKNOWN',unknown,now,now)
unknownEnvelope~addSegment('BODY','opaque')
unknownEnvelope~seal
unknownResult=router~adapt(unknownEnvelope)
call assertTrue \unknownResult~accepted,'unsupported source rejected'
call assertEqual 'NO_ADAPTER',unknownResult~status,'unsupported source explicitly reports no adapter'

say 'PASS test_acquisition_adapter_diversity api=' .ReputationFeedBuild~API_VERSION
exit 0
assertTrue: procedure; use arg v,l; if v \== .true then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'ReputationAcquisition.cls'
