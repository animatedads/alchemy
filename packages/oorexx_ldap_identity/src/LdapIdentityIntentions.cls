/* LdapIdentityIntentions.cls - dynamic Intention Service bridge for Identity Directory.
 *
 * Meaning discovery is refreshed by IntentionService before every fresh input.
 * This adapter never turns recognition into authority: dispatch is delegated to
 * an injected operations object and the supplied directory adapter is READ ONLY.
 */

::class LdapIdentityIntentionBuild public
::constant API_VERSION "identity.intention.discovery/0.1"
::constant SOURCE "LDAP_IDENTITY"
::constant READ_BUCKET "LDAP_IDENTITY_READ"

::class IdentityIntentionOperationDescriptor public
::attribute intentionId get
::attribute phrase get
::attribute aliases get
::attribute sideEffectClass get
::attribute available get
::method init
  expose intentionId phrase aliases sideEffectClass available
  use strict arg phraseArg, aliasesArg = (.array~new), sideEffectClassArg = "READ", availableArg = .true
  phrase=strip(phraseArg); intentionId=translate(phrase); intentionId=changestr(" ",intentionId,"_")
  aliases=.array~new; aliases~append(phrase)
  do a over aliasesArg; if strip(a)<>"" then aliases~append(strip(a)); end
  sideEffectClass=translate(strip(sideEffectClassArg)); if sideEffectClass="" then sideEffectClass="READ"
  available=availableArg

::class IdentityIntentionOperations public
::method apiVersion
  return .LdapIdentityIntentionBuild~API_VERSION
::method sourceId abstract
::method revision abstract
::method descriptors abstract
::method invoke abstract
::method evidence
  return .array~new

/* Safe reference adapter.  It intentionally exposes only observation.  Any
 * administrative/mutating surface must be supplied by a separate operations
 * provider which performs its own authorization and policy checks. */
::class DirectoryIdentityReadIntentionOperations subclass IdentityIntentionOperations public
::method init
  expose directory
  use strict arg directoryArg
  if directoryArg==.nil then raise syntax 88.900 array("identity intention directory required")
  directory=directoryArg
::method sourceId
  expose directory
  return .LdapIdentityIntentionBuild~SOURCE || ":" || directory~peerId
::method revision
  expose directory
  return directory~peerId || ":" || directory~revision
::method descriptors
  out=.array~new
  out~append(.IdentityIntentionOperationDescriptor~new("show identity directory status",.array~of("show ldap status","identity directory status")))
  out~append(.IdentityIntentionOperationDescriptor~new("list identity directory entries",.array~of("list ldap entries","list identities")))
  out~append(.IdentityIntentionOperationDescriptor~new("find identity directory entry",.array~of("find ldap entry","find identity")))
  return out
::method evidence
  expose directory
  out=.array~new
  entries=directory~allEntries
  out~append(.IntentionEvidenceFact~new("LDAP_IDENTITY","PEER_ID",directory~peerId,100,self~sourceId,"OBSERVED",self~revision))
  out~append(.IntentionEvidenceFact~new("LDAP_IDENTITY","REVISION",directory~revision,100,self~sourceId,"OBSERVED",self~revision))
  out~append(.IntentionEvidenceFact~new("LDAP_IDENTITY","ENTRY_COUNT",entries~items,100,self~sourceId,"OBSERVED",self~revision))
  return out
::method invoke
  expose directory
  use strict arg intentionId, decision
  id=translate(strip(intentionId))
  if id="SHOW_IDENTITY_DIRECTORY_STATUS" then do
    d=.directory~new
    d["peerId"]=directory~peerId; d["revision"]=directory~revision; d["entryCount"]=directory~allEntries~items
    d["principalCount"]=directory~entriesOfKind("PRINCIPAL")~items
    d["groupCount"]=directory~entriesOfKind("GROUP")~items
    d["resourceCount"]=directory~entriesOfKind("RESOURCE")~items
    return .DirectoryResult~success(d,"IDENTITY_DIRECTORY_STATUS")
  end
  if id="LIST_IDENTITY_DIRECTORY_ENTRIES" then return .DirectoryResult~success(directory~allEntries,"IDENTITY_DIRECTORY_ENTRIES")
  if id="FIND_IDENTITY_DIRECTORY_ENTRY" then do
    slot=decision~slots~at("IDENTIFIER")
    if slot==.nil then return .DirectoryResult~failure("IDENTIFIER_REQUIRED")
    key=strip(slot~value)
    entry=directory~entryById(key)
    if entry==.nil then entry=directory~entryByDn(key)
    if entry==.nil then return .DirectoryResult~failure("IDENTITY_ENTRY_NOT_FOUND",key)
    return .DirectoryResult~success(entry,"IDENTITY_ENTRY_FOUND")
  end
  return .DirectoryResult~failure("IDENTITY_INTENTION_UNSUPPORTED",id)

::class LdapIdentityIntentionEvent public
::method init
  expose operations intentionId
  use strict arg operationsArg, intentionIdArg
  operations=operationsArg; intentionId=intentionIdArg~string
::method currentlyAvailable private
  expose operations intentionId
  do descriptor over operations~descriptors
    if descriptor~intentionId=intentionId then return descriptor~available
  end
  return .false
::method invoke
  expose operations intentionId
  use strict arg decision
  /* Re-check the live operations provider at dispatch time.  A registration is
   * merely vocabulary; it must not preserve execution authority after a
   * dynamically discovered capability disappears. */
  if \self~currentlyAvailable then return .DirectoryResult~failure("IDENTITY_INTENTION_NOT_CURRENTLY_AVAILABLE",intentionId)
  return operations~invoke(intentionId,decision)

/* Proposals come only from the currently discovered surface.  The surface is
 * replaced on every discovery refresh, so an operation that disappears from
 * the provider cannot remain executable merely because it was once known. */
::class LdapIdentityIntentionSurfaceProvider public
::method init
  expose descriptors evidenceFacts
  use strict arg descriptorsArg, evidenceFactsArg
  descriptors=descriptorsArg; evidenceFacts=evidenceFactsArg
::method name
  return "LDAP_IDENTITY_DISCOVERY"
::method normalize private
  use strict arg text
  return translate(space(strip(text)))
::method propose
  expose descriptors evidenceFacts
  use strict arg service, text
  input=self~normalize(text); out=.array~new
  do descriptor over descriptors
    if \descriptor~available then iterate
    matched=.false; score=0
    do alias over descriptor~aliases
      a=self~normalize(alias)
      if input=a then do; matched=.true; score=100; leave; end
      if pos(a,input)>0 then do; matched=.true; if score<92 then score=92; end
    end
    if \matched then iterate
    if service~registration(descriptor~intentionId)==.nil then iterate
    p=.IntentionProposal~new(descriptor~intentionId,score,self~name,.true,"current LDAP identity discovery surface")
    if descriptor~intentionId="FIND_IDENTITY_DIRECTORY_ENTRY" then do
      marker="FIND IDENTITY DIRECTORY ENTRY "
      if left(input,length(marker))=marker then p~putSlot("IDENTIFIER",strip(substr(text,length(marker)+1)),.true)
      else do
        marker="FIND LDAP ENTRY "
        if left(input,length(marker))=marker then p~putSlot("IDENTIFIER",strip(substr(text,length(marker)+1)),.true)
      end
    end
    do fact over evidenceFacts; p~addEvidenceFact(fact); end
    out~append(p)
  end
  return out

::class LdapIdentityIntentionDiscoveryProvider public
::method init
  expose operations
  use strict arg operationsArg
  if operationsArg==.nil then raise syntax 88.900 array("identity intention operations required")
  operations=operationsArg
::method discover
  expose operations
  use strict arg service
  revision=operations~revision
  snapshot=.IntentionDiscoverySnapshot~new(operations~sourceId,revision)
  facts=operations~evidence
  do fact over facts; snapshot~addEvidenceFact(fact); end
  descriptors=operations~descriptors
  active=.array~new
  do d over descriptors; if d~available then active~append(d); end
  surface=.LdapIdentityIntentionSurfaceProvider~new(active,facts)
  metadata=.directory~new; metadata["apiVersion"]=operations~apiVersion; metadata["operationCount"]=active~items
  snapshot~addSurfaceAdvertisement(.IntentionSurfaceAdvertisement~new("LDAP_IDENTITY",surface,operations~sourceId,"IDENTITY_DIRECTORY","LDAP","DISCOVERY","ADVISORY",metadata))
  return snapshot

::class LdapIdentityIntentionInstaller public
::method install class
  use strict arg service, operations
  if service==.nil | operations==.nil then raise syntax 88.900 array("intention service and operations required")
  if service~bucket(.LdapIdentityIntentionBuild~READ_BUCKET)==.nil then service~registerBucket(.LdapIdentityIntentionBuild~READ_BUCKET,.IntentionBucketPolicy~new("EXPLICIT",80,8,.false,.false))
  do descriptor over operations~descriptors
    reg=service~registration(descriptor~intentionId)
    if reg==.nil then do
      reg=service~register(descriptor~phrase,.LdapIdentityIntentionEvent~new(operations,descriptor~intentionId),.LdapIdentityIntentionBuild~READ_BUCKET)
      do alias over descriptor~aliases; if translate(strip(alias))<>translate(strip(descriptor~phrase)) then reg~alias(alias); end
      reg~tag("DOMAIN","LDAP_IDENTITY")~tag("SIDE_EFFECT_CLASS",descriptor~sideEffectClass)
      if descriptor~intentionId="FIND_IDENTITY_DIRECTORY_ENTRY" then reg~requireSlot("IDENTIFIER","Which identity entry (entity id or DN)?",.true)
    end
  end
  service~registerDiscoveryProvider(.LdapIdentityIntentionDiscoveryProvider~new(operations))
  return service

::requires "src/IdentityDirectory.cls"
::requires "IntentionService.cls"
::requires "IntentionContext.cls"
