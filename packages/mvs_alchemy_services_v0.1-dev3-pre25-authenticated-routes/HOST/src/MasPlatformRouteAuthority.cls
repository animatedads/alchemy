/* MasPlatformRouteAuthority.cls
 * PRE25 authenticated remote-route authority for ConnectSelector dev8.
 * Authentication and route authority require independent LDAP identity,
 * endpoint-security and exact IdentityDirectory ACL evidence.
 */
::class MasRouteSessionProvider public
::method sessionForRoute abstract

::class MasRouteChannelAttestor public
::method attestRoute abstract

::class MasRouteResourceMap public
::method init public
  expose routes
  routes=.Table~new
::method register public
  expose routes
  use strict arg destination, provider, resourceId, action
  destination=destination~string~strip~translate
  provider=provider~string~strip~translate
  resourceId=resourceId~string~strip
  action=action~string~strip~translate
  if destination='' | provider='' | resourceId='' | action='' then raise syntax 88.900 array('MAS_ROUTE_RESOURCE_MAPPING_REQUIRED')
  key=destination||'|'||provider
  if routes~hasIndex(key) then raise syntax 88.900 array('MAS_ROUTE_RESOURCE_DUPLICATE:'||key)
  row=.Directory~new; row['resource_id']=resourceId; row['action']=action; routes[key]=row
  return self
::method resolve public
  expose routes
  use strict arg intention, provider
  key=intention~destination~string~strip~translate||'|'||provider~string~strip~translate
  if \routes~hasIndex(key) then return .nil
  return routes[key]

::class MasAuthenticatedRouteAuthority public
::method init public
  expose sessionProvider channelAttestor directory resourceMap
  use strict arg sessionProviderArg, channelAttestorArg, directoryArg, resourceMapArg
  if sessionProviderArg==.nil | \sessionProviderArg~hasMethod('sessionForRoute') then raise syntax 88.900 array('MAS_ROUTE_SESSION_PROVIDER_REQUIRED')
  if channelAttestorArg==.nil | \channelAttestorArg~hasMethod('attestRoute') then raise syntax 88.900 array('MAS_ROUTE_CHANNEL_ATTESTOR_REQUIRED')
  if directoryArg==.nil | \directoryArg~hasMethod('aclDecision') then raise syntax 88.900 array('MAS_IDENTITY_DIRECTORY_REQUIRED')
  if resourceMapArg==.nil | \resourceMapArg~hasMethod('resolve') then raise syntax 88.900 array('MAS_ROUTE_RESOURCE_MAP_REQUIRED')
  sessionProvider=sessionProviderArg; channelAttestor=channelAttestorArg; directory=directoryArg; resourceMap=resourceMapArg
::method authorizeRoute public
  expose sessionProvider channelAttestor directory resourceMap
  use strict arg intention, provider
  signal on syntax name denied
  signal on error name denied
  route=resourceMap~resolve(intention,provider)
  if route==.nil then return .false
  if channelAttestor~attestRoute(intention,provider) \== .true then return .false
  /* trusted host composition supplies this session; never derive from intention options */
  session=sessionProvider~sessionForRoute(intention,provider)
  if session==.nil then return .false
  if \session~hasMethod('authenticated') | \session~hasMethod('principalId') | \session~hasMethod('sessionId') then return .false
  if session~authenticated \== .true then return .false
  principal=session~principalId~string~strip
  if principal='' then return .false
  decision=directory~aclDecision(principal,route['resource_id'],route['action'])
  if decision==.nil | \decision~hasMethod('ok') then return .false
  return decision~ok==.true
denied:
  ignored=condition('D'); signal off syntax; signal off error; return .false

::class MasLdapHostIdentityResolver subclass MasHostIdentityResolver public
::method init public
  expose resolver
  use strict arg resolverArg
  if resolverArg==.nil | \resolverArg~hasMethod('resolveSession') then raise syntax 88.900 array('MAS_LDAP_SESSION_RESOLVER_REQUIRED')
  resolver=resolverArg
::method resolve public
  expose resolver
  use strict arg sessionId, context=.nil
  session=resolver~resolveSession(sessionId,context)
  if session==.nil then return .nil
  if \session~hasMethod('authenticated') | \session~hasMethod('principalId') | \session~hasMethod('sessionId') then return .nil
  if session~authenticated \== .true then return .nil
  principal=session~principalId~string~strip
  if principal='' then return .nil
  return .MasHostIdentity~new(principal,'LDAP_IDENTITY_DEV22','ldap-session:'||session~sessionId)

::class MasHttpsExchangeChannelAttestor subclass MasRouteChannelAttestor public
::method init public
  expose contextProvider
  use strict arg providerArg
  if providerArg==.nil | \providerArg~hasMethod('contextForRoute') then raise syntax 88.900 array('MAS_HTTPS_CONTEXT_PROVIDER_REQUIRED')
  contextProvider=providerArg
::method attestRoute public
  expose contextProvider
  use strict arg intention, provider
  context=contextProvider~contextForRoute(intention,provider)
  if context==.nil then return .false
  if \context~hasMethod('tlsProtocol') | \context~hasMethod('tlsCipher') | \context~hasMethod('tlsGeneration') | \context~hasMethod('get') then return .false
  if context~tlsProtocol~string~strip='' | context~tlsCipher~string~strip='' then return .false
  if \datatype(context~tlsGeneration,'W') | context~tlsGeneration<1 then return .false
  return context~get('mas.private_ca_verified',.false)==.true

::requires 'MasHostIdentity.cls'
::requires 'IdentityDirectory.cls'
::requires 'LdapConversation.cls'
