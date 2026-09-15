parse arg root port host sampleFile capabilityV1 capabilityV2 queueRootA queueRootB
if root = '' then root = '/tmp/frankenstack_v10_db'
if port = '' then port = 3498
if host = '' then host = '127.0.0.1'
if sampleFile = '' then raise syntax 93.900 additional('sampleFile required')
if queueRootA = '' then queueRootA = root || '/qm_a'
if queueRootB = '' then queueRootB = root || '/qm_b'

say 'FRANKENSTACK V0.10 RETAINED AUTHORITY TIME BOMB START'
fed = .FederatedDatabaseEngine~new(root)

/* ------------------------------------------------------------------
 * Structured Relation v0.9: real OurLadyAir G07 PNRGOV evidence.
 * The fixture deliberately has an INVALID outer envelope; we retain
 * that fact instead of laundering it away.  G07 itself carries three
 * NSST assertions and passenger identities.
 * ------------------------------------------------------------------ */
doc = .EdiFactDocumentContext~new(sampleFile)
envelopeReport = doc~validateEnvelope
if doc~groups~items <> 7 then raise syntax 93.900 additional('expected seven PNRGOV groups')
if envelopeReport~status <> 'INVALID' then raise syntax 93.900 additional('fixture outer envelope must remain honestly INVALID')
ediProvider = .EdiFactRelationProvider~new(.DatabaseResult)
ssr = ediProvider~defineRelation('pnr_ssr', doc, 'SEGMENT:SSR')
ssr~columnMap('group_ref','@groupReference')
ssr~columnMap('message_ref','@messageReference')
ssr~columnMap('service_code','1/1')
ssr~columnMap('service_status','1/2')
ssr~columnMap('flight','1/5')
ssr~columnMap('flight_date','1/6')
ssr~columnMap('service_value','2')
pax = ediProvider~defineRelation('pnr_passengers', doc, 'SEGMENT:TIF')
pax~columnMap('group_ref','@groupReference')
pax~columnMap('message_ref','@messageReference')
pax~columnMap('surname','1')
pax~columnMap('given_name','2')
pax~columnMap('title','3')
pax~columnMap('passenger_type','4')
pax~columnMap('dob','5')
ignore = fed~addEngine(ediProvider)

paxByMessage = .table~new
do row over ediProvider~table('pnr_passengers')~readRows
  if row['group_ref'] = 'G07' then paxByMessage[row['message_ref']] = row
end
structuredRows = .array~new
nsstFacts = .array~new
do row over ediProvider~table('pnr_ssr')~readRows
  if row['group_ref'] <> 'G07' then iterate
  if row['service_code'] <> 'NSST' then iterate
  fact = row~fact('service_code')
  if fact == .nil then raise syntax 93.900 additional('G07 NSST rich fact missing')
  sourceObj = row~sourceFor('service_code')
  if fact~source \== sourceObj then raise syntax 93.900 additional('G07 fact source identity lost')
  if fact~sourceDocument \== doc then raise syntax 93.900 additional('G07 fact document identity lost')
  pRow = paxByMessage[row['message_ref']]
  if pRow == .nil then raise syntax 93.900 additional('G07 passenger missing for message ' || row['message_ref'])
  sourceKind = fact~source~class~id
  nsstFacts~append(fact)
  structuredRows~append(.StructuredOfferEvidence~new('G07-' || row['message_ref'],row['group_ref'],row['message_ref'],pRow['surname'],pRow['given_name'],row['service_code'],row['service_value'],fact~sourcePath,sourceKind,.true,fact))
end
if structuredRows~items <> 3 then raise syntax 93.900 additional('expected three G07 NSST facts')
seatOfferTotal = structuredRows~items * 20
if seatOfferTotal <> 60 then raise syntax 93.900 additional('seat offer total')
structuredMap = .ObjectTableMapping~new('structured_offer_evidence')
structuredMap~column('evidence_id','VARCHAR','evidenceId')
structuredMap~column('group_ref','VARCHAR','groupRef')
structuredMap~column('message_ref','VARCHAR','messageRef')
structuredMap~column('surname','VARCHAR','surname')
structuredMap~column('given_name','VARCHAR','givenName')
structuredMap~column('service_code','VARCHAR','serviceCode')
structuredMap~column('service_value','VARCHAR','serviceValue')
structuredMap~column('source_path','VARCHAR','sourcePath')
structuredMap~column('source_kind','VARCHAR','sourceKind')
structuredMap~column('source_identity_preserved','BOOLEAN','sourceIdentityPreserved')
if \fed~registerSnapshot('structured_offer_evidence',structuredRows,structuredMap) then raise syntax 93.900 additional('structured evidence snapshot failed')

/* ------------------------------------------------------------------
 * Runtime Registry v0.11: capture publisher generation evidence, then
 * activate a newer consumer-time capability.  Detached evidence from
 * v1 remains a truthful historical snapshot; it is not current authority.
 * ------------------------------------------------------------------ */
verifier = .RuntimePinnedSourceVerifier~new
kernel = .RuntimeKernel~new(verifier)
load1 = .RuntimeSourceLoader~readFile(capabilityV1)
if \load1~ok then raise syntax 93.900 additional('load capability v1')
load2 = .RuntimeSourceLoader~readFile(capabilityV2)
if \load2~ok then raise syntax 93.900 additional('load capability v2')
lines1 = load1~value; lines2 = load2~value
ignore = verifier~pin('fixture:seat-offer:v1',lines1)
ignore = verifier~pin('fixture:seat-offer:v2',lines2)
artifact1 = .RuntimeArtifact~new('ourladyair.seat.offer','CAPABILITY','1.0.0','fixture:seat-offer:v1','SeatOfferCapability',lines1,'seat.offer/0.1')
artifact2 = .RuntimeArtifact~new('ourladyair.seat.offer','CAPABILITY','2.0.0','fixture:seat-offer:v2','SeatOfferCapability',lines2,'seat.offer/0.1')
staged1 = kernel~stage('prod',artifact1); call mustOk staged1,'stage publisher capability'
activated1 = kernel~activate('prod',artifact1~moduleId,staged1~value~generationId); call mustOk activated1,'activate publisher capability'
acq1 = kernel~acquire('prod',artifact1~moduleId); call mustOk acq1,'acquire publisher capability'
publisherLease = acq1~value
publisherEvidence = publisherLease~executionEvidence
if publisherEvidence == .nil then raise syntax 93.900 additional('publisher execution evidence missing')
if publisherEvidence~generationState <> 'ACTIVE' then raise syntax 93.900 additional('publisher evidence not ACTIVE')

/* ------------------------------------------------------------------
 * Legal Effect v0.7: synthetic law only.  Same sealed rule generation:
 * publisher event before 2026-08-21 is ADMISSIBLE; consumer event after
 * the cutover is BLOCKED.  This is test law, not real legal advice.
 * ------------------------------------------------------------------ */
legalSource = .NormativeSource~new('SYN-RETAINED-SEAT-LAW','LEGISLATION','Synthetic retained seat offer rule','SYNTHETIC','GB')
legalScope = .LegalTemporalScope~new('2026-08-21','2026-08-21','','2026-08-21','')
legalNorm = .LegalNorm~new('SEAT-RET-1',legalSource~sourceId,'1','PROHIBITION','OFFER_RETAINED_SEAT','PROHIBITED','CONSUMER','Synthetic test rule: retained seat upsell prohibited from cutover',legalScope)
legalGeneration = .LegalRuleGeneration~new('SEAT-LEGAL-G1','0.7-synthetic')
ignore = legalGeneration~addSource(legalSource)
ignore = legalGeneration~addNorm(legalNorm)
ignore = legalGeneration~seal
if \legalGeneration~sealed then raise syntax 93.900 additional('synthetic legal generation not sealed')
legalAction = .LegalAction~new('OFFER_RETAINED_SEAT','Offer retained G07 seat-together product')
publisherContext = .LegalContext~new('PUBLISH-G07','2026-08-20','2026-08-20')
publisherEval = .LegalEffectEngine~new~evaluate(legalAction,legalGeneration,publisherContext)
if \publisherEval~ok then raise syntax 93.900 additional('publisher legal evaluation failed')
publisherAssessment = publisherEval~value
if publisherAssessment~status <> 'ADMISSIBLE' then raise syntax 93.900 additional('publisher should be ADMISSIBLE')

/* Build queue-persistable payload from rich source facts without pretending
 * the flattened copy is the source itself.  The exact rich facts remain in
 * structured_offer_evidence; this envelope carries stable locators/identity. */
payload = .directory~new
payload['offer_id'] = 'G07-SEAT-TOGETHER-60'
payload['group_ref'] = 'G07'
payload['passenger_count'] = structuredRows~items
payload['unit_eur'] = 20
payload['total_eur'] = seatOfferTotal
payload['publisher_legal_status'] = publisherAssessment~status
payload['publisher_event_time'] = '2026-08-20'
payload['publisher_runtime_generation'] = publisherEvidence~generationId
payload['publisher_runtime_artifact'] = publisherEvidence~artifactId
payload['source_envelope_status'] = envelopeReport~status
payload['source_paths'] = .array~of(nsstFacts[1]~sourcePath,nsstFacts[2]~sourcePath,nsstFacts[3]~sourcePath)
payload['passengers'] = .array~of(structuredRows[1]~surname,structuredRows[2]~surname,structuredRows[3]~surname)
registryEnvelope = publisherLease~envelope(payload,'edifact://ourladyair/G07/SSR:NSST')
if registryEnvelope == .nil then raise syntax 93.900 additional('registry evidence envelope missing')

/* ------------------------------------------------------------------
 * Queue Fabric v0.8.1: durable retained publication on A while B has no
 * interest.  Restart A.  Later B subscribes after legal/runtime cutover;
 * A hands off exactly one retained publication.  B restarts and durable
 * receipt suppresses a duplicate logical remote publication.
 * ------------------------------------------------------------------ */
transport = .QueueInProcessTransport~new
codecA = .QueueGraphPayloadCodec~new; ignore = .QueueDistributedTopicSupport~registerTypes(codecA)
codecB = .QueueGraphPayloadCodec~new; ignore = .QueueDistributedTopicSupport~registerTypes(codecB)
managerA = .ObjectQueueManager~new(queueRootA,codecA,'admin')
managerB = .ObjectQueueManager~new(queueRootB,codecB,'admin')
call makePermanent managerA,.array~of('XMIT.B','DT.CTRL','DT.PUB','DT.DIST')
call makePermanent managerB,.array~of('XMIT.A','DT.CTRL','DT.PUB','DT.DIST','B.OFFER')
call mustQueue managerA~grant('DT.CTRL','wire-a',.QueueAccess~PUT,'admin'),'grant A control'
call mustQueue managerA~grant('DT.PUB','wire-a',.QueueAccess~PUT,'admin'),'grant A pub'
call mustQueue managerB~grant('DT.CTRL','wire-b',.QueueAccess~PUT,'admin'),'grant B control'
call mustQueue managerB~grant('DT.PUB','wire-b',.QueueAccess~PUT,'admin'),'grant B pub'
channelsA = .QueueChannelFabric~new('QM.A',managerA,transport,'admin')
channelsB = .QueueChannelFabric~new('QM.B',managerB,transport,'admin')
ignore = transport~registerEndpoint('QM.A',channelsA); ignore = transport~registerEndpoint('QM.B',channelsB)
call permanentLink channelsA,'A.TO.B','XMIT.B','QM.B','wire-b'
call permanentReceiver channelsB,'A.TO.B','QM.A','wire-b'
call permanentLink channelsB,'B.TO.A','XMIT.A','QM.A','wire-a'
call permanentReceiver channelsA,'B.TO.A','QM.B','wire-a'
call permanentAlias channelsA,'B.CTRL','DT.CTRL','QM.B','XMIT.B','A.TO.B'
call permanentAlias channelsA,'B.PUB','DT.PUB','QM.B','XMIT.B','A.TO.B'
call permanentAlias channelsB,'A.CTRL','DT.CTRL','QM.A','XMIT.A','B.TO.A'
call permanentAlias channelsB,'A.PUB','DT.PUB','QM.A','XMIT.A','B.TO.A'
topicsA = .QueueTopicFabric~new(managerA,'admin')
topicsB = .QueueTopicFabric~new(managerB,'admin')
call mustQueue topicsA~defineTopic('SEAT.OFFERS','seat/offers','PERMANENT','TOPIC','admin'),'define A topic'
call mustQueue topicsB~defineTopic('SEAT.OFFERS','seat/offers','PERMANENT','TOPIC','admin'),'define B topic'
call mustQueue topicsA~grantTopicAccess('SEAT.OFFERS','producer',.QueueTopicAccess~PUBLISH,'admin'),'grant publisher'
remoteA = .QueueDistributedTopicFabric~new('QM.A',managerA,topicsA,channelsA,'DT.CTRL','DT.PUB','DT.DIST','admin')
remoteB = .QueueDistributedTopicFabric~new('QM.B',managerB,topicsB,channelsB,'DT.CTRL','DT.PUB','DT.DIST','admin')
call mustQueue remoteA~definePeer('QM.B','SEAT.OFFERS','SEAT.OFFERS','B.CTRL','B.PUB','PERMANENT',.false,'admin'),'define A peer'
call mustQueue remoteB~definePeer('QM.A','SEAT.OFFERS','SEAT.OFFERS','A.CTRL','A.PUB','PERMANENT',.false,'admin'),'define B peer'

options = .table~new
options['subtopic']='g07/seat-together'; options['persistent']=.true; options['retain']=.true
options['securityDomain']='TOPIC'; options['correlationId']='G07-SEAT-TOGETHER-60'
publishResult = topicsA~publish('SEAT.OFFERS',payload,options,'producer')
call mustQueue publishResult,'publish retained offer before remote interest'
pubReceipt = publishResult~value
if pubReceipt~remoteManagerCount <> 0 then raise syntax 93.900 additional('retained offer unexpectedly remotely delivered at publisher time')
if topicsA~retainedPublications~items <> 1 then raise syntax 93.900 additional('A retained state missing')
publicationId = pubReceipt~publicationId

/* Runtime cutover after publication. */
staged2 = kernel~stage('prod',artifact2); call mustOk staged2,'stage consumer capability'
activated2 = kernel~activate('prod',artifact2~moduleId,staged2~value~generationId); call mustOk activated2,'activate consumer capability'
publisherLiveAfterCutover = publisherLease~executionEvidence
if publisherLiveAfterCutover~generationState <> 'DRAINING' then raise syntax 93.900 additional('publisher live lease should be DRAINING after cutover')
if publisherEvidence~generationState <> 'ACTIVE' then raise syntax 93.900 additional('detached publisher evidence mutated after cutover')
acq2 = kernel~acquire('prod',artifact2~moduleId); call mustOk acq2,'acquire consumer capability'
consumerLease = acq2~value
consumerEvidence = consumerLease~executionEvidence
if consumerEvidence~generationState <> 'ACTIVE' then raise syntax 93.900 additional('consumer runtime not ACTIVE')

consumerContext = .LegalContext~new('CONSUME-G07','2026-08-22','2026-08-22')
consumerEval = .LegalEffectEngine~new~evaluate(legalAction,legalGeneration,consumerContext)
if \consumerEval~ok then raise syntax 93.900 additional('consumer legal evaluation failed')
consumerAssessment = consumerEval~value
if consumerAssessment~status <> 'BLOCKED' then raise syntax 93.900 additional('consumer should be BLOCKED after cutover')

/* Restart A before B interest: the retained payload and peer definitions
 * must recover from Queue Fabric durable state. */
codecA2 = .QueueGraphPayloadCodec~new; ignore = .QueueDistributedTopicSupport~registerTypes(codecA2)
managerA2 = .ObjectQueueManager~new(queueRootA,codecA2,'admin')
channelsA2 = .QueueChannelFabric~new('QM.A',managerA2,transport,'admin')
topicsA2 = .QueueTopicFabric~new(managerA2,'admin')
remoteA2 = .QueueDistributedTopicFabric~new('QM.A',managerA2,topicsA2,channelsA2,'DT.CTRL','DT.PUB','DT.DIST','admin')
ignore = transport~registerEndpoint('QM.A',channelsA2)
if topicsA2~retainedPublications~items <> 1 then raise syntax 93.900 additional('A restart lost retained publication')
if topicsA2~retainedPublications[1]~publicationId <> publicationId then raise syntax 93.900 additional('A restart changed publication identity')
if topicsA2~retainedPublications[1]~payload['publisher_runtime_generation'] <> publisherEvidence~generationId then raise syntax 93.900 additional('A restart lost publisher runtime provenance')

/* B becomes interested only now, after the legal/runtime cutover. */
call mustQueue topicsB~subscribe('B.G07.SUB','SEAT.OFFERS','g07/#','B.OFFER','PERMANENT','admin'),'subscribe B after retain/cutover'
call mustQueue remoteB~syncPeer('QM.A','SEAT.OFFERS','admin'),'B advertises late interest'
call mustQueue channelsB~pump('B.TO.A',0,'admin'),'send B late interest'
call mustQueue remoteA2~pumpControlIngress(0,'admin'),'A applies late interest'
if managerA2~depth('DT.DIST','admin')~value['ready'] <> 1 then raise syntax 93.900 additional('late interest did not stage retained handoff')
call mustQueue remoteA2~pumpDistribution(0,'admin'),'stage retained handoff'
call mustQueue channelsA2~pump('A.TO.B',0,'admin'),'transmit retained handoff'
call mustQueue remoteB~pumpPublicationIngress(0,'admin'),'B commits retained handoff'
if managerB~depth('B.OFFER','admin')~value['ready'] <> 1 then raise syntax 93.900 additional('B did not receive exactly one retained offer')
receivedPackage = managerB~browse('B.OFFER','admin')~value
receivedPayload = receivedPackage~payload
if receivedPayload['publisher_legal_status'] <> 'ADMISSIBLE' then raise syntax 93.900 additional('publisher legal provenance lost')
if receivedPayload['publisher_runtime_generation'] <> publisherEvidence~generationId then raise syntax 93.900 additional('publisher generation provenance lost at B')
if receivedPayload['source_paths'][1] <> nsstFacts[1]~sourcePath then raise syntax 93.900 additional('source path provenance lost at B')
if remoteB~receipts~items <> 1 then raise syntax 93.900 additional('B durable distributed receipt missing')

/* Restart B and reinject same logical remote publication. Durable receipt
 * must suppress a second local fan-out. */
codecB2 = .QueueGraphPayloadCodec~new; ignore = .QueueDistributedTopicSupport~registerTypes(codecB2)
managerB2 = .ObjectQueueManager~new(queueRootB,codecB2,'admin')
channelsB2 = .QueueChannelFabric~new('QM.B',managerB2,transport,'admin')
topicsB2 = .QueueTopicFabric~new(managerB2,'admin')
remoteB2 = .QueueDistributedTopicFabric~new('QM.B',managerB2,topicsB2,channelsB2,'DT.CTRL','DT.PUB','DT.DIST','admin')
ignore = transport~registerEndpoint('QM.B',channelsB2)
if managerB2~depth('B.OFFER','admin')~value['ready'] <> 1 then raise syntax 93.900 additional('B restart lost subscriber delivery')
if remoteB2~receipts~items <> 1 then raise syntax 93.900 additional('B restart lost distributed receipt')
duplicate = .QueueRemoteTopicPublication~new('QM.A',publicationId,'QM.A','QM.B','SEAT.OFFERS','SEAT.OFFERS','g07/seat-together',payload,.table~new,0,.true,'TOPIC','G07-SEAT-TOGETHER-60','',0,.true,.array~of('QM.A'))
dupOptions=.table~new; dupOptions['persistent']=.true; dupOptions['securityDomain']='TOPIC'
call mustQueue managerB2~put('DT.PUB',duplicate,dupOptions,'admin'),'queue duplicate remote publication'
call mustQueue remoteB2~pumpPublicationIngress(0,'admin'),'suppress duplicate by durable receipt'
if managerB2~depth('B.OFFER','admin')~value['ready'] <> 1 then raise syntax 93.900 additional('duplicate created second subscriber delivery')
if remoteB2~receipts~items <> 1 then raise syntax 93.900 additional('duplicate created second receipt')

/* ------------------------------------------------------------------
 * Freeze execution/runtime/legal/queue evidence into NoSQLServer v0.74.
 * ------------------------------------------------------------------ */
runtimeRows=.array~new
runtimeRows~append(.RuntimeEvidenceObservation~new('PUBLISH_CAPTURED',publisherEvidence~generationId,'1.0.0',publisherEvidence~artifactId,publisherEvidence~generationState,registryEnvelope~locator,'DETACHED_ACTIVE',publisherEvidence))
runtimeRows~append(.RuntimeEvidenceObservation~new('PUBLISH_LIVE_AFTER_CUTOVER',publisherLiveAfterCutover~generationId,'1.0.0',publisherLiveAfterCutover~artifactId,publisherLiveAfterCutover~generationState,'','DRAINING',publisherLiveAfterCutover))
runtimeRows~append(.RuntimeEvidenceObservation~new('CONSUMER_CURRENT',consumerEvidence~generationId,'2.0.0',consumerEvidence~artifactId,consumerEvidence~generationState,'','ACTIVE',consumerEvidence))
runtimeMap=.ObjectTableMapping~new('runtime_execution_evidence')
runtimeMap~column('phase','VARCHAR','phase'); runtimeMap~column('generation_id','VARCHAR','generationId'); runtimeMap~column('version','VARCHAR','version'); runtimeMap~column('artifact_id','VARCHAR','artifactId'); runtimeMap~column('generation_state','VARCHAR','generationState'); runtimeMap~column('locator','VARCHAR','locator'); runtimeMap~column('captured_state','VARCHAR','capturedState')
if \fed~registerSnapshot('runtime_execution_evidence',runtimeRows,runtimeMap) then raise syntax 93.900 additional('runtime evidence snapshot failed')

legalRows=.array~new
legalRows~append(.LegalTimeObservation~new('PUBLISHER_TIME','2026-08-20','2026-08-20',publisherAssessment~status,summarizeDispositions(publisherAssessment~dispositions),legalGeneration~generationId,publisherEvidence~generationId,'legal admissibility at publication is evidence, not a permanent capability token',publisherAssessment))
legalRows~append(.LegalTimeObservation~new('CONSUMER_TIME','2026-08-22','2026-08-22',consumerAssessment~status,summarizeDispositions(consumerAssessment~dispositions),legalGeneration~generationId,consumerEvidence~generationId,'same sealed legal generation blocks the action after the synthetic cutover',consumerAssessment))
legalMap=.ObjectTableMapping~new('legal_time_assessments')
legalMap~column('phase','VARCHAR','phase'); legalMap~column('event_time','VARCHAR','eventTime'); legalMap~column('evaluation_time','VARCHAR','evaluationTime'); legalMap~column('assessment_status','VARCHAR','assessmentStatus'); legalMap~column('dispositions','VARCHAR','dispositions'); legalMap~column('legal_generation_id','VARCHAR','legalGenerationId'); legalMap~column('runtime_generation_id','VARCHAR','runtimeGenerationId'); legalMap~column('note','VARCHAR','note')
if \fed~registerSnapshot('legal_time_assessments',legalRows,legalMap) then raise syntax 93.900 additional('legal snapshot failed')

deliveryRows=.array~of(.RetainedDeliveryObservation~new('G07-RETAINED-TIME-BOMB',publicationId,pubReceipt~remoteManagerCount,topicsA2~retainedPublications~items,managerB2~depth('B.OFFER','admin')~value['ready'],receivedPayload~class~id,receivedPayload['publisher_legal_status'],consumerEvidence~generationId,consumerAssessment~status,remoteB2~receipts~items,.true,.true,receivedPayload))
deliveryMap=.ObjectTableMapping~new('retained_authority_case')
deliveryMap~column('case_id','VARCHAR','caseId'); deliveryMap~column('publication_id','VARCHAR','publicationId'); deliveryMap~column('publisher_remote_count','INTEGER','publisherRemoteCount'); deliveryMap~column('retained_at_a','INTEGER','retainedAtA'); deliveryMap~column('consumer_depth','INTEGER','consumerDepth'); deliveryMap~column('consumer_payload_class','VARCHAR','consumerPayloadClass'); deliveryMap~column('publisher_legal_status','VARCHAR','consumerPublisherStatus'); deliveryMap~column('consumer_runtime_generation','VARCHAR','consumerRuntimeGeneration'); deliveryMap~column('consumer_legal_status','VARCHAR','consumerLegalStatus'); deliveryMap~column('receipt_count','INTEGER','receiptCount'); deliveryMap~column('duplicate_suppressed','BOOLEAN','duplicateSuppressed'); deliveryMap~column('provenance_preserved','BOOLEAN','provenancePreserved')
if \fed~registerSnapshot('retained_authority_case',deliveryRows,deliveryMap) then raise syntax 93.900 additional('delivery snapshot failed')

promotions=.array~new
promotions~append(.PromotionEvidence~new('PROMO-LEGAL-PUBLISH','LEGAL_EFFECT',publisherAssessment~status,'PUBLISHER_TIME_ADMISSIBILITY','EVIDENCE_ONLY','publisher event was admissible under synthetic law at 2026-08-20; not transferable authority',publisherAssessment))
promotions~append(.PromotionEvidence~new('PROMO-QUEUE-RETAIN','QUEUE_FABRIC','RETAINED_AND_RECEIPTED','DURABLE_TRANSPORT_PROVENANCE','EVIDENCE_ONLY','queue proves durable retained handoff and duplicate suppression; it does not grant business authority',remoteB2))
promotions~append(.PromotionEvidence~new('PROMO-RUNTIME','RUNTIME_REGISTRY',publisherEvidence~generationId,'HISTORICAL_EXECUTION_GENERATION','EVIDENCE_ONLY','detached publisher evidence remains historically truthful while v2 is current',publisherEvidence))
promotions~append(.PromotionEvidence~new('PROMO-LEGAL-CONSUME','LEGAL_EFFECT',consumerAssessment~status,'CONSUMER_TIME_ACTION_BLOCKED','PROHIBIT_ACTION','consumer-time evaluation after synthetic cutover controls actionability',consumerAssessment))
promotions~append(.PromotionEvidence~new('PROMO-STRUCTURED','STRUCTURED_RELATION','G07_NSST_X3','SOURCE_PROVENANCE_PRESERVED','REQUIRE_PRESERVATION','three native EDIFACT facts retain exact source document and paths',nsstFacts[1]))
promoMap=.ObjectTableMapping~new('retained_authority_promotions')
promoMap~column('promotion_id','VARCHAR','promotionId'); promoMap~column('evidence_type','VARCHAR','evidenceType'); promoMap~column('evidence_key','VARCHAR','evidenceKey'); promoMap~column('promoted_meaning','VARCHAR','promotedMeaning'); promoMap~column('authority_effect','VARCHAR','authorityEffect'); promoMap~column('provenance','VARCHAR','provenance')
if \fed~registerSnapshot('retained_authority_promotions',promotions,promoMap) then raise syntax 93.900 additional('promotion snapshot failed')

/* Queue Fabric's own read-only NoSQL projections, separately prefixed. */
qa=.QueueDistributedTopicNoSQLAdapter~new(remoteA2,.nil,'mqa_')
qb=.QueueDistributedTopicNoSQLAdapter~new(remoteB2,.nil,'mqb_')
if \qa~snapshotInto(fed,'admin') then raise syntax 93.900 additional('A queue NoSQL projection failed')
if \qb~snapshotInto(fed,'admin') then raise syntax 93.900 additional('B queue NoSQL projection failed')

/* ------------------------------------------------------------------
 * HardWorld v0.19: large preference scores cannot convert publisher-time
 * admissibility or queue delivery into consumer-time authority.
 * ------------------------------------------------------------------ */
actionSchema=.AlgorithmSchema~new('TABLE_FEED_SOURCE')
actionSchema~add('ROW_ID','TEXT',.false); actionSchema~add('LABEL','TEXT',.false); actionSchema~add('PREFERENCE_SCORE','NUMBER',.false)
actionSchema~addEnum('UPSTREAM_DISPOSITION','TEXT',.false,.array~of('UNRESOLVED','PERMITTED','REQUIRED','SUPPRESSED','PROHIBITED','REQUIRES_APPROVAL'))
actionBuilder=.AlgorithmInputRelationBuilder~new(actionSchema)
call addAction actionBuilder,'ACT_ON_RETAINED_OFFER','Execute the retained G07 seat offer at consumer time',9000000,'PROHIBITED'
call addAction actionBuilder,'TRUST_PUBLISHER_TIME_APPROVAL','Treat publisher-time ADMISSIBLE as permanently transferable authority',8000000,'PROHIBITED'
call addAction actionBuilder,'TREAT_QUEUE_DELIVERY_AS_AUTHORITY','Treat durable queue delivery/receipt as business authority',7000000,'PROHIBITED'
call addAction actionBuilder,'RE_EVALUATE_AT_CONSUMER','Re-evaluate legal/business authority when retained event becomes actionable',-1000000,'REQUIRED'
call addAction actionBuilder,'PRESERVE_SOURCE_PROVENANCE','Keep the native EDIFACT provenance attached to the business evidence',-500000,'REQUIRED'
call addAction actionBuilder,'SUPPRESS_RETAINED_OFFER','Suppress the stale retained offer after consumer-time block',-1000,'REQUIRED'
consistency=.AlgorithmInputConsistencyDescriptor~new(.AlgorithmInputConsistencyConstant~FROZEN_OBSERVATION,5,'','',.array~of('STRUCTURED_SOURCE','QUEUE_RECEIPT','RUNTIME_EVIDENCE','LEGAL_EFFECT','PROMOTION_POLICY'))
tribunalInput=actionBuilder~freeze('INCIDENT-RETAINED-AUTHORITY-V10','Retained event preserves provenance but not permanent authority','FRANKENSTACK-V10',consistency)
tribunalProvider=.TableFeedDecisionProvider~new(directory('..'),.AlgorithmInputConsistencyConstant~FROZEN_OBSERVATION)
tribunalEngine=.AlgorithmRelationEngine~new
if \tribunalEngine~addProvider(tribunalProvider) then raise syntax 93.900 additional('HardWorld provider registration failed')
tribunalContext=.AlgorithmExecutionContext~new('INCIDENT-RETAINED-AUTHORITY-HARDWORLD-V10',tribunalInput~sourceOid)
tribunalResult=tribunalEngine~execute('TABLE_FEED_DECIDER',tribunalInput,tribunalContext)
if tribunalResult == .nil then raise syntax 93.900 additional('HardWorld decision failed')
tribunalAdapter=.NoSQLServerAlgorithmRelationAdapter~new(fed,tribunalEngine,.ObjectTableMapping)
bindings=.directory~new; bindings['TABLE_FEED_DECISIONS']='retained_authority_decisions'; bindings['TABLE_FEED_TRACE']='retained_authority_trace'
if tribunalAdapter~registerMaterializedSet(tribunalResult,bindings)==.nil then raise syntax 93.900 additional('HardWorld relation registration failed')
stats=.array~of(.ProviderInvocationStat~new('TRIBUNAL',tribunalProvider))
statsMap=.ObjectTableMapping~new('algrel_provider_stats'); statsMap~column('provider_id','VARCHAR','providerId'); statsMap~column('invocations','INTEGER','invocations')
if \fed~register('algrel_provider_stats',stats,statsMap) then raise syntax 93.900 additional('provider stats registration failed')

ignore=publisherLease~release; ignore=consumerLease~release; ignore=kernel~collectRetired
sql=.NoSQLServerSQL~new(fed)
say '  structured_plugin=0.9 outer_envelope=' || envelopeReport~status || ' g07_nsst=' || structuredRows~items || ' offer_eur=' || seatOfferTotal
say '  publisher_runtime=' || publisherEvidence~generationId || ' captured_state=' || publisherEvidence~generationState || ' live_after_cutover=' || publisherLiveAfterCutover~generationState
say '  consumer_runtime=' || consumerEvidence~generationId || ' state=' || consumerEvidence~generationState
say '  legal_publish=' || publisherAssessment~status || ' legal_consume=' || consumerAssessment~status
say '  retained_publication=' || publicationId || ' publisher_remote_count=' || pubReceipt~remoteManagerCount || ' receipt_count=' || remoteB2~receipts~items || ' duplicate_suppressed=1'
q=sql~execute("SELECT row_id,preference_score,disposition,final_selected,reason FROM retained_authority_decisions ORDER BY row_id")
call requireSuccess q,'decision query'
do rr over q~rows
  say '  HARDWORLD ' || rr['row_id'] || ' score=' || rr['preference_score'] || ' -> ' || rr['disposition'] || ' selected=' || rr['final_selected'] || ' reason=' || rr['reason']
end
say '  tribunal_provider_invocations=' || tribunalProvider~invocationCount
say 'FRANKENSTACK V0.10 FEDERATION READY tables=' || fed~readCatalog['tables']~items
say 'FRANKENSTACK V0.10 WIRE READY host=' || host || ' port=' || port
server=.MySQLWireServer~new(root,host,port); server~engine=fed; server~serve
exit 0

makePermanent: procedure
  use arg manager,names
  do name over names
    call mustQueue manager~createQueue(name,'PERMANENT','TOPIC',100,'admin'),'create permanent ' || name
  end
  return
permanentLink: procedure
  use arg fabric,channelName,xmitQueue,remoteManager,remotePrincipal
  call mustQueue fabric~defineSenderChannel(channelName,xmitQueue,remoteManager,channelName,'admin',remotePrincipal,3,'PERMANENT','admin'),'define sender ' || channelName
  call mustQueue fabric~startSenderChannel(channelName,'admin'),'start sender ' || channelName
  return
permanentReceiver: procedure
  use arg fabric,channelName,sourceManager,inboundPrincipal
  call mustQueue fabric~defineReceiverChannel(channelName,sourceManager,inboundPrincipal,'PERMANENT','admin'),'define receiver ' || channelName
  call mustQueue fabric~startReceiverChannel(channelName,'admin'),'start receiver ' || channelName
  return
permanentAlias: procedure
  use arg fabric,aliasName,remoteQueue,remoteManager,xmitQueue,channelName
  call mustQueue fabric~defineRemoteQueue(aliasName,remoteQueue,remoteManager,xmitQueue,channelName,'TOPIC','PERMANENT','admin','admin'),'define alias ' || aliasName
  return
mustQueue: procedure
  use arg operationResult,label
  if \operationResult~ok then raise syntax 93.900 additional(label || ': ' || operationResult~code || ' ' || operationResult~detail)
  return
mustOk: procedure
  use arg operationResult,label
  if \operationResult~ok then raise syntax 93.900 additional(label || ': ' || operationResult~code || ' ' || operationResult~detail)
  return
summarizeDispositions: procedure
  use arg arr
  out=''
  do item over arr
    if out<>'' then out||=','
    out||=item~string
  end
  return out
addAction: procedure
  use arg builder,rowId,label,score,disposition
  values=.directory~new; values['ROW_ID']=rowId; values['LABEL']=label; values['PREFERENCE_SCORE']=score; values['UPSTREAM_DISPOSITION']=disposition
  if \builder~addValues(values) then raise syntax 93.900 additional('unable to add action ' || rowId)
  return
requireSuccess: procedure
  use arg rs,label
  if rs~status \= .Error~SUCCESS then raise syntax 93.900 additional(label || ': ' || rs~error || ' ' || rs~message)
  return

::requires 'src/MySQLWireServer.cls'
::requires 'EdiFactRelationAdapter.cls'
::requires 'ObjectQueueDistributedTopicNoSQL.cls'
::requires 'RuntimeRegistry.cls'
::requires 'LegalEffect.cls'
::requires 'TribunalObjects.cls'
::requires '../integration/NoSQLServerAlgorithmRelationAdapter.cls'
::requires '../algorithm/TableFeedDecisionProvider.cls'
