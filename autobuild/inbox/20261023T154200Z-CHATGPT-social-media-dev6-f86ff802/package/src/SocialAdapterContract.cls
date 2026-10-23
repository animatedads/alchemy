/* Social Media v0.1-dev6: protocol provider adapter boundary.
 * This is NO vendor network implementation. Existing SocialPublicationService
 * remains the sole outbound authority/outbox path; the adapter has no grant.
 */

::class SocialAdapter public
::method id abstract
::method capabilities abstract
::method discoverScoped abstract
::method dispatch abstract
::method verifyInbound abstract
::method verifyRemote abstract

/* Registry does not infer any provider capability from a platform name. */
::class SocialAdapterRegistry public
::method adapters attribute
::method init
  expose adapters
  adapters = .directory~new
::method register
  expose adapters
  use strict arg adapter
  if adapter == .nil then raise syntax 93.900 array ('Adapter required')
  if \adapter~isA(.SocialAdapter) then raise syntax 93.900 array ('Invalid social adapter')
  name = adapter~id
  if name == '' then raise syntax 93.900 array ('Adapter provider ID missing')
  if adapters~hasIndex(name) then raise syntax 93.900 array ('Duplicate provider adapter')
  adapters[name] = adapter
  return self
::method find
  expose adapters
  use strict arg providerId
  if \adapters~hasIndex(providerId) then return .nil
  return adapters[providerId]

/* Live adapters must actively establish the exact account/surface capability
 * for each new publication request; cache policy is their responsibility.
 * Even a valid capability is never sufficient to authorize dispatch. */
::class SocialAdapterScopedResolver public subclass SocialScopedCapabilityResolver
::method registry attribute
::method init
  expose registry
  use strict arg registry
  if registry == .nil then raise syntax 93.900 array ('Adapter registry required')
::method resolve
  expose registry
  use strict arg request
  adapter = registry~find(request~surface~providerId)
  if adapter == .nil then return .nil
  offer = adapter~discoverScoped(request)
  if offer == .nil then return .nil
  if \offer~isA(.SocialScopedCapability) then raise syntax 93.900 array ('Adapter returned invalid scoped capability')
  return offer

/* The platform's provider-wide operations are ADVERTISED ONLY by an adapter;
 * actual authorisation, scoped capability and policy remain in SocialPublication.
 * The caller must register this wrapper on SocialLibrary and expose only the
 * SocialScopedPublicationService to applications.
 */
::class SocialAdapterProvider public subclass SocialProvider
::method adapter attribute
::method init
  expose adapter
  use strict arg adapter
  if adapter == .nil then raise syntax 93.900 array ('Adapter required')
  if \adapter~isA(.SocialAdapter) then raise syntax 93.900 array ('Invalid adapter provider')
::method id
  expose adapter
  return adapter~id
::method capabilities
  expose adapter
  return adapter~capabilities
::method perform
  expose adapter
  use strict arg action, context
  if \context~isA(.directory) then raise syntax 93.900 array ('Publication context must be Directory')
  do key over 'requestId providerId accountId surfaceKey action'~makearray(' ')
    if \context~hasIndex(key) then raise syntax 93.900 array ('Adapter context incomplete')
    if context[key] == '' then raise syntax 93.900 array ('Adapter context value missing')
  end
  if context['providerId'] <> adapter~id then raise syntax 93.900 array ('Adapter provider mismatch')
  if context['action'] <> action then raise syntax 93.900 array ('Adapter operation mismatch')
  /* No interpretation of remote acknowledgement as delivery here. */
  return adapter~dispatch(action, context)

/* The existing inbound gate calls verify(event) before graph inclusion.
 * A live adapter must authenticate provider-originating events against its
 * owned raw-envelope evidence, replay policy and account binding. It MUST NOT
 * blindly trust mutable interaction metadata or platform ID strings. */
::class SocialAdapterInboundVerifier public
::method registry attribute
::method init
  expose registry
  use strict arg registry
::method verify
  expose registry
  use strict arg interaction
  adapter = registry~find(interaction~target~surface~providerId)
  if adapter == .nil then return .false
  return adapter~verifyInbound(interaction) == .true

/* Reconciliation authority is separate from network acknowledgements; the
 * adapter verifies remote evidence about the original ticket, not a loose ID. */
::class SocialAdapterDeliveryVerifier public
::method registry attribute
::method init
  expose registry
  use strict arg registry
::method verify
  expose registry
  use strict arg ticket, status, evidence
  adapter = registry~find(ticket~providerId)
  if adapter == .nil then return .false
  if evidence == '' then return .false
  return adapter~verifyRemote(ticket, status, evidence) == .true

/* Inert reference adapter for local qualification. No HTTP, credentials,
 * event authentication, remote reconciliation or spend. It cannot be used
 * as proof of real platform permissions or real delivery. */
::class SocialTestAdapter public subclass SocialAdapter
::method providerId attribute
::method offers attribute
::method operations attribute
::method init
  expose providerId offers operations
  use strict arg providerId
  if providerId == '' then raise syntax 93.900 array ('Test provider required')
  offers = .directory~new
  operations = .array~new
::method id
  expose providerId
  return providerId
::method capabilities
  caps = .directory~new
  caps['publish'] = .SocialCapability~new('publish',.true)
  caps['reply'] = .SocialCapability~new('reply',.true)
  return caps
::method scopedKey private
  use strict arg account, surface, action
  return length(account) || ':' || account || length(surface) || ':' || surface || length(action) || ':' || action
::method permit
  expose providerId offers
  use strict arg capability
  if capability~providerId <> providerId then raise syntax 93.900 array ('Test offer provider mismatch')
  key = self~scopedKey(capability~accountId,capability~surfaceKey,capability~action)
  offers[key] = capability
  return self
::method revoke
  expose offers
  use strict arg capability
  key = self~scopedKey(capability~accountId,capability~surfaceKey,capability~action)
  if offers~hasIndex(key) then offers~remove(key)
  return self
::method discoverScoped
  expose offers
  use strict arg request
  key = self~scopedKey(request~accountId,request~surface~key,request~action)
  if \offers~hasIndex(key) then return .nil
  return offers[key]
::method dispatch
  expose operations
  use strict arg action, context
  receipt = .directory~new
  receipt['status'] = 'simulated'
  receipt['action'] = action
  receipt['requestId'] = context['requestId']
  operations~append(receipt)
  return receipt
::method verifyInbound
  use strict arg interaction
  return .false
::method verifyRemote
  use strict arg ticket, status, evidence
  return .false

::requires 'SocialScopedPublication.cls'
