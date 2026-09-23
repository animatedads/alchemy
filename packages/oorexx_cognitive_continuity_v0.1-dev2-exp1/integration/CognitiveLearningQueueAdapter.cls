/* Queue Fabric triggered nearline learning interface.
 * This adapter expects an ObjectQueueManager-compatible manager (put/claim/ack).
 * It deliberately does not ::require Queue Fabric so the cognitive package remains
 * loadable without the optional transport package.
 */
::class CognitiveLearningRequestBuilder public
::method fromDelta class
  use strict arg deltaValue, trigger='HOURLY', budgetClass='NORMAL'
  out=.directory~new
  out['schema']=.CognitiveBuild~LEARNING_REQUEST_SCHEMA
  out['requestId']=.CognitiveUtil~makeId('learn')
  out['trigger']=trigger~string~upper
  out['scopeRef']=deltaValue['scopeRef']
  out['fromCorpusPointId']=deltaValue['fromCorpusPointId']
  out['toCorpusPointId']=deltaValue['toCorpusPointId']
  out['fromSequence']=deltaValue['fromSequence']
  out['toSequence']=deltaValue['toSequence']
  out['records']=deltaValue['records']
  out['recordCount']=deltaValue['count']
  out['budgetClass']=budgetClass
  out['requestedCapabilities']=.array~of('MULTI_LABEL_CLASSIFICATION','NEIGHBOUR_DISCOVERY','GENERALISATION','LESSON_DISCOVERY','PROCEDURE_DISCOVERY','TOOL_DISCOVERY','PROJECTION_ANALYSIS')
  out['requestedAt']=.CognitiveUtil~now
  return out

::class CognitiveLearningQueueAdapter public
::method init
  expose manager queueName producerActor workerActor
  use strict arg managerArg, queueNameArg='COGNITIVE.LEARNING', producerActorArg='cognitive:scheduler', workerActorArg='cognitive:learner'
  manager=managerArg; queueName=queueNameArg; producerActor=producerActorArg; workerActor=workerActorArg
::method enqueue
  expose manager queueName producerActor
  use strict arg request
  options=.table~new
  options['priority']=5
  if request~hasIndex('requestId') then options['correlationId']=request['requestId']
  headers=.table~new; headers['schema']=.CognitiveBuild~LEARNING_REQUEST_SCHEMA; headers['submitted-by']='cognitive-learning-adapter'; options['headers']=headers
  return manager~put(queueName,request,options,producerActor)
::method claim
  expose manager queueName workerActor
  return manager~claim(queueName,workerActor)
::method ack
  expose manager queueName workerActor
  use strict arg package
  return manager~ack(queueName,package~packageId,package~claimToken,workerActor)
::method nack
  expose manager queueName workerActor
  use strict arg package, reason='LEARNING_FAILED'
  options=.table~new; options['reason']=reason
  return manager~nack(queueName,package~packageId,package~claimToken,options,workerActor)

::class CognitiveLearningResultBuilder public
::method emptyResult class
  use strict arg request, workerId='fake-worker'
  out=.directory~new
  out['schema']=.CognitiveBuild~LEARNING_RESULT_SCHEMA
  out['requestId']=request['requestId']
  out['scopeRef']=request['scopeRef']
  out['fromCorpusPointId']=request['fromCorpusPointId']
  out['toCorpusPointId']=request['toCorpusPointId']
  out['workerId']=workerId
  out['classificationProposals']=.array~new
  out['classificationAnomalies']=.array~new
  out['conceptProposals']=.array~new
  out['lessonCandidates']=.array~new
  out['procedureCandidates']=.array~new
  out['toolCandidates']=.array~new
  out['projectionFindings']=.array~new
  out['completedAt']=.CognitiveUtil~now
  out['disposition']='PROPOSALS_ONLY_NOT_ADMITTED'
  return out
::requires 'CognitiveContinuity.cls'
