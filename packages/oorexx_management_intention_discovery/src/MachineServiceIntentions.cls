/* MachineServiceIntentions.cls
 * Domain-owned, read-only intention surfaces for ordinary managed machines and
 * services.  They own semantic vocabulary for their domains, but no provider
 * syntax, credentials, SSH commands, cloud commands, service-manager commands,
 * or mutable operational state.
 *
 * Authoritative objects are supplied by injected registries and preserved by
 * identity in discovery and relevance evidence.
 */

::class ManagedMachineIntentionProvider public
::method init
  use arg registry
  if registry == .nil then raise syntax 93.900 array('Managed machine registry must not be NIL')
  self~registry = registry
  self~generation = 0

::attribute registry
::attribute generation

::method providerId
  return 'managed.machine.intentions/0.1'

::method discover
  use arg context=.nil
  self~generation += 1
  machines = self~registry~discoverMachines(context)
  if machines == .nil then machines = .Array~new
  surface = .Directory~new
  surface['provider'] = self~providerId
  surface['authority'] = 'MACHINE'
  surface['subjectKinds'] = .Array~of('MACHINE')
  surface['operations'] = .Array~of('LIST_MACHINES', 'GET_MACHINE_STATE', 'EXPLAIN_MACHINE', 'GET_MACHINE_RELATIONSHIPS', 'LIST_MACHINE_SERVICES')
  surface['mutating'] = .false
  surface['generation'] = self~generation
  surface['machines'] = machines
  surface['registry'] = self~registry
  surface['context'] = context
  return surface

::method assessRelevance
  use arg request, surface, context=.nil
  text = self~normalize(request)
  matched = self~matchingObjects(text, surface['machines'])
  intentScore = self~domainScore(text)
  if matched~items = 0 & intentScore = 0 then -
    return .ManagementRelevanceAssessment~new(.false, 0, 'MACHINE', 'MACHINE_INTENTION_UNKNOWN', self~evidence(surface, matched))

  score = intentScore
  if matched~items > 0 then score = max(score, 92)
  return .ManagementRelevanceAssessment~new(.true, score, 'MACHINE', 'MACHINE_INTENTION_MATCH', self~evidence(surface, matched))

::method evidence private
  use arg surface, matched
  e = .Directory~new
  e['surface'] = surface
  e['objects'] = matched
  return e

::method matchingObjects private
  use arg text, objects
  out = .Array~new
  do object over objects
    names = self~objectNames(object)
    do name over names
      normalized = self~normalize(name)
      if normalized \== '' & pos(normalized, text) > 0 then do
        out~append(object)
        leave
      end
    end
  end
  return out

::method objectNames private
  use arg object
  names = .Array~new
  if object == .nil then return names
  if object~hasMethod('id') then names~append(object~id)
  if object~hasMethod('name') then names~append(object~name)
  if object~hasMethod('aliases') then do alias over object~aliases; names~append(alias); end
  return names

::method domainScore private
  use arg text
  score = 0
  if self~hasWord(text, 'MACHINE') | self~hasWord(text, 'MACHINES') then score = max(score, 86)
  if self~hasWord(text, 'HOST') then score = max(score, 84)
  if self~hasWord(text, 'NODE') then score = max(score, 82)
  if self~hasPhrase(text, 'WHAT MACHINES') then score = max(score, 95)
  if self~hasPhrase(text, 'LIST MACHINES') then score = max(score, 95)
  if self~hasPhrase(text, 'MACHINE STATE') then score = max(score, 94)
  if self~hasPhrase(text, 'MACHINE HEALTH') then score = max(score, 94)
  return score

::method normalize private
  use arg value
  return translate(strip(value))

::method hasWord private
  use arg text, word
  padded = ' ' || text || ' '
  return pos(' ' || word || ' ', padded) > 0

::method hasPhrase private
  use arg text, phrase
  return pos(phrase, text) > 0


::class ManagedServiceIntentionProvider public
::method init
  use arg registry
  if registry == .nil then raise syntax 93.900 array('Managed service registry must not be NIL')
  self~registry = registry
  self~generation = 0

::attribute registry
::attribute generation

::method providerId
  return 'managed.service.intentions/0.1'

::method discover
  use arg context=.nil
  self~generation += 1
  services = self~registry~discoverServices(context)
  if services == .nil then services = .Array~new
  surface = .Directory~new
  surface['provider'] = self~providerId
  surface['authority'] = 'SERVICE'
  surface['subjectKinds'] = .Array~of('SERVICE')
  surface['operations'] = .Array~of('LIST_SERVICES', 'GET_SERVICE_STATE', 'EXPLAIN_SERVICE', 'GET_SERVICE_RELATIONSHIPS')
  surface['mutating'] = .false
  surface['generation'] = self~generation
  surface['services'] = services
  surface['registry'] = self~registry
  surface['context'] = context
  return surface

::method assessRelevance
  use arg request, surface, context=.nil
  text = self~normalize(request)
  matched = self~matchingObjects(text, surface['services'])
  intentScore = self~domainScore(text)
  if matched~items = 0 & intentScore = 0 then -
    return .ManagementRelevanceAssessment~new(.false, 0, 'SERVICE', 'SERVICE_INTENTION_UNKNOWN', self~evidence(surface, matched))

  score = intentScore
  if matched~items > 0 then score = max(score, 93)
  return .ManagementRelevanceAssessment~new(.true, score, 'SERVICE', 'SERVICE_INTENTION_MATCH', self~evidence(surface, matched))

::method evidence private
  use arg surface, matched
  e = .Directory~new
  e['surface'] = surface
  e['objects'] = matched
  return e

::method matchingObjects private
  use arg text, objects
  out = .Array~new
  do object over objects
    names = self~objectNames(object)
    do name over names
      normalized = self~normalize(name)
      if normalized \== '' & pos(normalized, text) > 0 then do
        out~append(object)
        leave
      end
    end
  end
  return out

::method objectNames private
  use arg object
  names = .Array~new
  if object == .nil then return names
  if object~hasMethod('id') then names~append(object~id)
  if object~hasMethod('name') then names~append(object~name)
  if object~hasMethod('kind') then names~append(object~kind)
  if object~hasMethod('aliases') then do alias over object~aliases; names~append(alias); end
  return names

::method domainScore private
  use arg text
  score = 0
  if self~hasWord(text, 'SERVICE') | self~hasWord(text, 'SERVICES') then score = max(score, 86)
  if self~hasWord(text, 'DAEMON') then score = max(score, 84)
  if self~hasPhrase(text, 'WHAT SERVICES') then score = max(score, 95)
  if self~hasPhrase(text, 'LIST SERVICES') then score = max(score, 95)
  if self~hasPhrase(text, 'SERVICE STATE') then score = max(score, 94)
  if self~hasPhrase(text, 'SERVICE HEALTH') then score = max(score, 94)
  return score

::method normalize private
  use arg value
  return translate(strip(value))

::method hasWord private
  use arg text, word
  padded = ' ' || text || ' '
  return pos(' ' || word || ' ', padded) > 0

::method hasPhrase private
  use arg text, phrase
  return pos(phrase, text) > 0

::requires 'ManagementIntentionDiscovery.cls'
