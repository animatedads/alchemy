# Changelog

## 0.1-dev14

- Preserve an accepted provider socket's own `address` object when the common `ProviderSocketListener` wraps it.
- Apply the rule to both blocking `accept()` and provider-neutral `tryAccept()`.
- Fall back to the listener address only for older native peers which do not expose `address`.
- No XTP/NORM/UDP/TLS routing or negotiation semantics changed in this increment.

# Changelog

## 0.1-dev13

- Rebase the bundled XTP adapter on `oorexx_xtp_v0.1-dev17`.
- Add current `xtpDev17Rexx` / `XtpDev17SocketOfferProvider` projection.
- Advertise XTP stream+multicast only because libxtp dev17 now implements and qualifies both.
- Preserve the common dev12 selector contract: multicast streaming is `requireStream && requireMulticast`; no transport-specific capability field is added.
- Preserve sibling IPv6, QUIC, NORM dev3 and IP multicast provider boundaries.

# Changelog

## 0.1-dev11

- Reconcile the three colliding dev10 heads into one authoritative source line.
- Retain UDP/IP multicast + explicit membership and the corrected XTP multicast=false capability truth.
- Retain the concrete RxSock UDP datagram endpoint/binding, including listener port 0.
- Retain provider-neutral `descriptor`, `waitReady`, `tryAccept`, and `waitDrained` delegation required by NORM dev3.
- Preserve both pre-collision UDP factory call shapes and both multicast-address call shapes.
- Add current XTP dev14 and NORM dev3 offer-provider projections without moving their mechanics into Socket Provider.
- Keep RxSock6/IPv6 and QUIC as sibling provider components behind the same boundary.

## 0.1-dev10
- Add UDP/INET as a first-class non-stream SocketProvider family.
- Add `SocketAddresses~udp()` and explicit `SocketAddresses~ipMulticast()` factories.
- Add `RexxUdpSocketBinding` with sender/listener plus provider-neutral explicit join/listener-on-membership hooks.
- Keep RFC 3678/IGMP mechanics in the injected IP multicast provider; common SocketProvider remains native-free.
- Preserve multicast hard-gating: family capability alone never turns a unicast endpoint into multicast.
- Correct historical XTP multicast capability overclaim after checking libxtp dev12: current XTP sender/listener remains qualified but multicast is not advertised until the executable XTP profile implements it.
- Add `XtpDev12SocketOfferProvider` with current evidence-based sender/listener=yes, multicast=no capability projection.


## 0.1-dev9

- Add `socket.multicast.membership/0.1` as a provider-neutral multicast membership contract.
- Add `SocketMulticastMembershipRequest` retaining exact SocketAddress identity plus interface, source filter, scope and metadata.
- Add explicit `SocketProvider~join()` / `joinAt()` and `listenerOn()`; unsupported bindings fail closed.
- Membership lifetime is independent of listener lifetime; closing a listener attached to an explicit membership does not leave the group.
- Extend `RexxNormSocketBinding` with NORM join/listener-on-membership hooks without moving libnorm state into the common provider.
- Preserve all dev8 TCP/UNIX/TLS/XTP/NORM negotiation behavior.

## 0.1-dev8

- Add NORM transport/scheme/address family as a first-class provider offer.
- Add full NORM SocketAddress value fields for group, port, interface, optional SSM source and node id.
- Add RexxNormSocketBinding while keeping libnorm mechanics outside the common selector.
- Preserve existing TCP/UNIX/TLS/XTP contracts.

# CHANGELOG

## 0.1-dev7

- Added `socket.stream/0.1`.
- Added `SocketStreamAdapter` and `ProviderSocketConnection~asStream`.
- Added `SocketProvider~streamSender()` / `streamSenderAt()`.
- Preserves the exact selected `SocketAddress` object by identity.
- Qualified against uploaded Debug Socket Transport v0.1-dev3.
- Added XTP-shaped endpoint compatibility without claiming native XTP traffic.


## 0.1-dev6

- Rebased Socket Intentions on the current discovery-first Intention pattern found in the Library.
- Added fresh per-turn `SocketOfferObservation` generations.
- Added `SocketIntentionDiscoverySnapshot`.
- Added `SocketDynamicIntentionProvider`.
- `OPEN_SOCKET` / `LISTEN_SOCKET` are now dynamically exposed only when the current hard requirements are feasible.
- Added mutable offer removal/replacement to model provider/route arrival and withdrawal.
- Added add/remove/fail-closed qualification.
- Added dynamic XTP dev9 -> dev10 listener-capability refresh qualification.
- No LLM participates in socket capability refresh or carrier negotiation.


## 0.1-dev5

- Added current XTP dev10 native sender+listener capability profile.
- Added `XtpDev10SocketOfferProvider` for dynamic Intention negotiation.
- Retained dev9 sender-only profile for mixed-version deployments.
- XTP listener requests may now select XTP when dev10 capability is advertised.
- Preserved hard multicast endpoint check: family support alone is insufficient.
- Added Intention -> negotiation -> XTP SocketProvider acquisition regression.
- Added direct source-compatibility qualification against supplied XTP dev10 `XtpSocketProvider.cls`.


## 0.1-dev4

- Added role-specific capability overrides to socket negotiation offers.
- Added the historical XTP dev9 Rexx capability profile as it was understood at dev4: sender=yes, listener=no, multicast=yes. **Superseded by dev10 evidence correction:** current executable XTP profiles advertise multicast=no.
- Added XtpDev9SocketOfferProvider convenience adapter.
- Multicast requests now require an actual multicast endpoint, not merely a multicast-capable family.
- Added compatibility qualification against the supplied XTP dev9 provider source.


## 0.1-dev3

- Added `socket.intention/0.1` and `socket.negotiation/0.1`.
- Added dynamic `SocketIntentionPort~discover()`; socket intentions are not cached as a permanent catalogue.
- Added semantic `SocketNegotiationRequest` hard requirements for role, stream, security, multicast, local-only and permitted schemes.
- Added dynamic `SocketOfferProvider`, registered offer provider, deterministic negotiation and rejection evidence.
- Added local/secure/scheme preference policy without allowing preferences to override hard requirements.
- Added `SocketProvider~senderAt()` / `listenerAt()` so negotiated addresses still flow through the single socket acquisition authority.
- Added executable negotiation proofs for Unix preference, TLS secure-family selection, the then-assumed XTP multicast selection, explicit scheme constraints and fail-closed impossible requirements. **Superseded by dev10 evidence correction:** XTP multicast is no longer advertised without implementation evidence.
- Added complete Intention -> negotiation -> SocketProvider acquisition proof.


## 0.1-dev2

- Aligned the provider boundary with the Optimised Queue Transport work: `SocketSelector`, `SocketEndpoint`, `SocketAddress`, and `SocketCapabilities` are now explicit while `SocketProvider` remains the requested standard acquisition authority.
- Split native transport bindings from the core provider so importing the provider does not force RxSock, Unix Socket, TLS/OpenSSL, or future XTP dependencies.
- Added `socket.family/0.1` with explicit schemes/families and capability projection.
- Added `RxSockSocketBinding.cls` as the concrete TCP/INET family using stock `.Socket` / `.InetAddress`.
- Added `UnixSocketBinding.cls` as the AF_UNIX family using the existing ooRexx Unix Socket semantic API.
- Added `TLSSocketFamily.cls` as the complete family example: TLS has its own scheme/family and secure capability, composes a base stream binding, and resolves all key/certificate/trust material through one `SocketSecurityMaterialProvider` using only a security-profile reference carried by the address.
- Retained XTP as an injectable future binding only; no XTP execution claim is made.
- Corrected dev1 abstract-method declarations and qualified the package under the supplied ooRexx 5.3.0 r13196 runtime.

## 0.1-dev12

- Merged the current `oorexx_xtp_v0.1-dev14` `XtpSocketProvider.cls` into the
  common Socket Provider distribution.
- Preserved standard `SocketSelector` sender/listener integration through
  `RexxXtpSocketBinding`.
- Preserved XTP-specific native multipath sender/listener access without adding
  XTP-specific methods to the protocol-neutral SocketProvider API.
- Retained dev14 capability truth: sender/listener/multipath yes; multicast no.
- Added contract and real dev14 local-UDP environment qualification for the
  merged access route.
