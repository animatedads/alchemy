/* NetworkTransportIntentions.cls
 * ooRexx Network Transport Intentions v0.1-dev1
 *
 * Read-only semantic projection over two existing authorities:
 *   - Socket Provider owns logical service -> SocketAddress/family capability.
 *   - XTP route authority owns peer routes and preferred route selection.
 *
 * This package does not acquire sockets, connect, listen, probe networks,
 * select an XTP route, mutate route tables, inspect firewalls, or execute
 * provider/OS commands.  Original SocketAddress/SocketFamily/XTPRoute and
 * domain object references are retained in observations and evidence.
 */

::class NetworkTransportIntentionsBuild public
::constant VERSION '0.1-dev1'
::constant PROVIDER_API 'network.transport.intentions/0.1'

::class NetworkTransportIntentionProvider public
::method init
  use arg socketAuthority=.nil, xtpAuthority=.nil
  self~socketAuthority = socketAuthority
  self~xtpAuthority = xtpAuthority
  self~generation = 0

::attribute socketAuthority
::attribute xtpAuthority
::attribute generation

::method providerId
  return 'network.transport.intentions/0.1'

::method discover
  use arg context=.nil
  self~generation += 1
  socketObservations = .Array~new
  xtpObservations = .Array~new
  if self~socketAuthority \== .nil then do
    socketObservations = self~socketAuthority~discoverTransportServices(context)
    if socketObservations == .nil then socketObservations = .Array~new
  end
  if self~xtpAuthority \== .nil then do
    xtpObservations = self~xtpAuthority~discoverPeerRoutes(context)
    if xtpObservations == .nil then xtpObservations = .Array~new
  end
  surface = .Directory~new
  surface['provider'] = self~providerId
  surface['authority'] = 'NETWORK_TRANSPORT'
  surface['subjectKinds'] = .Array~of('LOGICAL_SERVICE', 'SOCKET_ADDRESS', 'SOCKET_FAMILY', 'XTP_PEER', 'XTP_ROUTE')
  surface['operations'] = .Array~of('LIST_LOGICAL_SERVICES', 'GET_SERVICE_TRANSPORT', 'GET_TRANSPORT_CAPABILITIES', 'EXPLAIN_SERVICE_TRANSPORT', 'LIST_XTP_ROUTES', 'GET_XTP_BEST_ROUTE', 'EXPLAIN_XTP_ROUTE')
  surface['mutating'] = .false
  surface['generation'] = self~generation
  surface['socketObservations'] = socketObservations
  surface['xtpObservations'] = xtpObservations
  surface['context'] = context
  return surface

::method assessRelevance
  use arg request, surface, context=.nil
  text = self~normalize(request)
  matched = .Array~new
  score = self~domainScore(text)

  do observation over surface['socketObservations']
    service = observation~service
    if self~matchesObject(text, service) | self~matchesAddress(text, observation~address) then do
      self~appendUnique(matched, service)
      score = max(score, 94)
    end
  end

  do observation over surface['xtpObservations']
    peer = observation~peer
    if self~matchesObject(text, peer) then do
      self~appendUnique(matched, peer)
      score = max(score, 95)
    end
  end

  evidence = .Directory~new
  evidence['surface'] = surface
  evidence['objects'] = matched
  evidence['socketObservations'] = surface['socketObservations']
  evidence['xtpObservations'] = surface['xtpObservations']

  if score = 0 then return .ManagementRelevanceAssessment~new(.false, 0, 'NETWORK_TRANSPORT', 'NETWORK_TRANSPORT_INTENTION_UNKNOWN', evidence)
  return .ManagementRelevanceAssessment~new(.true, score, 'NETWORK_TRANSPORT', 'NETWORK_TRANSPORT_INTENTION_MATCH', evidence)

::method domainScore private
  use arg text
  score = 0
  if self~hasWord(text, 'TRANSPORT') then score = max(score, 88)
  if self~hasWord(text, 'SOCKET') | self~hasWord(text, 'SOCKETS') then score = max(score, 88)
  if self~hasWord(text, 'TCP') | self~hasWord(text, 'TLS') | self~hasWord(text, 'UNIX') then score = max(score, 90)
  if self~hasWord(text, 'XTP') then score = max(score, 94)
  if self~hasWord(text, 'MULTICAST') then score = max(score, 92)
  if self~hasWord(text, 'ROUTE') | self~hasWord(text, 'ROUTES') then score = max(score, 88)
  if self~hasPhrase(text, 'BEST ROUTE') | self~hasPhrase(text, 'PREFERRED ROUTE') then score = max(score, 96)
  if self~hasPhrase(text, 'HOW CAN') & self~hasWord(text, 'REACH') then score = max(score, 90)
  if self~hasPhrase(text, 'WHY') & self~hasWord(text, 'UDP') then score = max(score, 94)
  return score

::method matchesObject private
  use arg text, object
  if object == .nil then return .false
  names = .Array~new
  if object~hasMethod('logicalName') then names~append(object~logicalName)
  if object~hasMethod('id') then names~append(object~id)
  if object~hasMethod('name') then names~append(object~name)
  if object~hasMethod('aliases') then do alias over object~aliases; names~append(alias); end
  do name over names
    n = self~normalize(name)
    if n \== '' & pos(n, text) > 0 then return .true
  end
  return .false

::method matchesAddress private
  use arg text, address
  if address == .nil then return .false
  if pos(translate(address~transport), text) > 0 then return .true
  if address~logicalName \== '' & pos(self~normalize(address~logicalName), text) > 0 then return .true
  if address~xtpAddress \== '' & pos(self~normalize(address~xtpAddress), text) > 0 then return .true
  return .false

::method appendUnique private
  use arg array, object
  do existing over array
    if existing == object then return array
  end
  array~append(object)
  return array

::method normalize private
  use arg value
  return translate(strip(value))

::method hasWord private
  use arg text, word
  return pos(' ' || word || ' ', ' ' || text || ' ') > 0

::method hasPhrase private
  use arg text, phrase
  return pos(phrase, text) > 0

/* Registry is deliberately tiny.  The service object remains domain-owned;
 * only its logical socket name is required. */
::class NetworkLogicalServiceRegistry public
::method discoverServices abstract

/* Uses the actual SocketAddressProvider contract to resolve current addresses.
 * It never calls SocketProvider~sender/listener and therefore acquires no
 * socket and performs no I/O. */
::class SocketProviderTransportAuthority public
::method init
  use arg serviceRegistry, addressProvider
  if serviceRegistry == .nil | addressProvider == .nil then raise syntax 93.900 array('Socket transport authority requires service registry and address provider')
  self~serviceRegistry = serviceRegistry
  self~addressProvider = addressProvider
::attribute serviceRegistry
::attribute addressProvider

::method discoverTransportServices
  use arg context=.nil
  services = self~serviceRegistry~discoverServices(context)
  if services == .nil then services = .Array~new
  out = .Array~new
  do service over services
    logicalName = self~logicalNameOf(service)
    if logicalName == '' then iterate
    listener = self~addressProvider~listenerAddress(logicalName)
    if listener \== .nil then out~append(.NetworkSocketObservation~new(service, 'LISTENER', listener))
    sender = self~addressProvider~senderAddress(logicalName)
    if sender \== .nil then out~append(.NetworkSocketObservation~new(service, 'SENDER', sender))
  end
  return out

::method logicalNameOf private
  use arg service
  if service == .nil then return ''
  if service~hasMethod('logicalName') then return service~logicalName
  if service~hasMethod('name') then return service~name
  if service~hasMethod('id') then return service~id
  return ''

::class NetworkSocketObservation public
::method init
  use arg service, role, address
  self~service = service
  self~role = role
  self~address = address
  self~family = address~family
  self~capabilities = self~family~capabilities
::attribute service
::attribute role
::attribute address
::attribute family
::attribute capabilities

/* XTP authority contract.  Real adapters may bind directly to libxtp/native
 * service state.  The intention layer does not shell through the administrator command. */
::class NetworkXtpRouteAuthority public
::method discoverPeerRoutes abstract

::class NetworkXtpPeerObservation public
::method init
  use arg peer, routes, bestRoute=.nil, evidence=.nil
  if routes == .nil then routes = .Array~new
  self~peer = peer
  self~routes = routes
  self~bestRoute = bestRoute
  self~evidence = evidence
::attribute peer
::attribute routes
::attribute bestRoute
::attribute evidence

/* Domain-owned relationship projection.  Relationship kinds are published by
 * this network domain and remain opaque to Management. */
::class NetworkTransportRelationshipProvider public
::method init
  use arg intentionProvider
  if intentionProvider == .nil then raise syntax 93.900 array('Network transport relationship provider requires intention provider')
  self~intentionProvider = intentionProvider
::attribute intentionProvider

::method discoverRelationships
  use arg context=.nil
  surface = self~intentionProvider~discover(context)
  out = .Array~new
  serial = 0
  do observation over surface['socketObservations']
    if \self~hasRelationship(out, 'USES_SOCKET_ADDRESS', observation~service, observation~address) then do
      serial += 1
      out~append(.ManagementRelationship~new('socket-' || serial, 'USES_SOCKET_ADDRESS', observation~service, observation~address, 'NETWORK_TRANSPORT', observation))
    end
    if \self~hasFamilyRelationship(out, observation~address, observation~family) then do
      serial += 1
      out~append(.ManagementRelationship~new('socket-' || serial, 'USES_TRANSPORT_FAMILY', observation~address, observation~family, 'NETWORK_TRANSPORT', observation))
    end
  end
  do peerObservation over surface['xtpObservations']
    do route over peerObservation~routes
      serial += 1
      out~append(.ManagementRelationship~new('xtp-' || serial, 'HAS_XTP_ROUTE', peerObservation~peer, route, 'XTP', peerObservation~evidence))
    end
  end
  return out


::method hasFamilyRelationship private
  use arg relationships, address, family
  do relationship over relationships
    if relationship~kind \== 'USES_TRANSPORT_FAMILY' then iterate
    if relationship~fromObject \== address then iterate
    existingFamily = relationship~toObject
    if existingFamily~scheme == family~scheme & existingFamily~addressFamily == family~addressFamily then return .true
  end
  return .false

::method hasRelationship private
  use arg relationships, kind, fromObject, toObject
  do relationship over relationships
    if relationship~kind == kind & relationship~fromObject == fromObject & relationship~toObject == toObject then return .true
  end
  return .false

::requires 'ManagementIntentionDiscovery.cls'
::requires 'ManagementRelationships.cls'
::requires 'SocketProvider.cls'
::requires 'XTP.cls'
