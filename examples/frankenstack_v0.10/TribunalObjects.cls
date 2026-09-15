::class StructuredOfferEvidence public
::attribute evidenceId get
::attribute groupRef get
::attribute messageRef get
::attribute surname get
::attribute givenName get
::attribute serviceCode get
::attribute serviceValue get
::attribute sourcePath get
::attribute sourceKind get
::attribute sourceIdentityPreserved get
::method init
  expose evidenceId groupRef messageRef surname givenName serviceCode serviceValue sourcePath sourceKind sourceIdentityPreserved sourceObject
  use arg evidenceId,groupRef,messageRef,surname,givenName,serviceCode,serviceValue,sourcePath,sourceKind,sourceIdentityPreserved,sourceObject=.nil

::class RuntimeEvidenceObservation public
::attribute phase get
::attribute generationId get
::attribute version get
::attribute artifactId get
::attribute generationState get
::attribute locator get
::attribute capturedState get
::method init
  expose phase generationId version artifactId generationState locator capturedState sourceObject
  use arg phase,generationId,version,artifactId,generationState,locator,capturedState,sourceObject=.nil

::class LegalTimeObservation public
::attribute phase get
::attribute eventTime get
::attribute evaluationTime get
::attribute assessmentStatus get
::attribute dispositions get
::attribute legalGenerationId get
::attribute runtimeGenerationId get
::attribute note get
::method init
  expose phase eventTime evaluationTime assessmentStatus dispositions legalGenerationId runtimeGenerationId note sourceObject
  use arg phase,eventTime,evaluationTime,assessmentStatus,dispositions,legalGenerationId,runtimeGenerationId,note,sourceObject=.nil

::class RetainedDeliveryObservation public
::attribute caseId get
::attribute publicationId get
::attribute publisherRemoteCount get
::attribute retainedAtA get
::attribute consumerDepth get
::attribute consumerPayloadClass get
::attribute consumerPublisherStatus get
::attribute consumerRuntimeGeneration get
::attribute consumerLegalStatus get
::attribute receiptCount get
::attribute duplicateSuppressed get
::attribute provenancePreserved get
::method init
  expose caseId publicationId publisherRemoteCount retainedAtA consumerDepth consumerPayloadClass consumerPublisherStatus consumerRuntimeGeneration consumerLegalStatus receiptCount duplicateSuppressed provenancePreserved sourceObject
  use arg caseId,publicationId,publisherRemoteCount,retainedAtA,consumerDepth,consumerPayloadClass,consumerPublisherStatus,consumerRuntimeGeneration,consumerLegalStatus,receiptCount,duplicateSuppressed,provenancePreserved,sourceObject=.nil

::class PromotionEvidence public
::attribute promotionId get
::attribute evidenceType get
::attribute evidenceKey get
::attribute promotedMeaning get
::attribute authorityEffect get
::attribute provenance get
::method init
  expose promotionId evidenceType evidenceKey promotedMeaning authorityEffect provenance sourceObject
  use arg promotionId,evidenceType,evidenceKey,promotedMeaning,authorityEffect,provenance,sourceObject=.nil

::class ProviderInvocationStat public
::attribute providerId get
::attribute providerRef get
::method init
  expose providerId providerRef
  use arg providerId,providerRef
::method invocations
  expose providerRef
  return providerRef~invocationCount
