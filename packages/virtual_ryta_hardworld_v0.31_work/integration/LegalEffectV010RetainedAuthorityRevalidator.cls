/*
 * LegalEffectV010RetainedAuthorityRevalidator.cls
 *
 * Consumer-time retained-event revalidation adapter.
 *
 * The revalidator owns the consumer-time Legal Effect evaluation.  A caller
 * supplies a Legal Effect engine object, live LegalRuntimeRuleLease, and the
 * action/context to evaluate;
 * it does NOT supply a precomputed runtime envelope.  This prevents a stale
 * publisher-era or earlier-consumer envelope from being relabelled as fresh
 * retained-delivery authority.
 *
 * The same action/context are also passed through RYTA's conservative pinned
 * evaluator.  Its canonical input snapshot supplies the consumer context
 * identity and preserves the known reducer-order refusal.  The input snapshot
 * is recomputed after the runtime-bound evaluation and must be unchanged.
 *
 * Publisher-time promotions and queue durability remain evidence only.  They
 * are never copied into the consumer authority set.
 */

::class LegalEffectV010RetainedAuthorityRevalidator public
::attribute consumerContextIdentity get
::attribute revalidatorIdentity get

::method init
  expose legalEngine legalLease action context prefix consumerContextIdentity revalidatorIdentity
  use arg legalEngineArg, legalLeaseArg, actionArg, contextArg, prefixArg = 'LEGAL_', revalidatorIdentityArg = 'RYTA/LEGAL_EFFECT_V010_RETAINED/2'
  if legalEngineArg == .nil then raise syntax 93.900 additional('LEGAL_RETAINED_ENGINE_REQUIRED')
  if \legalEngineArg~hasMethod('EVALUATE') then raise syntax 93.900 additional('LEGAL_RETAINED_ENGINE_SURFACE_INVALID')
  if legalLeaseArg == .nil then raise syntax 93.900 additional('LEGAL_RETAINED_RUNTIME_LEASE_REQUIRED')
  if actionArg == .nil then raise syntax 93.900 additional('LEGAL_RETAINED_ACTION_REQUIRED')
  if contextArg == .nil then raise syntax 93.900 additional('LEGAL_RETAINED_CONTEXT_REQUIRED')
  if revalidatorIdentityArg~string~strip = '' then raise syntax 93.900 additional('LEGAL_RETAINED_REVALIDATOR_IDENTITY_REQUIRED')
  if \legalLeaseArg~hasMethod('EVALUATE') | \legalLeaseArg~hasMethod('GENERATION') then raise syntax 93.900 additional('LEGAL_RETAINED_RUNTIME_LEASE_SURFACE_INVALID')
  legalEngine = legalEngineArg
  legalLease = legalLeaseArg
  action = actionArg
  context = contextArg
  prefix = prefixArg~string
  consumerContextIdentity = ''
  revalidatorIdentity = revalidatorIdentityArg~string

::method revalidate
  expose legalEngine legalLease action context prefix consumerContextIdentity revalidatorIdentity
  use arg package, publisherPromotionSet, world, workIdentity, attemptEvidence
  if package == .nil then return .QueueAuthorityRevalidationResult~failure('LEGAL_RETAINED_PACKAGE_REQUIRED')
  if \package~hasMethod('HEADERS') then return .QueueAuthorityRevalidationResult~failure('LEGAL_RETAINED_PACKAGE_HEADERS_REQUIRED')
  headers = package~headers
  if headers == .nil then return .QueueAuthorityRevalidationResult~failure('LEGAL_RETAINED_PACKAGE_HEADERS_REQUIRED')
  publicationId = headers~at('oqf.topic.publication_id')
  if publicationId == .nil | publicationId~string~strip = '' then return .QueueAuthorityRevalidationResult~failure('LEGAL_RETAINED_PUBLICATION_ID_REQUIRED')
  publicationId = publicationId~string

  /* First pin the exact action/context/generation and retain the reducer guard. */
  signal on syntax name pinnedFailed
  pinned = .LegalEffectV07PinnedEvaluator~evaluate(legalEngine, action, legalLease~generation, context)
  signal off syntax
  if \pinned~ok then return .QueueAuthorityRevalidationResult~failure('LEGAL_RETAINED_PINNED_EVALUATION_REFUSED', pinned~code || ':' || pinned~detail, publicationId, '', revalidatorIdentity)
  sourceObject = pinned~envelope
  consumerContextIdentity = sourceObject~inputSnapshot~contextIdentity
  actionIdentity = sourceObject~inputSnapshot~actionIdentity

  /* The authority-bearing runtime evaluation happens here, at consumption. */
  signal on syntax name liveEvaluationFailed
  evaluated = legalLease~evaluate(action, context)
  signal off syntax
  if evaluated == .nil then return .QueueAuthorityRevalidationResult~failure('LEGAL_RETAINED_LIVE_EVALUATION_REQUIRED', '', publicationId, consumerContextIdentity, revalidatorIdentity)
  if \evaluated~ok then return .QueueAuthorityRevalidationResult~failure('LEGAL_RETAINED_LIVE_EVALUATION_REFUSED', evaluated~code || ':' || evaluated~detail, publicationId, consumerContextIdentity, revalidatorIdentity)
  runtimeEnvelope = evaluated~value
  if runtimeEnvelope == .nil then return .QueueAuthorityRevalidationResult~failure('LEGAL_RETAINED_RUNTIME_ENVELOPE_REQUIRED', '', publicationId, consumerContextIdentity, revalidatorIdentity)

  /* Re-pin input after the live call: mutation/race across the boundary fails. */
  signal on syntax name postInputFailed
  postInput = .LegalEffectEvaluationInputSnapshot~new(sourceObject~generationSnapshot, action, context)
  signal off syntax
  if postInput~actionIdentity \== actionIdentity then return .QueueAuthorityRevalidationResult~failure('LEGAL_RETAINED_ACTION_CHANGED_DURING_REVALIDATION', actionIdentity || ' -> ' || postInput~actionIdentity, publicationId, consumerContextIdentity, revalidatorIdentity)
  if postInput~contextIdentity \== consumerContextIdentity then return .QueueAuthorityRevalidationResult~failure('LEGAL_RETAINED_CONTEXT_CHANGED_DURING_REVALIDATION', consumerContextIdentity || ' -> ' || postInput~contextIdentity, publicationId, consumerContextIdentity, revalidatorIdentity)

  if runtimeEnvelope~hasMethod('STATUS') then do
    if runtimeEnvelope~status~string \= sourceObject~assessment~status~string then return .QueueAuthorityRevalidationResult~failure('LEGAL_RETAINED_RUNTIME_PINNED_STATUS_MISMATCH', sourceObject~assessment~status || '<>' || runtimeEnvelope~status, publicationId, consumerContextIdentity, revalidatorIdentity)
  end

  signal on syntax name promotionFailed
  consumerSet = .LegalEffectV010PromotionAdapter~promotionsFrom(sourceObject, prefix, runtimeEnvelope)
  signal off syntax
  if consumerSet == .nil then return .QueueAuthorityRevalidationResult~failure('LEGAL_RETAINED_CONSUMER_PROMOTIONS_REQUIRED', '', publicationId, consumerContextIdentity, revalidatorIdentity)
  if \consumerSet~sealed then return .QueueAuthorityRevalidationResult~failure('LEGAL_RETAINED_CONSUMER_PROMOTIONS_NOT_SEALED', '', publicationId, consumerContextIdentity, revalidatorIdentity)

  evidence = .directory~new
  evidence['publication_id'] = publicationId
  evidence['consumer_context_identity'] = consumerContextIdentity
  evidence['consumer_action_identity'] = actionIdentity
  evidence['publisher_promotion_count'] = publisherPromotionSet~count
  evidence['consumer_promotion_count'] = consumerSet~count
  evidence['work_execution_key'] = workIdentity~executionKey
  attemptIdentity = .QueueAuthorityPromotionExecutor~attemptIdentity(attemptEvidence)
  if left(attemptIdentity, 10) = 'HASH_ERROR' then return .QueueAuthorityRevalidationResult~failure('LEGAL_RETAINED_ATTEMPT_IDENTITY_FAILED', attemptIdentity, publicationId, consumerContextIdentity, revalidatorIdentity)
  evidence['attempt_identity'] = attemptIdentity
  evidence['attempt_delivery_count'] = attemptEvidence~deliveryCount
  if runtimeEnvelope~hasMethod('STATUS') then evidence['legal_status'] = runtimeEnvelope~status
  if runtimeEnvelope~hasMethod('CREATEDAT') then evidence['legal_evaluated_at'] = runtimeEnvelope~createdAt
  if runtimeEnvelope~hasMethod('BINDINGEVIDENCE') then evidence['runtime_binding_evidence'] = runtimeEnvelope~bindingEvidence

  return .QueueAuthorityRevalidationResult~success(consumerSet, publicationId, consumerContextIdentity, revalidatorIdentity, evidence, 'fresh Legal Effect v0.10 consumer-time authority projection', '', workIdentity~executionKey, attemptIdentity)

pinnedFailed:
  signal off syntax
  failureCondition = condition('O')
  failureDetail = condition('D')
  if failureCondition \== .nil then do
    failureMessage = failureCondition['MESSAGE']
    if failureMessage \== .nil then failureDetail = failureMessage~string
  end
  return .QueueAuthorityRevalidationResult~failure('LEGAL_RETAINED_PINNED_EVALUATION_FAILED', failureDetail, publicationId, '', revalidatorIdentity)
liveEvaluationFailed:
  signal off syntax
  return .QueueAuthorityRevalidationResult~failure('LEGAL_RETAINED_LIVE_EVALUATION_FAILED', condition('D'), publicationId, consumerContextIdentity, revalidatorIdentity)
postInputFailed:
  signal off syntax
  return .QueueAuthorityRevalidationResult~failure('LEGAL_RETAINED_POST_INPUT_PIN_FAILED', condition('D'), publicationId, consumerContextIdentity, revalidatorIdentity)
promotionFailed:
  signal off syntax
  return .QueueAuthorityRevalidationResult~failure('LEGAL_RETAINED_PROMOTION_FAILED', condition('D'), publicationId, consumerContextIdentity, revalidatorIdentity)

::requires 'LegalEffectV010PromotionAdapter.cls'
::requires 'QueueFabricAuthorityExecution.cls'
