/* SocketIntentions.cls
 * ooRexx Socket Provider v0.1-dev14
 *
 * Intention-facing socket negotiation.
 *
 * The intention layer says what kind of communication is required.  This
 * component discovers current socket offers, rejects those which do not meet
 * hard requirements, ranks the remainder deterministically, and returns one
 * selected SocketAddress.  It does not create a second transport authority.
 *
 * Public contracts:
 *   socket.intention/0.1
 *   socket.negotiation/0.1
 */

::class SocketIntentionBuild public
::constant VERSION "0.1-dev14"
::constant INTENTION_API "socket.intention/0.1"
::constant NEGOTIATION_API "socket.negotiation/0.1"

::class SocketIntentionName public
::constant NEGOTIATE "NEGOTIATE_SOCKET"
::constant OPEN "OPEN_SOCKET"
::constant LISTEN "LISTEN_SOCKET"
::constant EXPLAIN "EXPLAIN_SOCKET_SELECTION"

/* Hard requirements only.  Preference belongs to SocketNegotiationPolicy. */
::class SocketNegotiationRequest public
::method init
  expose logicalName role requireStream requireSecure requireMulticast localOnly allowedSchemes peerId metadata
  use strict arg logicalName, role="SENDER", requireStream=.true, requireSecure=.false, requireMulticast=.false, localOnly=.false, allowedSchemes=.nil, peerId="", metadata=.nil
  logicalName=logicalName~string~strip
  role=role~string~strip~upper
  requireStream=requireStream
  requireSecure=requireSecure
  requireMulticast=requireMulticast
  localOnly=localOnly
  peerId=peerId~string~strip
  if allowedSchemes=.nil then allowedSchemes=.array~new
  else allowedSchemes=allowedSchemes
  if metadata=.nil then metadata=.directory~new
  else metadata=metadata
  if logicalName="" then raise syntax 88.900 array("socket negotiation logicalName must not be empty")
  if role<>.SocketRole~SENDER & role<>.SocketRole~LISTENER then raise syntax 88.900 array("invalid socket negotiation role")
::attribute logicalName get
::attribute role get
::attribute requireStream get
::attribute requireSecure get
::attribute requireMulticast get
::attribute localOnly get
::attribute allowedSchemes get
::attribute peerId get
::attribute metadata get

::method schemeAllowed
  expose allowedSchemes
  use strict arg scheme
  if allowedSchemes~items=0 then return .true
  wanted=scheme~string~strip~lower
  do x over allowedSchemes
    if x~string~strip~lower=wanted then return .true
  end
  return .false


/* One currently possible way to satisfy a request.  Offers are observations,
 * not authority to connect.  The selected address is still consumed by the
 * ordinary SocketProvider and its registered transport binding.
 */
::class SocketNegotiationOffer public
::method init
  expose offerId address priority localityClass available evidence providerId capabilitiesOverride
  use strict arg offerId, address, priority=100, localityClass="REMOTE", available=.true, evidence="", providerId="", capabilitiesOverride=.nil
  offerId=offerId~string~strip
  address=address
  priority=priority+0
  localityClass=localityClass~string~strip~upper
  available=available
  evidence=evidence~string
  providerId=providerId~string~strip
  capabilitiesOverride=capabilitiesOverride
  if offerId="" then raise syntax 88.900 array("socket offerId must not be empty")
  if address=.nil then raise syntax 88.900 array("socket offer requires address")
::attribute offerId get
::attribute address get
::attribute priority get
::attribute localityClass get
::attribute available get
::attribute evidence get
::attribute providerId get
::attribute capabilitiesOverride get
::method capabilities
  expose address capabilitiesOverride
  if capabilitiesOverride<>.nil then return capabilitiesOverride
  return address~family~capabilities


::class SocketNegotiationStatus public
::constant SELECTED "SELECTED"
::constant NO_OFFER "NO_OFFER"
::constant CLARIFY "CLARIFY"

::class SocketNegotiationSelection public
::method init
  expose status request offer reason rejected
  use strict arg status, request, offer=.nil, reason="", rejected=.nil
  status=status~string~strip~upper
  request=request
  offer=offer
  reason=reason~string
  if rejected=.nil then rejected=.array~new
  else rejected=rejected
::attribute status get
::attribute request get
::attribute offer get
::attribute reason get
::attribute rejected get
::method address
  expose offer
  if offer=.nil then return .nil
  return offer~address
::method selected
  expose status
  return status=.SocketNegotiationStatus~SELECTED


/* Dynamic offer providers are queried on every negotiation.  They may source
 * deployment state, Runtime Registry, MU/MI topology, XTP route tables, policy
 * or any other current evidence.  Nothing here caches a permanent catalogue.
 */
::class SocketOfferProvider public
::method offers abstract

/* Adapter over the existing SocketAddressProvider.  This makes already
 * registered TCP/UNIX/TLS addresses participate without changing that API.
 */
::class AddressProviderSocketOfferProvider public subclass SocketOfferProvider
::method init
  expose addressProvider providerId defaultPriority
  use strict arg addressProvider, providerId="address-provider", defaultPriority=100
  addressProvider=addressProvider
  providerId=providerId~string~strip
  defaultPriority=defaultPriority+0
::method offers
  expose addressProvider providerId defaultPriority
  use strict arg request, context=.nil
  answer=.array~new
  a=addressProvider~resolve(request~logicalName,request~role)
  if a=.nil then return answer
  answer~append(.SocketNegotiationOffer~new(providerId||":"||a~scheme,a,defaultPriority,self~locality(a),.true,"resolved address",providerId))
  return answer
::method locality private
  use strict arg address
  if address~transport=.SocketTransportKind~UNIX then return "LOCAL"
  return "REMOTE"


/* Useful for tests and deployment catalogues which have several valid routes
 * for the same logical socket name. */
::class RegisteredSocketOfferProvider public subclass SocketOfferProvider
::method init
  expose byName
  byName=.directory~new
::method register
  expose byName
  use strict arg logicalName, offer
  name=logicalName~string~strip
  a=byName[name]
  if a=.nil then do; a=.array~new; byName[name]=a; end
  a~append(offer)
  return self
::method offers
  expose byName
  use strict arg request, context=.nil
  source=byName[request~logicalName]
  out=.array~new
  if source=.nil then return out
  do offer over source; out~append(offer); end
  return out

/* Current capability state is mutable because deployment/routes/providers can
 * change.  Dynamic Intention discovery must observe the current set each turn,
 * not a startup snapshot. */
::method clear
  expose byName
  use strict arg logicalName
  byName[logicalName~string~strip]=.array~new
  return self

::method remove
  expose byName
  use strict arg logicalName, offerId
  name=logicalName~string~strip
  source=byName[name]
  if source=.nil then return .false
  out=.array~new
  removed=.false
  do offer over source
    if offer~offerId=offerId~string~strip then removed=.true
    else out~append(offer)
  end
  byName[name]=out
  return removed

::method replace
  expose byName
  use strict arg logicalName, offers
  name=logicalName~string~strip
  copy=.array~new
  do offer over offers; copy~append(offer); end
  byName[name]=copy
  return self




/* XTP dev9 publishes a native userspace Listener, but its ooRexx provider
 * bridge deliberately refuses listener acquisition until it can retain the
 * native Listener and replay state across accept calls.  This capability
 * profile lets Intention negotiation represent that truth precisely:
 * sender yes, listener no.  It is evidence about the current bridge, not a
 * permanent property of the XTP family.
 */
::class SocketCapabilityProfiles public
/* dev9: sender is native, listener bridge deliberately unavailable. */
::method xtpDev9Rexx class
  return .SocketCapabilities~new(.SocketScheme~XTP,.SocketAddressFamily~XTP,.true,.false,.true,.false,.false)

/* dev10: native ooRexx sender and persistent listener are both available.
 * libxtp retains replay/carrier state behind the listener handle. */
::method xtpDev10Rexx class
  return .SocketCapabilities~new(.SocketScheme~XTP,.SocketAddressFamily~XTP,.true,.true,.true,.false,.false)
/* dev12 retains sender/listener and adds multipath/path-health, but the current
 * executable XTP profile still explicitly excludes multicast. */
::method xtpDev12Rexx class
  return .SocketCapabilities~new(.SocketScheme~XTP,.SocketAddressFamily~XTP,.true,.true,.true,.false,.false)
/* dev14 is the current capability-truth line: sender/listener remain available;
 * multicast remains explicitly unadvertised. */
::method xtpDev14Rexx class
  return .SocketCapabilities~new(.SocketScheme~XTP,.SocketAddressFamily~XTP,.true,.true,.true,.false,.false)
/* dev17: libxtp now implements reliable MULTI FIRST+DATA streaming,
 * slowest-receiver ALLOC pacing and receiver reject suppression.  The common
 * selector expresses multicast streaming as stream && multicast. */
::method xtpDev17Rexx class
  return .SocketCapabilities~new(.SocketScheme~XTP,.SocketAddressFamily~XTP,.true,.true,.true,.false,.true)

/* NORM dev1: message/object oriented reliable multicast sender and persistent
 * receiver are available.  It is deliberately not advertised as a stream. */
::method normDev1Rexx class
  return .SocketCapabilities~new(.SocketScheme~NORM,.SocketAddressFamily~NORM,.false,.true,.true,.false,.true)


/* Convenience offer provider for the current XTP dev9 ooRexx bridge.  It is
 * intentionally small: route discovery remains owned by XTP.  The caller
 * supplies currently valid XTP addresses/evidence, and this provider stamps
 * the role-specific bridge capability used by negotiation.
 */
::class XtpDev9SocketOfferProvider public subclass SocketOfferProvider
::method init
  expose delegate
  delegate=.RegisteredSocketOfferProvider~new
::method register
  expose delegate
  use strict arg logicalName, offerId, address, priority=100, localityClass="REMOTE", available=.true, evidence="XTP dev9 route available", providerId="xtp-dev9"
  if address~transport<>.SocketTransportKind~XTP then raise syntax 88.900 array("XtpDev9SocketOfferProvider requires XTP address")
  offer=.SocketNegotiationOffer~new(offerId,address,priority,localityClass,available,evidence,providerId,.SocketCapabilityProfiles~xtpDev9Rexx)
  delegate~register(logicalName,offer)
  return self
::method offers
  expose delegate
  use strict arg request, context=.nil
  return delegate~offers(request,context)


/* Current XTP dev10 ooRexx bridge.  Sender and listener are both native and
 * usable through SocketSelector/SocketProvider.  Route discovery remains XTP's
 * responsibility; this provider only projects current addresses plus the
 * implementation capability actually qualified by dev10. */
::class XtpDev10SocketOfferProvider public subclass SocketOfferProvider
::method init
  expose delegate
  delegate=.RegisteredSocketOfferProvider~new
::method register
  expose delegate
  use strict arg logicalName, offerId, address, priority=100, localityClass="REMOTE", available=.true, evidence="XTP dev10 route available", providerId="xtp-dev10"
  if address~transport<>.SocketTransportKind~XTP then raise syntax 88.900 array("XtpDev10SocketOfferProvider requires XTP address")
  offer=.SocketNegotiationOffer~new(offerId,address,priority,localityClass,available,evidence,providerId,.SocketCapabilityProfiles~xtpDev10Rexx)
  delegate~register(logicalName,offer)
  return self
::method offers
  expose delegate
  use strict arg request, context=.nil
  return delegate~offers(request,context)

/* Current XTP dev12 projection.  Sender/listener plus path-health/multipath
 * exist below this boundary.  Multicast remains fail-closed because the
 * executable libxtp profile still lists it outside the implemented subset. */
::class XtpDev12SocketOfferProvider public subclass SocketOfferProvider
::method init
  expose delegate
  delegate=.RegisteredSocketOfferProvider~new
::method register
  expose delegate
  use strict arg logicalName, offerId, address, priority=100, localityClass="REMOTE", available=.true, evidence="XTP dev12 route available", providerId="xtp-dev12"
  if address~transport<>.SocketTransportKind~XTP then raise syntax 88.900 array("XtpDev12SocketOfferProvider requires XTP address")
  offer=.SocketNegotiationOffer~new(offerId,address,priority,localityClass,available,evidence,providerId,.SocketCapabilityProfiles~xtpDev12Rexx)
  delegate~register(logicalName,offer)
  return self
::method offers
  expose delegate
  use strict arg request, context=.nil
  return delegate~offers(request,context)

/* XTP dev14 keeps the dev12 sender/listener shape and corrects capability truth
 * explicitly in the current libxtp package: multicast=false. */
::class XtpDev14SocketOfferProvider public subclass SocketOfferProvider
::method init
  expose delegate
  delegate=.RegisteredSocketOfferProvider~new
::method register
  expose delegate
  use strict arg logicalName, offerId, address, priority=100, localityClass="REMOTE", available=.true, evidence="XTP dev14 route available", providerId="xtp-dev14"
  if address~transport<>.SocketTransportKind~XTP then raise syntax 88.900 array("XtpDev14SocketOfferProvider requires XTP address")
  offer=.SocketNegotiationOffer~new(offerId,address,priority,localityClass,available,evidence,providerId,.SocketCapabilityProfiles~xtpDev14Rexx)
  delegate~register(logicalName,offer)
  return self
::method offers
  expose delegate
  use strict arg request, context=.nil
  return delegate~offers(request,context)

/* Current XTP dev17 projection.  libxtp owns route selection, carriers,
 * wire filters, multipath and multicast control mechanics.  Socket Provider
 * only projects the currently qualified stream+multicast capability. */
::class XtpDev17SocketOfferProvider public subclass SocketOfferProvider
::method init
  expose delegate
  delegate=.RegisteredSocketOfferProvider~new
::method register
  expose delegate
  use strict arg logicalName, offerId, address, priority=100, localityClass="REMOTE", available=.true, evidence="XTP dev17 route available", providerId="xtp-dev17"
  if address~transport<>.SocketTransportKind~XTP then raise syntax 88.900 array("XtpDev17SocketOfferProvider requires XTP address")
  offer=.SocketNegotiationOffer~new(offerId,address,priority,localityClass,available,evidence,providerId,.SocketCapabilityProfiles~xtpDev17Rexx)
  delegate~register(logicalName,offer)
  return self
::method offers
  expose delegate
  use strict arg request, context=.nil
  return delegate~offers(request,context)

/* NORM provider projection.  Group/interface/source/session mechanics remain
 * owned by the NORM provider; negotiation sees current address/capability evidence. */
::class NormDev1SocketOfferProvider public subclass SocketOfferProvider
::method init
  expose delegate
  delegate=.RegisteredSocketOfferProvider~new
::method register
  expose delegate
  use strict arg logicalName, offerId, address, priority=100, localityClass="REMOTE", available=.true, evidence="NORM reliable multicast available", providerId="norm-dev1"
  if address~transport<>.SocketTransportKind~NORM then raise syntax 88.900 array("NormDev1SocketOfferProvider requires NORM address")
  offer=.SocketNegotiationOffer~new(offerId,address,priority,localityClass,available,evidence,providerId,.SocketCapabilityProfiles~normDev1Rexx)
  delegate~register(logicalName,offer)
  return self
::method offers
  expose delegate
  use strict arg request, context=.nil
  return delegate~offers(request,context)

/* NORM dev3 retains the same semantic socket capability and adds provider-owned
 * descriptor/readiness behaviour below this negotiation boundary. */
::class NormDev3SocketOfferProvider public subclass SocketOfferProvider
::method init
  expose delegate
  delegate=.RegisteredSocketOfferProvider~new
::method register
  expose delegate
  use strict arg logicalName, offerId, address, priority=100, localityClass="REMOTE", available=.true, evidence="NORM dev3 reliable multicast available", providerId="norm-dev3"
  if address~transport<>.SocketTransportKind~NORM then raise syntax 88.900 array("NormDev3SocketOfferProvider requires NORM address")
  offer=.SocketNegotiationOffer~new(offerId,address,priority,localityClass,available,evidence,providerId,.SocketCapabilityProfiles~normDev1Rexx)
  delegate~register(logicalName,offer)
  return self
::method offers
  expose delegate
  use strict arg request, context=.nil
  return delegate~offers(request,context)

::class SocketNegotiationPolicy public
::method init
  expose preferLocal preferSecure schemeOrder
  use strict arg preferLocal=.true, preferSecure=.true, schemeOrder=.nil
  preferLocal=preferLocal
  preferSecure=preferSecure
  if schemeOrder=.nil then do
    schemeOrder=.array~new
    /* Local Unix first. XTP is ahead of IP families when available because it
     * is the intended internal transport, without making it mandatory. */
    schemeOrder~append(.SocketScheme~UNIX)
    schemeOrder~append(.SocketScheme~XTP)
    schemeOrder~append(.SocketScheme~NORM)
    schemeOrder~append(.SocketScheme~UDP)
    schemeOrder~append(.SocketScheme~TLS)
    schemeOrder~append(.SocketScheme~TCP)
  end
  else schemeOrder=schemeOrder
::attribute preferLocal get
::attribute preferSecure get
::attribute schemeOrder get
::method schemeRank
  expose schemeOrder
  use strict arg scheme
  i=1
  do s over schemeOrder
    if s~string~lower=scheme~string~lower then return i
    i+=1
  end
  return 999



/* One bounded observation of current provider state.  This is evidence, not a
 * cache contract.  A new observation is built for every discovery/negotiation
 * turn. */
::class SocketOfferObservation public
::method init
  expose generation request candidates rejected providerCount
  use strict arg generation, request, candidates, rejected, providerCount
  generation=generation+0
  request=request
  candidates=candidates
  rejected=rejected
  providerCount=providerCount+0
::attribute generation get
::attribute request get
::attribute candidates get
::attribute rejected get
::attribute providerCount get


::class SocketIntentionDiscoverySnapshot public
::method init
  expose generation request intentions observation feasible
  use strict arg generation, request, intentions, observation, feasible
  generation=generation+0
  request=request
  intentions=intentions
  observation=observation
  feasible=feasible
::attribute generation get
::attribute request get
::attribute intentions get
::attribute observation get
::attribute feasible get
::method hasIntention
  expose intentions
  use strict arg name
  wanted=name~string~strip~upper
  do d over intentions
    if d~name=wanted then return .true
  end
  return .false


::class SocketNegotiator public
::method init
  expose providers policy observationGeneration
  use strict arg policy=.nil
  providers=.array~new
  observationGeneration=0
  if policy=.nil then policy=.SocketNegotiationPolicy~new
  else policy=policy
::method registerOfferProvider
  expose providers
  use strict arg provider
  providers~append(provider)
  return self
::method providers
  expose providers
  return providers~copy
::method observe
  expose providers observationGeneration
  use strict arg request, context=.nil
  candidates=.array~new
  rejected=.array~new
  providerCount=0

  do p over providers
    providerCount+=1
    offers=p~offers(request,context)
    if offers=.nil then iterate
    do offer over offers
      reason=self~rejectionReason(request,offer)
      if reason="" then candidates~append(offer)
      else do
        d=.directory~new
        d["offerId"]=offer~offerId
        d["reason"]=reason
        d["providerId"]=offer~providerId
        rejected~append(d)
      end
    end
  end

  observationGeneration+=1
  return .SocketOfferObservation~new(observationGeneration,request,candidates,rejected,providerCount)

::method negotiate
  expose policy
  use strict arg request, context=.nil
  observation=self~observe(request,context)
  candidates=observation~candidates
  rejected=observation~rejected

  if candidates~items=0 then
    return .SocketNegotiationSelection~new(.SocketNegotiationStatus~NO_OFFER,request,.nil,"no current socket offer satisfies the hard requirements",rejected)

  best=.nil; bestScore=999999999
  do offer over candidates
    score=self~score(offer)
    if best=.nil | score<bestScore then do
      best=offer; bestScore=score
    end
  end

  return .SocketNegotiationSelection~new(.SocketNegotiationStatus~SELECTED,request,best,"selected from current qualified socket offers",rejected)

::method rejectionReason private
  use strict arg request, offer
  if \offer~available then return "OFFER_UNAVAILABLE"
  address=offer~address
  caps=offer~capabilities
  if \request~schemeAllowed(address~scheme) then return "SCHEME_NOT_ALLOWED"
  if request~requireStream & \caps~stream then return "STREAM_REQUIRED"
  if request~requireSecure & \caps~secure then return "SECURE_REQUIRED"
  if request~requireMulticast then do
    if \caps~multicast then return "MULTICAST_REQUIRED"
    /* A multicast-capable family does not make every endpoint multicast. */
    if \address~multicast then return "MULTICAST_ADDRESS_REQUIRED"
  end
  if request~role="SENDER" & \caps~sender then return "SENDER_REQUIRED"
  if request~role=.SocketRole~LISTENER & \caps~listener then return "LISTENER_REQUIRED"
  if request~localOnly & offer~localityClass<>"LOCAL" then return "LOCAL_ONLY"
  return ""

::method score private
  expose policy
  use strict arg offer
  score=offer~priority*1000
  if policy~preferLocal then do
    if offer~localityClass="LOCAL" then score-=200
    else score+=200
  end
  if policy~preferSecure then do
    if offer~capabilities~secure then score-=20
  end
  score+=policy~schemeRank(offer~address~scheme)
  return score


/* Intention descriptors are deliberately simple ordinary objects.  The real
 * Intention Service adapter can turn these into registrations/events without
 * making Socket Provider depend on one specific Intention Service revision.
 */
::class SocketIntentionDescriptor public
::method init
  expose name phrase role description
  use strict arg name, phrase, role="", description=""
  name=name~string~strip~upper
  phrase=phrase~string~strip
  role=role~string~strip~upper
  description=description~string
::attribute name get
::attribute phrase get
::attribute role get
::attribute description get


/* Dynamic Intention port.  discover() is deliberately recomputed each call.
 * Negotiation is deterministic once semantic requirements have been supplied.
 */
::class SocketIntentionPort public
::method init
  expose negotiator socketProvider
  use strict arg negotiator, socketProvider=.nil
  negotiator=negotiator
  socketProvider=socketProvider

::method discover
  expose negotiator
  use strict arg context=.nil
  /* Generic discovery has no target address requirement yet.  Only the
   * non-mutating semantic operations are universally truthful. */
  answer=.array~new
  answer~append(.SocketIntentionDescriptor~new(.SocketIntentionName~NEGOTIATE,"negotiate a socket","","Find the best current socket family/address for communication requirements"))
  answer~append(.SocketIntentionDescriptor~new(.SocketIntentionName~EXPLAIN,"explain socket selection","","Present the selected offer and rejected alternatives"))
  return answer

/* Discovery for a concrete semantic requirement is authoritative for this
 * turn.  OPEN/LISTEN appear only if a fresh bounded observation says the
 * requested role is feasible now. */
::method discoverFor
  expose negotiator
  use strict arg request, context=.nil
  observation=negotiator~observe(request,context)
  intents=.array~new
  intents~append(.SocketIntentionDescriptor~new(.SocketIntentionName~NEGOTIATE,"negotiate a socket","","Find the best current socket family/address for communication requirements"))
  intents~append(.SocketIntentionDescriptor~new(.SocketIntentionName~EXPLAIN,"explain socket selection","","Present the selected offer and rejected alternatives"))

  feasible=(observation~candidates~items>0)
  if feasible then do
    if request~role=.SocketRole~LISTENER then
      intents~append(.SocketIntentionDescriptor~new(.SocketIntentionName~LISTEN,"listen on a socket",.SocketRole~LISTENER,"Open a listener using a currently feasible negotiated socket"))
    else
      intents~append(.SocketIntentionDescriptor~new(.SocketIntentionName~OPEN,"open a socket",.SocketRole~SENDER,"Open a sender using a currently feasible negotiated socket"))
  end

  return .SocketIntentionDiscoverySnapshot~new(observation~generation,request,intents,observation,feasible)

::method negotiate
  expose negotiator
  use strict arg request, context=.nil
  return negotiator~negotiate(request,context)

::method open
  expose negotiator socketProvider
  use strict arg request, context=.nil, backlog=32
  selection=negotiator~negotiate(request,context)
  if \selection~selected then return selection
  if socketProvider=.nil then return selection
  address=selection~address
  if request~role=.SocketRole~LISTENER then handle=socketProvider~listenerAt(address,backlog)
  else handle=socketProvider~senderAt(address)
  d=.directory~new
  d["selection"]=selection
  d["handle"]=handle
  return d

::method explain
  use strict arg selection
  d=.directory~new
  d["status"]=selection~status
  d["reason"]=selection~reason
  if selection~offer<>.nil then do
    d["offerId"]=selection~offer~offerId
    d["address"]=selection~offer~address~canonical
    d["providerId"]=selection~offer~providerId
    d["evidence"]=selection~offer~evidence
  end
  d["rejected"]=selection~rejected
  return d



/* Small discovery-first adapter suitable for an Intention controller.  It owns
 * no conversational state and no LLM.  The controller supplies the semantic
 * SocketNegotiationRequest for the current turn and receives a fresh snapshot.
 */
::class SocketDynamicIntentionProvider public
::method init
  expose port
  use strict arg port
  port=port
::method discover
  expose port
  use strict arg request, context=.nil
  return port~discoverFor(request,context)
::method negotiate
  expose port
  use strict arg request, context=.nil
  return port~negotiate(request,context)
::method open
  expose port
  use strict arg request, context=.nil, backlog=32
  return port~open(request,context,backlog)

::requires "SocketProvider.cls"
