/* XtpProvisionLdapResolver.cls
 * LDAP Identity admission adapter for XTP xtp.provision sessions.
 *
 * Architecture: Tom Dyer.
 * Coding: ChatGPT (GPT-5.6 Sol), 29 October 2026.
 *
 * This object never accepts a caller-supplied principal.  It resolves the
 * cryptographically established XTP KEYID against current Identity Directory
 * key ownership, lifecycle and ACL state.  It deliberately returns only
 * identity/admission evidence; it neither opens XTP routes nor mutates them.
 */

::class XtpProvisionLdapResolver public

::method init
  expose directory resourceId action serviceName
  use strict arg directoryArg, resourceIdArg = 'resource:xtp.provision', actionArg = 'XTP_PROVISION', serviceNameArg = 'xtp.provision'
  if directoryArg == .nil then raise syntax 93.900 array('Identity Directory is required')
  if \directoryArg~hasMethod('ENTRYBYID') then raise syntax 93.900 array('Identity Directory entryById API is required')
  if \directoryArg~hasMethod('ENTRIESOFKIND') then raise syntax 93.900 array('Identity Directory entriesOfKind API is required')
  if \directoryArg~hasMethod('ACLDECISION') then raise syntax 93.900 array('Identity Directory aclDecision API is required')
  directory = directoryArg
  resourceId = resourceIdArg~string~strip
  action = actionArg~string~strip~upper
  serviceName = serviceNameArg~string~strip
  if resourceId = '' then raise syntax 93.900 array('resourceId is required')
  if action = '' then raise syntax 93.900 array('action is required')
  if serviceName = '' then raise syntax 93.900 array('serviceName is required')

::method denied private
  use strict arg reason, keyId = ''
  verdict = .directory~new
  verdict['OK'] = .false
  verdict['EXCLUSIVE'] = .false
  verdict['KEYID'] = keyId
  verdict['AUTHORITY'] = 'LDAP'
  verdict['FENCED'] = .false
  verdict['REASON'] = reason
  return verdict

::method resolveSession
  expose directory resourceId action serviceName
  use strict arg info

  if info == .nil then return self~denied('SESSION_INFO_REQUIRED')
  if \info~isInstanceOf(.directory) then return self~denied('SESSION_INFO_REQUIRED')
  if \info~hasIndex('SERVICE') then return self~denied('SERVICE_MISSING')
  if info['SERVICE'] <> serviceName then return self~denied('SERVICE_MISMATCH')
  if \info~hasIndex('OPEN') then return self~denied('SESSION_NOT_OPEN')
  if info['OPEN'] <> '1' then return self~denied('SESSION_NOT_OPEN')
  if \info~hasIndex('PROTECTION') then return self~denied('ENCRYPTION_REQUIRED')
  if info['PROTECTION'] <> 'encrypt' then return self~denied('ENCRYPTION_REQUIRED')
  if \info~hasIndex('KEYID') then return self~denied('KEY_ID_REQUIRED')

  keyId = info['KEYID']~string
  if keyId~length <> 16 then return self~denied('KEY_ID_INVALID', keyId)
  if keyId~verify('0123456789ABCDEFabcdef') <> 0 then return self~denied('KEY_ID_INVALID', keyId)
  if keyId = '0000000000000000' then return self~denied('KEY_ID_INVALID', keyId)
  normalizedKeyId = keyId~lower

  /* The directory revision is the local revocation/ACL fence.  It is not a
   * cluster election epoch.  A mutation while this decision is being formed
   * invalidates the decision and forces the caller to retry. */
  fenceRevision = directory~revision
  servicePrincipalId = 'service:' || serviceName
  servicePrincipal = directory~entryById(servicePrincipalId)
  if \self~activePrincipal(servicePrincipal, 'SERVICE') then return self~denied('SERVICE_PRINCIPAL_INACTIVE', keyId)

  resource = directory~entryById(resourceId)
  if resource == .nil then return self~denied('RESOURCE_MISSING', keyId)
  if resource~kind <> 'RESOURCE' then return self~denied('RESOURCE_MISSING', keyId)
  if resource~state <> 'ACTIVE' then return self~denied('RESOURCE_INACTIVE', keyId)

  now = .DateTime~new
  bindingCount = 0
  accepted = .nil
  clientPrefix = servicePrincipalId || '/client:'

  do generation over directory~entriesOfKind('KEYGEN')
    if generation~publicMaterial~lower <> normalizedKeyId then iterate
    if generation~state <> 'ACTIVE' then do
      if generation~state <> 'RETIRING' then iterate
    end
    if \generation~validAt(now) then iterate

    keySet = directory~entryById(generation~keySetId)
    if keySet == .nil then iterate
    if keySet~kind <> 'KEYSET' then iterate
    if keySet~state <> 'ACTIVE' then iterate
    if keySet~usage <> 'XTP_ENCRYPT' then iterate

    ownerId = keySet~ownerId
    /* A service-wide key is intentionally counted as a binding conflict.  It
     * may encrypt the service, but cannot prove which MI opened the session. */
    if ownerId = servicePrincipalId then do
      bindingCount += 1
      iterate
    end
    if ownerId~left(clientPrefix~length) <> clientPrefix then iterate
    miPrincipalId = ownerId~substr(clientPrefix~length + 1)
    if \self~validMiPrincipalId(miPrincipalId) then do
      bindingCount += 1
      iterate
    end

    bindingCount += 1

    clientPrincipal = directory~entryById(ownerId)
    if \self~activePrincipal(clientPrincipal) then iterate
    if \self~isUnder(clientPrincipal~dn, servicePrincipal~dn) then iterate
    if \self~isUnder(keySet~dn, clientPrincipal~dn) then iterate
    if self~parentOf(generation~dn) <> keySet~dn~lower then iterate

    if generation~state = 'ACTIVE' then do
      if keySet~activeGenerationId <> generation~entityId then iterate
    end

    miPrincipal = directory~entryById(miPrincipalId)
    if \self~activeMiPrincipal(miPrincipal) then iterate

    access = directory~aclDecision(miPrincipalId, resourceId, action)
    if \access~ok then iterate

    candidate = .directory~new
    candidate['PRINCIPAL'] = miPrincipalId
    candidate['KEYSET'] = keySet~entityId
    candidate['KEYGEN'] = generation~entityId
    candidate['GENERATION_STATE'] = generation~state
    accepted = candidate
  end

  if directory~revision <> fenceRevision then return self~denied('DIRECTORY_CHANGED', keyId)
  if bindingCount = 0 then return self~denied('KEY_UNBOUND', keyId)
  if bindingCount <> 1 then return self~denied('KEY_NOT_EXCLUSIVE', keyId)
  if accepted == .nil then return self~denied('KEY_BINDING_DENIED', keyId)

  verdict = .directory~new
  verdict['OK'] = .true
  verdict['EXCLUSIVE'] = .true
  verdict['KEYID'] = keyId
  verdict['SERVICE'] = serviceName
  verdict['PRINCIPAL'] = accepted['PRINCIPAL']
  verdict['AUTHORITY'] = 'LDAP'
  verdict['FENCED'] = .true
  verdict['FENCE_REVISION'] = fenceRevision
  verdict['KEYSET'] = accepted['KEYSET']
  verdict['KEYGEN'] = accepted['KEYGEN']
  verdict['GENERATION_STATE'] = accepted['GENERATION_STATE']
  verdict['REASON'] = 'ADMITTED'
  return verdict

::method activePrincipal private
  use strict arg principal, requiredType = ''
  if principal == .nil then return .false
  if principal~kind <> 'PRINCIPAL' then return .false
  if principal~state <> 'ACTIVE' then return .false
  if requiredType <> '' then do
    if principal~principalType <> requiredType then return .false
  end
  return .true

::method activeMiPrincipal private
  use strict arg principal
  if \self~activePrincipal(principal) then return .false
  if principal~principalType = 'NODE' then return .true
  if principal~principalType = 'WORKLOAD' then return .true
  return .false

::method validMiPrincipalId private
  use strict arg principalId
  if principalId~length < 4 then return .false
  if principalId~length > 128 then return .false
  if principalId~left(3) <> 'mi:' then return .false
  if principalId~verify('abcdefghijklmnopqrstuvwxyz0123456789._:-') <> 0 then return .false
  return .true

::method parentOf private
  use strict arg dn
  p = dn~pos(',')
  if p = 0 then return ''
  return dn~substr(p + 1)~lower

::method isUnder private
  use strict arg dn, parentDn
  if parentDn = '' then return .false
  child = dn~lower
  parent = parentDn~lower
  tail = ',' || parent
  if child~length <= tail~length then return .false
  return child~right(tail~length) = tail

::requires 'IdentityDirectory.cls'
