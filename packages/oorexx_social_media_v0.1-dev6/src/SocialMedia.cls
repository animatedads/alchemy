/* Social Media semantic plumbing 0.1-dev1. No network transport ownership. */
::class SocialEnvelope public
::method id attribute
::method kind attribute
::method author attribute
::method body attribute
::method replyTo attribute
::method audience attribute
::method media attribute
::method metadata attribute
::method init
  expose id kind author body replyTo audience media metadata
  use strict arg id, kind, author, body
  if id == '' | kind == '' | author == '' then raise syntax 93.900 array ('Missing envelope identity/kind/author')
  replyTo = ''
  audience = .array~new
  media = .array~new
  metadata = .directory~new
::method addMedia
  expose media
  use strict arg item
  media~append(item)
  return self
::method addAudience
  expose audience
  use strict arg item
  audience~append(item)
  return self

::class SocialCapability public
::method name attribute
::method enabled attribute
::method constraints attribute
::method init
  expose name enabled constraints
  use strict arg name, enabled
  constraints = .directory~new
::method limit
  expose constraints
  use strict arg key, value
  constraints[key] = value
  return self

::class SocialProvider public
::method id abstract
::method capabilities abstract
::method perform abstract

/* Deliberately inert adapter: records receipts, never delivers externally. */
::class SocialMemoryProvider public subclass SocialProvider
::method operations attribute
::method init
  expose operations
  operations = .array~new
::method id
  return 'memory'
::method capabilities
  caps = .directory~new
  do action over 'publish reply receive moderate measure'~makearray(' ')
    caps[action] = .SocialCapability~new(action, .true)
  end
  return caps
::method perform
  expose operations
  use strict arg action, context
  receipt = .directory~new
  receipt['status'] = 'simulated'
  receipt['provider'] = self~id
  receipt['action'] = action
  receipt['context'] = context
  operations~append(receipt)
  return receipt

::class SocialPolicy public
::method authorizer attribute
::method init
  expose authorizer
  use strict arg authorizer
::method allow
  expose authorizer
  use strict arg action, context
  if authorizer == .nil then return .false
  return authorizer~allow(action, context)

::class SocialDenyByDefault public
::method allow
  use strict arg action, context
  return .false

/* Explicit test-only grants; never wire this to a real provider in production. */
::class SocialTestGrant public
::method grants attribute
::method init
  expose grants
  grants = .directory~new
::method grant
  expose grants
  use strict arg action
  grants[action] = .true
::method allow
  expose grants
  use strict arg action, context
  return grants~hasIndex(action)

::class SocialLibrary public
::method providers attribute
::method policy attribute
::method audit attribute
::method init
  expose providers policy audit
  providers = .directory~new
  policy = .SocialPolicy~new(.SocialDenyByDefault~new)
  audit = .array~new
::method register
  expose providers
  use strict arg provider
  providers[provider~id] = provider
  return self
::method discover
  expose providers
  use strict arg providerId
  if \providers~hasIndex(providerId) then return .nil
  return providers[providerId]~capabilities
::method execute
  expose providers policy audit
  use strict arg providerId, action, context
  if \providers~hasIndex(providerId) then raise syntax 93.900 array ('Unknown social provider')
  caps = providers[providerId]~capabilities
  if \caps~hasIndex(action) then raise syntax 93.900 array ('Unsupported social action')
  capability = caps[action]
  if \capability~enabled then raise syntax 93.900 array ('Social capability disabled')
  if \policy~allow(action, context) then raise syntax 93.900 array ('Authorisation denied')
  outcome = providers[providerId]~perform(action, context)
  audit~append(outcome)
  return outcome

/* v0.1-dev2: Surface identity separates provider, community/resource and item.
   This is a semantic locator, not a URL or an authority to access an account. */
::class SocialSurface public
::method providerId attribute
::method family attribute
::method resourceId attribute
::method visibility attribute
::method metadata attribute
::method init
  expose providerId family resourceId visibility metadata
  use strict arg providerId, family, resourceId, visibility
  if providerId == '' | family == '' | resourceId == '' then raise syntax 93.900 array ('Incomplete social surface')
  if visibility == '' then raise syntax 93.900 array ('Visibility must be declared')
  metadata = .directory~new
::method key
  expose providerId family resourceId
  return length(providerId) || ':' || providerId || length(family) || ':' || family || length(resourceId) || ':' || resourceId

::class SocialReference public
::method surface attribute
::method itemId attribute
::method itemKind attribute
::method init
  expose surface itemId itemKind
  use strict arg surface, itemId, itemKind
  if surface == .nil | itemId == '' | itemKind == '' then raise syntax 93.900 array ('Incomplete social reference')
::method key
  expose surface itemId itemKind
  return surface~key || length(itemKind) || ':' || itemKind || length(itemId) || ':' || itemId

/* An observed interaction. Parent/target are qualified references, not bare IDs.
   An external comment can reference an unobserved parent, so graph edges are
   allowed to precede receipt of the referenced content. */
::class SocialInteraction public
::method id attribute
::method kind attribute
::method actor attribute
::method target attribute
::method parent attribute
::method content attribute
::method source attribute
::method metadata attribute
::method init
  expose id kind actor target parent content source metadata
  use strict arg id, kind, actor, target, parent, content, source
  if id == '' | kind == '' | actor == '' | source == '' then raise syntax 93.900 array ('Incomplete social interaction')
  if target == .nil then raise syntax 93.900 array ('Interaction needs a qualified target')
  metadata = .directory~new
::method key
  expose id target source
  return target~surface~key || length(source) || ':' || source || length(id) || ':' || id

/* Store only detached/accepted interaction objects; no remote fetching. */
::class SocialConversationGraph public
::method interactions attribute
::method childEdges attribute
::method init
  expose interactions childEdges
  interactions = .directory~new
  childEdges = .directory~new
::method contains
  expose interactions
  use strict arg event
  return interactions~hasIndex(event~key)
::method record
  expose interactions childEdges
  use strict arg event
  eventKey = event~key
  if interactions~hasIndex(eventKey) then return .false
  interactions[eventKey] = event
  if event~parent <> .nil then do
    parentKey = event~parent~key
    if \childEdges~hasIndex(parentKey) then childEdges[parentKey] = .array~new
    childEdges[parentKey]~append(eventKey)
  end
  return .true
::method childrenOf
  expose childEdges
  use strict arg reference
  parentKey = reference~key
  if \childEdges~hasIndex(parentKey) then return .array~new
  return childEdges[parentKey]~copy
::method count
  expose interactions
  return interactions~items

/* A verifier must establish source authority before any inbound event can
   enter the graph. This is independent of permission to publish a response. */
::class SocialInboundGate public
::method verifier attribute
::method graph attribute
::method audit attribute
::method init
  expose verifier graph audit
  use strict arg graph
  verifier = .nil
  audit = .array~new
::method accept
  expose verifier graph audit
  use strict arg interaction
  if verifier == .nil then raise syntax 93.900 array ('Inbound source verification required')
  if \verifier~verify(interaction) then raise syntax 93.900 array ('Inbound source not verified')
  wasAdded = graph~record(interaction)
  receipt = .directory~new
  receipt['id'] = interaction~key
  if wasAdded then receipt['status'] = 'accepted'
  else receipt['status'] = 'duplicate'
  audit~append(receipt)
  return receipt

/* Test-only verifier. Production verifiers must authenticate origin, request
   signature where available, authority, event timestamp and replay window. */
::class SocialTestInboundVerifier public
::method approved attribute
::method init
  expose approved
  approved = .directory~new
::method permit
  expose approved
  use strict arg source
  approved[source] = .true
  return self
::method verify
  expose approved
  use strict arg interaction
  return approved~hasIndex(interaction~source)

/* This catalog is a taxonomy of social semantics. It does NOT declare that a
   vendor supplies any API, scope, credential or commercially usable action. */
::class SocialSurfaceProfile public
::method name attribute
::method verbs attribute
::method init
  expose name verbs
  use strict arg name
  if name == '' then raise syntax 93.900 array ('Empty profile name')
  verbs = .directory~new
::method addVerb
  expose verbs
  use strict arg verb
  verbs[verb] = .true
  return self
::method supports
  expose verbs
  use strict arg verb
  return verbs~hasIndex(verb)

::class SocialSurfaceCatalog public
::method profiles attribute
::method init
  expose profiles
  profiles = .directory~new
::method define
  expose profiles
  use strict arg name, verbs
  profile = .SocialSurfaceProfile~new(name)
  do v over verbs~makearray(' ')
    profile~addVerb(v)
  end
  profiles[name] = profile
  return self
::method profile
  expose profiles
  use strict arg name
  if \profiles~hasIndex(name) then return .nil
  return profiles[name]
::method count
  expose profiles
  return profiles~items
::method populateCommon
  /* Provider-neutral types: no API enablement implied. */
  self~define('marketplace.product', 'question answer review seller_message')
  self~define('marketplace.seller', 'feedback review reply')
  self~define('local.business', 'review reply question answer')
  self~define('gaming.community', 'thread reply announcement moderation')
  self~define('gaming.review', 'review developer_response reaction')
  self~define('gaming.workshop', 'creation comment reaction subscribe')
  self~define('chat.community', 'channel_message thread reply reaction role moderation')
  self~define('chat.direct', 'direct_message reply reaction')
  self~define('video.comments', 'comment reply reaction moderation')
  self~define('video.creator', 'community_post membership live_chat creator_message')
  self~define('video.live', 'live_chat moderation reaction')
  self~define('email.group', 'message reply digest subscribe unsubscribe')
  self~define('forum', 'thread reply vote moderation')
  self~define('social.feed', 'post reply repost reaction')
  self~define('social.advertising', 'creative placement measure')
  return self

/* A CMS intention can have multiple creative angles without corrupting the
   canonical message or promising that a provider can publish any one angle. */
::class SocialCreativeVariant public
::method id attribute
::method angle attribute
::method audience attribute
::method content attribute
::method assets attribute
::method lineage attribute
::method init
  expose id angle audience content assets lineage
  use strict arg id, angle, audience, content, lineage
  if id == '' | angle == '' | lineage == '' then raise syntax 93.900 array ('Creative variant needs id, angle and lineage')
  assets = .array~new
::method addAsset
  expose assets
  use strict arg reference
  assets~append(reference)
  return self

/* Financial request deliberately carries NO purchase or charging capability.
   Approved ceiling and account scope must still be verified at execution. */
::class SocialPaidPlacementPlan public
::method creativeId attribute
::method surface attribute
::method budgetMinor attribute
::method currency attribute
::method accountId attribute
::method approvalRef attribute
::method init
  expose creativeId surface budgetMinor currency accountId approvalRef
  use strict arg creativeId, surface, budgetMinor, currency, accountId, approvalRef
  if creativeId == '' | surface == .nil | accountId == '' | approvalRef == '' then raise syntax 93.900 array ('Paid placement requires account and approval reference')
  if \datatype(budgetMinor, 'W') then raise syntax 93.900 array ('Budget must be integral minor units')
  if budgetMinor <= 0 then raise syntax 93.900 array ('Budget must be positive')
  if length(currency) <> 3 then raise syntax 93.900 array ('Currency must be ISO 4217 alphabetic code')
  if \datatype(currency, 'A') then raise syntax 93.900 array ('Currency must be alphabetic')

/* Creator/community roles are observational relationships, never authorisation
   to call an API. A membership observed in a channel must not leak to another. */
::class SocialParticipation public
::method actorId attribute
::method surface attribute
::method role attribute
::method status attribute
::method evidenceRef attribute
::method metadata attribute
::method init
  expose actorId surface role status evidenceRef metadata
  use strict arg actorId, surface, role, status, evidenceRef
  if actorId == '' | surface == .nil | role == '' | status == '' | evidenceRef == '' then raise syntax 93.900 array ('Participation requires source evidence and scope')
  metadata = .directory~new
::method key
  expose actorId surface role
  return surface~key || length(actorId) || ':' || actorId || length(role) || ':' || role

::class SocialParticipationIndex public
::method relationships attribute
::method init
  expose relationships
  relationships = .directory~new
::method record
  expose relationships
  use strict arg participation
  relationships[participation~key] = participation
  return self
::method find
  expose relationships
  use strict arg actorId, surface, role
  key = surface~key || length(actorId) || ':' || actorId || length(role) || ':' || role
  if \relationships~hasIndex(key) then return .nil
  return relationships[key]
::method count
  expose relationships
  return relationships~items
