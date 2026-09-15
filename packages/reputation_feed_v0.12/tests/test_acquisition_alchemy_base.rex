context=.ReputationFeedAlchemyContext~new(.nil,.nil)
now=.DateTime~new
source=.ReputationSourceIdentity~new('REG-1','REGULATOR','Regulator','','','GB','OFFICIAL_NOTICE','endpoint',context)~seal
envelope=.ReputationRawEnvelope~new('ENV-1',source,now,now,'TEXT/XML','https://example.invalid/official','EN','sha256:test',context)
envelope~addField('TITLE','Notice'); envelope~addSegment('BODY','Investigation opened; cause not yet established.'); envelope~seal
adapter=.ReputationOfficialNoticeAdapter~new(context)
acquired=adapter~adapt(envelope)
call assertTrue source~isA(.AlchemyObject),'source identity inherits AlchemyObject'
call assertTrue envelope~isA(.AlchemyObject),'raw envelope inherits AlchemyObject'
call assertTrue acquired~document~isA(.AlchemyObject),'acquired document inherits AlchemyObject'
call assertTrue acquired~librarianHandoff~isA(.AlchemyObject),'Librarian handoff inherits AlchemyObject'
call assertEqual 1,adapter~alchemyMetrics['use_count'],'adapter use counted'
objects=.array~of(source,envelope,acquired~document,acquired~librarianHandoff)
do object over objects
  adoption=.AlchemyAdoptionVerifier~verify(object,'STANDARD')
  call assertTrue adoption~ok,'adapter-created object satisfies Alchemy v0.8 STANDARD adoption'
  call assertEqual '0.8', adoption~evidence['base_version'],'house base identity retained'
end
call assertEqual 'REG-1',source~sourceId,'source identity retained'
call assertEqual 'REGULATOR',source~sourceKind,'source kind retained'
call assertEqual 'OFFICIAL_NOTICE',source~evidentialRole,'descriptive evidential role retained'
say 'PASS test_acquisition_alchemy_base base=0.8 api=' || .ReputationFeedBuild~API_VERSION
exit 0
assertTrue: procedure; use arg v,l; if v \== .true then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'ReputationAcquisition.cls'
::requires 'AlchemyAdoption.cls'
