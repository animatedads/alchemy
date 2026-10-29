/* ooRexx Social Media v0.1-dev3 — controlled outbound semantics.
 * Intentionally no network, credentials, spend, durable outbox or policy engine.
 * Production systems must inject authoritative policy and a durable dispatcher.
 * Copyright (c) 2026. */

/* Identifies one CMS-approved rendition for one account and social surface.
 * An approvalRef is evidence lineage, never authorisation by itself.
 * Distinct request IDs are needed for intentional reposts and retry decisions. */
::class SocialPublicationRequest public
::method id attribute
::method brandId attribute
::method accountId attribute
::method surface attribute
::method action attribute
::method contentId attribute
::method contentVersion attribute
::method body attribute
::method approvalRef attribute
::method intentionRef attribute
::method narrativeRef attribute
::method parent attribute
::method assetRefs attribute
::method init
  expose id brandId accountId surface action contentId contentVersion body approvalRef intentionRef narrativeRef parent assetRefs
  use strict arg id, brandId, accountId, surface, action, contentId, contentVersion, body, approvalRef, intentionRef, narrativeRef, parent = .nil
  if id == '' | brandId == '' | accountId == '' then raise syntax 93.900 array ('Publication requires request, brand and account IDs')
  if surface == .nil then raise syntax 93.900 array ('Publication requires social surface')
  if action <> 'publish' & action <> 'reply' then raise syntax 93.900 array ('Only ordinary publish/reply supported; advertising and moderation require separate authority')
  if contentId == '' | contentVersion == '' | body == '' then raise syntax 93.900 array ('Publication requires content revision and body')
  if approvalRef == '' | intentionRef == '' | narrativeRef == '' then raise syntax 93.900 array ('Publication requires approval, intention and narrative evidence references')
  if action == 'reply' & parent == .nil then raise syntax 93.900 array ('Reply needs an explicit qualified parent')
  if action == 'publish' & parent <> .nil then raise syntax 93.900 array ('Publish cannot implicitly reply to an item')
  if parent <> .nil then do
    if parent~surface~key <> surface~key then raise syntax 93.900 array ('Cross-surface reply parent denied')
  end
  assetRefs = .array~new
::method addAsset
  expose assetRefs
  use strict arg assetRef
  if assetRef == '' then raise syntax 93.900 array ('Empty asset reference')
  assetRefs~append(assetRef)
  return self
/* Length framing makes concatenated references and text unambiguous.
 * It is an in-memory equality token, NOT a cryptographic digest/signature. */
::method fingerprint
  expose id brandId accountId surface action contentId contentVersion body approvalRef intentionRef narrativeRef parent assetRefs
  all = .array~of(id,brandId,accountId,surface~key,action,contentId,contentVersion,body,approvalRef,intentionRef,narrativeRef)
  if parent == .nil then all~append('')
  else all~append(parent~key)
  all~append(assetRefs~items)
  do a over assetRefs
    all~append(a)
  end
  key = ''
  do part over all
    part = part~string
    key ||= length(part) || ':' || part
  end
  return key
::method context
  expose id brandId accountId surface action contentId contentVersion body approvalRef intentionRef narrativeRef parent assetRefs
  info = .directory~new
  info['requestId'] = id
  info['brandId'] = brandId
  info['accountId'] = accountId
  info['surfaceKey'] = surface~key
  info['providerId'] = surface~providerId
  info['surfaceFamily'] = surface~family
  info['action'] = action
  info['contentId'] = contentId
  info['contentVersion'] = contentVersion
  info['body'] = body
  info['approvalRef'] = approvalRef
  info['intentionRef'] = intentionRef
  info['narrativeRef'] = narrativeRef
  if parent == .nil then info['parentKey'] = ''
  else info['parentKey'] = parent~key
  info['assets'] = assetRefs~copy
  /* Local-only reference, never serialized into the outbox or adapter wire payload.
   * Binds lower-layer execution to the original validated request object. */
  info['requestObject'] = self
  return info

/* A policy adapter MUST verify approval validity, principal/account ownership,
 * surface permissions, audience consent, governing institutional rules, etc.
 * The base library never equates a string approval reference with permission. */
::class SocialPublicationAuthority public
::method allow abstract
::class SocialDenyPublicationAuthority public subclass SocialPublicationAuthority
::method allow
  use strict arg request
  return .false

/* Test-only exact grants. Changes to any relevant field invalidate the grant.
 * Never use this in production: it does not authenticate CMS or policy data. */
::class SocialTestPublicationAuthority public subclass SocialPublicationAuthority
::method grants attribute
::method init
  expose grants
  grants = .directory~new
::method permit
  expose grants
  use strict arg request
  grants[request~id] = request~fingerprint
  return self
::method allow
  expose grants
  use strict arg request
  if \grants~hasIndex(request~id) then return .false
  return grants[request~id] == request~fingerprint

/* Local receipt state must not pretend to be remote publication evidence.
 * 'unknown' blocks automatic re-dispatch until reconciliation. */
::class SocialPublicationReceipt public
::method requestId attribute
::method fingerprint attribute
::method providerId attribute
::method status attribute
::method providerStatus attribute
::method providerEvidence attribute
::method detail attribute
::method context attribute
::method init
  expose requestId fingerprint providerId status providerStatus providerEvidence detail context
  use strict arg request = .nil
  if request == .nil then do
    requestId = ''
    fingerprint = ''
    providerId = ''
    status = ''
    providerStatus = ''
    providerEvidence = ''
    detail = ''
    context = .directory~new
    return
  end
  requestId = request~id
  fingerprint = request~fingerprint
  providerId = request~surface~providerId
  status = 'prepared'
  providerStatus = ''
  providerEvidence = ''
  detail = ''
  context = request~context
::method projection
  expose requestId providerId status providerStatus providerEvidence detail context
  data = .directory~new
  data['schema'] = 'social.outbound.receipt/0.1'
  data['requestId'] = requestId
  data['providerId'] = providerId
  data['status'] = status
  data['providerStatus'] = providerStatus
  data['providerEvidence'] = providerEvidence
  data['detail'] = detail
  data['brandId'] = context['brandId']
  data['contentId'] = context['contentId']
  data['contentVersion'] = context['contentVersion']
  data['intentionRef'] = context['intentionRef']
  data['narrativeRef'] = context['narrativeRef']
  data['approvalRef'] = context['approvalRef']
  data['surfaceKey'] = context['surfaceKey']
  data['accountId'] = context['accountId']
  data['action'] = context['action']
  return data

/* Controller with local single-process replay semantics. No durable guarantee.
 * Every request has two independent checks: publication authority and the
 * provider dispatch policy already owned by SocialLibrary. */
::class SocialPublicationService public
::method library attribute
::method authority attribute
::method receipts attribute
::method trace attribute
::method journal attribute
::method init
  expose library authority receipts trace journal
  use strict arg library, journal = .nil
  if library == .nil then raise syntax 93.900 array ('Missing provider library')
  authority = .SocialDenyPublicationAuthority~new
  receipts = .directory~new
  if journal <> .nil then receipts = journal~replay
  trace = .array~new
::method recordState private
  expose trace journal
  use strict arg receipt, phase
  marker = .directory~new
  marker['requestId'] = receipt~requestId
  marker['phase'] = phase
  marker['providerId'] = receipt~providerId
  if journal <> .nil then journal~save(receipt)
  trace~append(marker)
::method submit
  expose library authority receipts
  use strict arg request
  token = request~fingerprint
  if receipts~hasIndex(request~id) then do
    oldReceipt = receipts[request~id]
    if oldReceipt~fingerprint <> token then raise syntax 93.900 array ('Idempotency key reused with different publication')
    return oldReceipt
  end
  /* Reject before creating an outbox entry or invoking the provider. */
  if \authority~allow(request) then raise syntax 93.900 array ('Publication authority denied')
  caps = library~discover(request~surface~providerId)
  if caps == .nil then raise syntax 93.900 array ('No registered provider for social surface')
  if \caps~hasIndex(request~action) then raise syntax 93.900 array ('Provider operation not available')
  if \caps[request~action]~enabled then raise syntax 93.900 array ('Provider operation disabled')
  ctx = request~context
  if \library~policy~allow(request~action,ctx) then raise syntax 93.900 array ('Provider dispatch policy denied')
  ticket = .SocialPublicationReceipt~new(request)
  /* An acknowledged prepared record precedes in-memory admission. */
  self~recordState(ticket, 'prepared')
  receipts[request~id] = ticket
  ticket~status = 'dispatching'
  self~recordState(ticket, 'dispatching')
  /* An exception can occur after remote side effects. Do not retry blindly. */
  signal on syntax name uncertain
  providerResult = library~execute(request~surface~providerId,request~action,ctx)
  signal off syntax
  if providerResult == .nil then do
    ticket~status = 'unknown'
    ticket~detail = 'Provider returned no receipt; reconciliation required'
  end
  else do
    if \providerResult~isA(.directory) then do
      ticket~status = 'unknown'
      ticket~detail = 'Provider receipt has unsupported shape'
    end
    else do
      if \providerResult~hasIndex('status') then do
        ticket~status = 'unknown'
        ticket~detail = 'Provider receipt missing status'
      end
      else do
        ticket~providerStatus = providerResult['status']
        /* Acknowledgement != delivery. Only explicit provider evidence can
         * progress beyond submission; that is handled by reconcile(). */
        select
          when providerResult['status'] == 'simulated' then ticket~status = 'simulated'
          when providerResult['status'] == 'rejected' then ticket~status = 'rejected'
          when providerResult['status'] == 'accepted' | providerResult['status'] == 'queued' then ticket~status = 'submitted'
          otherwise do
            ticket~status = 'unknown'
            ticket~detail = 'Unrecognised or unverified delivery acknowledgement'
          end
        end
      end
    end
  end
  self~recordState(ticket, ticket~status)
  return ticket
  uncertain:
    signal off syntax
    ticket~status = 'unknown'
    ticket~detail = 'Dispatch error: remote outcome uncertain; reconcile before retry'
    self~recordState(ticket, ticket~status)
    return ticket
/* External verifier must establish binding to request/provider/account and
 * verify remote evidence. A test verifier is not sufficient for production. */
::method reconcile
  expose receipts
  use strict arg requestId, providerStatus, remoteEvidence, verifier
  if \receipts~hasIndex(requestId) then raise syntax 93.900 array ('Unknown publication receipt')
  ticket = receipts[requestId]
  if ticket~status == 'simulated' then raise syntax 93.900 array ('Simulation cannot be reconciled as live delivery')
  if providerStatus <> 'delivered' & providerStatus <> 'rejected' then raise syntax 93.900 array ('Invalid reconciliation outcome')
  if remoteEvidence == '' | verifier == .nil then raise syntax 93.900 array ('Verified external evidence required')
  if \verifier~verify(ticket,providerStatus,remoteEvidence) then raise syntax 93.900 array ('External delivery evidence not verified')
  /* Terminal states are immutable without an explicit correction workflow. */
  if ticket~status == 'delivered' | ticket~status == 'rejected' then raise syntax 93.900 array ('Terminal receipt cannot be overwritten')
  /* Write a separate candidate; a failed journal save must not mutate prior receipt. */
  candidate = .SocialPublicationReceipt~new
  candidate~requestId = ticket~requestId
  candidate~fingerprint = ticket~fingerprint
  candidate~providerId = ticket~providerId
  candidate~context = ticket~context
  candidate~detail = ticket~detail
  candidate~status = providerStatus
  candidate~providerStatus = providerStatus
  candidate~providerEvidence = remoteEvidence
  self~recordState(candidate, 'reconciled:' || providerStatus)
  ticket~status = providerStatus
  ticket~providerStatus = providerStatus
  ticket~providerEvidence = remoteEvidence
  return ticket
::method lookup
  expose receipts
  use strict arg requestId
  if \receipts~hasIndex(requestId) then return .nil
  return receipts[requestId]

/* Only for local tests. A production verifier verifies signed/credentialed
 * remote delivery state and binds it to the exact prior dispatch. */
::class SocialTestDeliveryVerifier public
::method expected attribute
::method init
  expose expected
  expected = .directory~new
::method permit
  expose expected
  use strict arg requestId, status, evidence
  expected[requestId] = status || ':' || evidence
  return self
::method verify
  expose expected
  use strict arg ticket, status, evidence
  if \expected~hasIndex(ticket~requestId) then return .false
  return expected[ticket~requestId] == status || ':' || evidence

/* Brand/effect bridge produces detached evidence, NOT a BrandEffect judgment.
 * Only project interactions already accepted through SocialInboundGate.
 * The caller supplies the gate, not a forgeable receipt-shaped dictionary. */
::class SocialBrandInteractionBridge public
::method projectAccepted
  use strict arg interaction, gate, brandId, intentionRef
  if gate == .nil then raise syntax 93.900 array ('Inbound verification gate required')
  if gate~verifier == .nil then raise syntax 93.900 array ('Inbound verifier not configured')
  if \gate~graph~contains(interaction) then raise syntax 93.900 array ('Interaction missing from accepted conversation graph')
  found = .false
  do gateReceipt over gate~audit
    if gateReceipt['id'] == interaction~key & (gateReceipt['status'] == 'accepted' | gateReceipt['status'] == 'duplicate') then do
      found = .true
      leave
    end
  end
  if \found then raise syntax 93.900 array ('No accepted inbound gate audit entry')
  if brandId == '' | intentionRef == '' then raise syntax 93.900 array ('Brand/intention lineage required')
  item = .directory~new
  item['schema'] = 'social.interaction.evidence/0.1'
  item['brandId'] = brandId
  item['intentionRef'] = intentionRef
  item['interactionKey'] = interaction~key
  item['targetKey'] = interaction~target~key
  item['surfaceKey'] = interaction~target~surface~key
  item['source'] = interaction~source
  item['kind'] = interaction~kind
  item['actor'] = interaction~actor
  item['content'] = interaction~content
  if interaction~parent == .nil then item['parentKey'] = ''
  else item['parentKey'] = interaction~parent~key
  item['verificationState'] = 'accepted_via_inbound_gate'
  item['brandEffect'] = 'not_assessed'
  return item

::requires 'SocialMedia.cls'
