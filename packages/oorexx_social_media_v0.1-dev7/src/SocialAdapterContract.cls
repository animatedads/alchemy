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

/* dev7: guard the adapter dispatch choke-point, not only the CMS facade.
 * Holds independently injected authority, current scope resolver and policy.
 * It is deliberately NOT a universal auth service and DOES NOT make test
 * authorities or a single-process consumed registry suitable for production.
 */
::class SocialDispatchGuard public
::method init
  expose authority gate policy consumed journal
  use strict arg authority, resolver, policy, journal
  if authority == .nil | resolver == .nil | policy == .nil | journal == .nil then raise syntax 93.900 array ('Dispatch guard requires authority, resolver, policy and outbox')
  if \authority~isA(.SocialPublicationAuthority) then raise syntax 93.900 array ('Invalid publication authority')
  if \resolver~isA(.SocialScopedCapabilityResolver) then raise syntax 93.900 array ('Invalid scoped resolver')
  if \policy~isA(.SocialPolicy) then raise syntax 93.900 array ('Invalid dispatch policy')
  if \journal~isA(.SocialPublicationJournal) then raise syntax 93.900 array ('Invalid outbox journal')
  gate = .SocialScopedCapabilityGate~new(resolver)
  consumed = .directory~new
::method admit
  expose authority gate policy consumed journal
  use strict arg action, context
  if \context~isA(.directory) then raise syntax 93.900 array ('Dispatch requires validated publication context')
  if \context~hasIndex('requestObject') then raise syntax 93.900 array ('Original publication object missing')
  request = context['requestObject']
  if \request~isA(.SocialPublicationRequest) then raise syntax 93.900 array ('Original publication object invalid')
  if request~action <> action then raise syntax 93.900 array ('Dispatch operation mismatch')
  expected = request~context
  do key over 'requestId providerId brandId accountId surfaceKey surfaceFamily action contentId contentVersion body approvalRef intentionRef narrativeRef parentKey'~makearray(' ')
    if \context~hasIndex(key) then raise syntax 93.900 array ('Dispatch field omitted: ' || key)
    if context[key] \== expected[key] then raise syntax 93.900 array ('Dispatch field tampered: ' || key)
  end
  if \context~hasIndex('assets') then raise syntax 93.900 array ('Dispatch assets omitted')
  submitted = context['assets']
  original = expected['assets']
  if \submitted~isA(.array) then raise syntax 93.900 array ('Dispatch assets malformed')
  if submitted~items <> original~items then raise syntax 93.900 array ('Dispatch assets changed')
  do i = 1 to original~items
    if submitted[i] \== original[i] then raise syntax 93.900 array ('Dispatch asset mutated')
  end
  /* No grant is inferred from an approvalRef string or an adapter capability. */
  if \authority~allow(request) then raise syntax 93.900 array ('Publication authority denied at dispatch')
  offer = gate~check(request)
  if \policy~allow(action, context) then raise syntax 93.900 array ('Dispatch policy denied')
  if consumed~hasIndex(request~id) then raise syntax 93.900 array ('Dispatch already consumed: reconcile prior outcome')
  /* Require a recorded dispatching state from the authoritative outbox.
   * Never call replay() default here: that represents a process restart. */
  checkpoints = journal~replay(.false)
  if \checkpoints~hasIndex(request~id) then raise syntax 93.900 array ('No outbox dispatch checkpoint')
  checkpoint = checkpoints[request~id]
  if checkpoint~fingerprint \== request~fingerprint then raise syntax 93.900 array ('Outbox fingerprint mismatch')
  if checkpoint~status \== 'dispatching' then raise syntax 93.900 array ('Outbox not in dispatching state')
  if checkpoint~providerId \== request~surface~providerId then raise syntax 93.900 array ('Outbox provider mismatch')
  /* Fence BEFORE the provider call; any uncertainty remains blocked. */
  consumed[request~id] = request~fingerprint
  return .true

/* Provider wrapper may dispatch only with independently checked proof of the
 * exact request. Unsafe unguarded wrappers no longer exist in this API.
 * The original requestObject never crosses the provider boundary.
 */
::class SocialAdapterProvider public subclass SocialProvider
::method init
  expose adapter guard
  use strict arg adapter, guard
  if adapter == .nil | guard == .nil then raise syntax 93.900 array ('Guarded adapter requires adapter and dispatch guard')
  if \adapter~isA(.SocialAdapter) then raise syntax 93.900 array ('Invalid adapter provider')
  if \guard~isA(.SocialDispatchGuard) then raise syntax 93.900 array ('Invalid dispatch guard')
::method id
  expose adapter
  return adapter~id
::method capabilities
  expose adapter
  return adapter~capabilities
::method perform
  expose adapter guard
  use strict arg action, context
  guard~admit(action,context)
  outbound = .directory~new
  do key over context~allIndexes
    if key \== 'requestObject' then outbound[key] = context[key]
  end
  return adapter~dispatch(action,outbound)

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

::requires 'SocialPublicationJournal.cls'
