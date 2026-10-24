/* Optional Intention Service dev11 adapter. The core never parses language.
 * This adapter registers project-specific candidate decisions; Intention
 * Service owns UNKNOWN/CLARIFY/CONFIRM/READY, and only READY dispatch mutates
 * architectural choices. Re-register on a fresh service when questions change.
 */
::requires 'ArchitecturePlanner.cls'
::requires 'IntentionService.cls'
::requires 'IntentionProviders.cls'

::class ArchitectureIntentionChoiceEvent public
::method init
  expose engine project principal questionId choiceId
  use strict arg engine, project, principal, questionId, choiceId

::method invoke
  expose engine project principal questionId choiceId
  use strict arg decision
  if decision~status \== 'READY' then -
    raise syntax 93.900 array('ARCH_INTENTION_NOT_READY')
  q = engine~catalog~questionAt(questionId)
  if engine~active(q, project) == .false then -
    raise syntax 93.900 array('ARCH_INTENTION_STALE_QUESTION')
  return project~answer(questionId, choiceId, -
    'Explicitly confirmed architecture intention', principal, -
    'Intention Service READY: 'decision~input)

::class ArchitectureIntentionAdapter public
::method registerOpenChoices
  use strict arg service, engine, project, principal
  registered = .Array~new
  service~registerBucket('ARCHITECTURE', -
    .IntentionBucketPolicy~new('EXPLICIT', 75, 8, .true, .false))
  plan = engine~plan(project)
  do question over plan['openQuestions']
    do option over question['options']
      phrase = 'select 'option['id']' for 'question['id']
      event = .ArchitectureIntentionChoiceEvent~new(engine, project, -
        principal, question['id'], option['id'])
      registration = service~register(phrase, event, 'ARCHITECTURE')
      registered~append(registration)
    end
  end
  return registered
