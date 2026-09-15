parse arg root
if root = '' then root = directory()
files = .array~of(root || '/src/ReputationFeed.cls', root || '/src/ReputationAcquisition.cls', root || '/src/ReputationSourceAuthentication.cls', root || '/src/ReputationDecisionAudit.cls', root || '/integration/ReputationFeedQueueBridge.cls', root || '/integration/ReputationFeedQueuePersistence.cls', root || '/integration/ReputationFeedInteractionEvidence.cls', root || '/integration/ReputationFeedInteractionEventBridge.cls', root || '/integration/ReputationFeedStructuredUtteranceBridge.cls', root || '/integration/ReputationFeedInstitutionalPolicyBridge.cls', root || '/integration/ReputationFeedGovernedEffectBridge.cls', root || '/integration/ReputationFeedLoggingBridge.cls')
static = .set~new
static~put('REPUTATIONFEEDBUILD')
static~put('REPUTATIONFEEDCANONICAL')
static~put('REPUTATIONFEEDQUEUEPERSISTENCEVALUE')
static~put('REPUTATIONFEEDALCHEMYCONTEXT')
static~put('REPUTATIONFEEDALCHEMYOBJECT')
static~put('REPUTATIONFEEDQUEUECONTRACT')
static~put('REPUTATIONFEEDQUEUEPERSISTENTTYPE')
static~put('REPUTATIONFEEDQUEUEPERSISTENCESUPPORT')
checked = 0
do file over files
  stream = .stream~new(file)
  stream~open('READ')
  do while stream~state = 'READY'
    line = stream~lineIn
    stripped = line~strip
    if stripped~left(8) <> '::class ' then iterate
    parse var stripped '::class ' className rest
    className = className~word(1)~translate
    if static~hasIndex(className) then iterate
    checked += 1
    if pos('SUBCLASS REPUTATIONFEEDALCHEMYOBJECT', stripped~translate) = 0 then do
      say 'FAIL: non-static feed class does not inherit ReputationFeedAlchemyObject:' stripped
      exit 1
    end
  end
  stream~close
end
if checked < 72 then do
  say 'FAIL: inheritance gate checked too few feed classes:' checked
  exit 1
end
say 'PASS test_reputation_feed_alchemy_inheritance classes='checked
exit 0
