/* Memory Fabric remote READ ingress admission. This is an authority gate,
 * not an XTP listener, serializer, authenticator, or page-data implementation.
 * The transport supplies an authenticated evidence handle; a separately
 * configured authenticator resolves it, and an ACL provider authorizes the
 * resulting identity against the current block and range. Caller-controlled
 * service names, sender labels, or XTP KEYs are never credentials.
 */

::class MemoryXtpReadIntent public
::method init
  expose fabricId blockId generation firstByte endByte pageBytes requestId expiresAtMs
  use strict arg fabricArg,blockArg,generationArg,firstArg,endArg,pageArg,idArg,expiresArg
  numeric digits 20
  fabricId=fabricArg~string~strip; blockId=blockArg~string~strip
  requestId=idArg~string~strip
  if datatype(generationArg,'W')=0 | datatype(firstArg,'W')=0 | datatype(endArg,'W')=0 | datatype(pageArg,'W')=0 | datatype(expiresArg,'W')=0 then
    raise syntax 88.900 array('invalid Memory XTP ingress integer')
  generation=generationArg+0; firstByte=firstArg+0; endByte=endArg+0; pageBytes=pageArg+0; expiresAtMs=expiresArg+0
  if fabricId='' | blockId='' | generation<1 | pageBytes<1 | firstByte<0 | endByte<=firstByte then
    raise syntax 88.900 array('invalid Memory XTP ingress identity/window')
  if firstByte//pageBytes<>0 | endByte//pageBytes<>0 then
    raise syntax 88.900 array('unaligned Memory XTP ingress window')
  if requestId~length<16 | requestId~length>128 | requestId~verify('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_')<>0 then
    raise syntax 88.900 array('invalid Memory XTP ingress request identity')
::attribute fabricId get
::attribute blockId get
::attribute generation get
::attribute firstByte get
::attribute endByte get
::attribute pageBytes get
::attribute requestId get
::attribute expiresAtMs get

::class MemoryXtpReadIngress public
::method init
  expose registry services authenticator acl providerId localPeer maxBytes lifetimeMs seen maxSeen
  use strict arg registryArg,servicesArg,authenticatorArg,aclArg,providerArg,peerArg,maxArg=16777216,lifetimeArg=60000
  numeric digits 20
  if registryArg==.nil | servicesArg==.nil | authenticatorArg==.nil | aclArg==.nil then
    raise syntax 88.900 array('ingress requires registry, service, authenticator and ACL authorities')
  if \authenticatorArg~hasMethod('IDENTITYFOR') | \aclArg~hasMethod('CANREAD') then
    raise syntax 88.900 array('ingress requires authenticating/authorizing providers')
  if datatype(maxArg,'W')=0 | datatype(lifetimeArg,'W')=0 then
    raise syntax 88.900 array('ingress maximum must be whole number')
  maxBytes=maxArg+0; lifetimeMs=lifetimeArg+0
  if maxBytes<1 | lifetimeMs<1 | lifetimeMs>60000 then
    raise syntax 88.900 array('ingress maximum out of bounds')
  registry=registryArg; services=servicesArg; authenticator=authenticatorArg; acl=aclArg
  providerId=providerArg~string~strip; localPeer=peerArg~string~strip
  if providerId='' | localPeer='' then raise syntax 88.900 array('ingress local provider and logical peer mandatory')
  seen=.directory~new; maxSeen=4096
::method admit
  expose seen authenticator maxSeen
  use strict arg intent,serviceName,transportEvidence,nowMs
  numeric digits 20
  /* Bind replay identity to the SAME principal whose ACL is checked.
   * Credential mappings may change between callbacks; fail closed if so. */
  identity=authenticator~identityFor(transportEvidence)
  if identity==.nil then return .nil
  if \identity~isA(.String) then return .nil
  if \self~valid(intent,serviceName,transportEvidence,nowMs,identity) then return .nil
  key=identity||'/'||intent~requestId
  /* A bounded in-process replay guard. This is NOT a durable/restart-proof
   * security ledger and cannot support exactly-once ownership mutation. */
  prior=seen[key]
  if prior<>.nil then
    if prior>=nowMs then return .nil
  if seen~items>=maxSeen then do
    /* Expired IDs are safe to forget. Saturation remains deny-by-default:
     * never evict an active request identity to accept another request. */
    do item over seen~allIndexes
      if seen[item]<nowMs then seen~remove(item)
    end
    if seen~items>=maxSeen then return .nil
  end
  seen[key]=intent~expiresAtMs
  return .MemoryXtpReadPermit~new(self,intent,serviceName,transportEvidence,identity)
::method valid
  expose registry services authenticator acl providerId localPeer maxBytes lifetimeMs
  use strict arg intent,serviceName,transportEvidence,nowMs,expectedIdentity
  numeric digits 20
  if intent==.nil then return .false
  if \intent~isA(.MemoryXtpReadIntent) then return .false
  if datatype(nowMs,'W')=0 then return .false
  now=nowMs+0
  if now<0 | intent~expiresAtMs<now | intent~expiresAtMs>now+lifetimeMs then return .false
  if intent~fabricId<>registry~fabricId then return .false
  if intent~endByte-intent~firstByte>maxBytes then return .false
  d=services~resolve(serviceName)
  if d==.nil then return .false
  if d~routePeer<>localPeer | d~operationalClass<>'normal.memory' then return .false
  identity=authenticator~identityFor(transportEvidence)
  if identity==.nil then return .false
  if \identity~isA(.String) then return .false
  if identity~strip='' then return .false
  if expectedIdentity<>.nil then
    if identity<>expectedIdentity then return .false
  block=registry~resolveBlock(intent~blockId,intent~generation)
  if block==.nil then return .false
  if block~providerId<>providerId then return .false
  if intent~endByte>block~length then return .false
  provider=registry~provider(providerId)
  if provider==.nil then return .false
  if provider~providerState<>'ACTIVE' & provider~providerState<>'DRAINING' then return .false
  if provider~membershipEpoch<>block~ownerEpoch then return .false
  /* No remote ACL shortcut via an offered evidence ID. Exact true only. */
  return acl~canRead(identity,intent,block,provider)==.true

::class MemoryXtpReadPermit public
::method init
  expose gate intent serviceName proof identity
  use strict arg gateArg,intentArg,serviceArg,proofArg,identityArg
  gate=gateArg; intent=intentArg; serviceName=serviceArg; proof=proofArg; identity=identityArg
::attribute identity get
::attribute requestId get
  expose intent
  return intent~requestId
::method validatePage
  expose gate intent serviceName proof identity
  use strict arg offsetArg,lengthArg,nowMs
  numeric digits 20
  if datatype(offsetArg,'W')=0 | datatype(lengthArg,'W')=0 then return .false
  offset=offsetArg+0; length=lengthArg+0
  if length<>intent~pageBytes then return .false
  if offset<intent~firstByte | offset+length>intent~endByte then return .false
  if offset//intent~pageBytes<>0 then return .false
  /* Invoke before EACH page read and again before publishing its bytes.
   * Admission is not itself a lease or an immutable data snapshot. */
  return gate~valid(intent,serviceName,proof,nowMs,identity)
