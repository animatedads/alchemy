/* Social Media v0.1-dev5: account-and-surface-specific publication admission.
 * This is a semantic capability boundary, not a platform API or an authority
 * to publish. Institutional/brand approval and SocialLibrary policy are still
 * independently required by SocialPublicationService.
 *
 * The resolver is called afresh for EVERY submit. A cached or local-test
 * resolver is insufficient for live capability freshness and revocation.
 */

/* Immutable capability offer for one specific provider/account/surface/action.
 * Limits are local mechanical constraints, NOT platform validation rules.
 * Revision and evidence identify an observed capability; they are not grants.
 */
::class SocialScopedCapability public
::method init
  expose providerId accountId surfaceKey action revision evidence active maxBodyBytes maxAssets
  use strict arg providerId, accountId, surfaceKey, action, revision, evidence, active, maxBodyBytes, maxAssets
  if providerId == '' | accountId == '' | surfaceKey == '' | action == '' then raise syntax 93.900 array ('Scoped capability identity missing')
  if revision == '' | evidence == '' then raise syntax 93.900 array ('Capability requires revision and discovery evidence')
  if \datatype(maxBodyBytes, 'W') | \datatype(maxAssets, 'W') then raise syntax 93.900 array ('Capability limits must be integers')
  if maxBodyBytes < 1 | maxAssets < 0 then raise syntax 93.900 array ('Invalid capability limit')
  if active <> .true & active <> .false then raise syntax 93.900 array ('Capability active must be Boolean')
::method providerId
  expose providerId
  return providerId
::method accountId
  expose accountId
  return accountId
::method surfaceKey
  expose surfaceKey
  return surfaceKey
::method action
  expose action
  return action
::method revision
  expose revision
  return revision
::method evidence
  expose evidence
  return evidence
::method active
  expose active
  return active
::method maxBodyBytes
  expose maxBodyBytes
  return maxBodyBytes
::method maxAssets
  expose maxAssets
  return maxAssets

/* Production implementations resolve current authorized account/surface
 * capability via their provider/identity policy, without leaking credentials.
 * Return .nil for stale, revoked or unknown capabilities. */
::class SocialScopedCapabilityResolver public
::method resolve abstract
::class SocialDenyScopedResolver public subclass SocialScopedCapabilityResolver
::method resolve
  use strict arg request
  return .nil

/* TEST-ONLY mutable resolver for negative and revocation regression tests.
 * Never use as live provider evidence. */
::class SocialTestScopedResolver public subclass SocialScopedCapabilityResolver
::method offers attribute
::method init
  expose offers
  offers = .directory~new
::method key private
  use strict arg providerId, accountId, surfaceKey, action
  return length(providerId) || ':' || providerId || length(accountId) || ':' || accountId || -
         length(surfaceKey) || ':' || surfaceKey || length(action) || ':' || action
::method install
  expose offers
  use strict arg offer
  key = self~key(offer~providerId,offer~accountId,offer~surfaceKey,offer~action)
  offers[key] = offer
  return self
::method revoke
  expose offers
  use strict arg offer
  key = self~key(offer~providerId,offer~accountId,offer~surfaceKey,offer~action)
  if offers~hasIndex(key) then offers~remove(key)
  return self
::method resolve
  expose offers
  use strict arg request
  key = self~key(request~surface~providerId,request~accountId,request~surface~key,request~action)
  if \offers~hasIndex(key) then return .nil
  return offers[key]

/* No inference from provider-wide capabilities, or from the name of a surface.
 * Exact-scoped current offer is necessary, but is NEVER sufficient to post:
 * the inner service also verifies brand/policy and provider-wide capability. */
::class SocialScopedCapabilityGate public
::method resolver attribute
::method init
  expose resolver
  use strict arg resolver = .nil
  if resolver == .nil then resolver = .SocialDenyScopedResolver~new
::method check
  expose resolver
  use strict arg request
  offer = resolver~resolve(request)
  if offer == .nil then raise syntax 93.900 array ('No current account/surface capability')
  if \offer~isA(.SocialScopedCapability) then raise syntax 93.900 array ('Invalid capability object')
  if offer~providerId <> request~surface~providerId then raise syntax 93.900 array ('Provider capability mismatch')
  if offer~accountId <> request~accountId then raise syntax 93.900 array ('Account capability mismatch')
  if offer~surfaceKey <> request~surface~key then raise syntax 93.900 array ('Surface capability mismatch')
  if offer~action <> request~action then raise syntax 93.900 array ('Operation capability mismatch')
  if offer~active <> .true then raise syntax 93.900 array ('Scoped capability disabled')
  if length(request~body) > offer~maxBodyBytes then raise syntax 93.900 array ('Content exceeds scoped byte limit')
  if request~assetRefs~items > offer~maxAssets then raise syntax 93.900 array ('Assets exceed scoped count limit')
  return offer

/* Opt-in strict facade. All existing dev4 APIs remain byte-for-byte unchanged.
 * Application must keep the unguarded inner service private. A live resolver
 * must recheck provider permissions; a test resolver supplies NO such proof.
 * Dispatch still goes via SocialPublicationService and its distinct authority,
 * SocialLibrary policy, and optional outbox journal.
 */
::class SocialScopedPublicationService public
::method authority attribute
::method init
  expose inner gate authority
  use strict arg library, journal = .nil, resolver = .nil
  inner = .SocialPublicationService~new(library, journal)
  gate = .SocialScopedCapabilityGate~new(resolver)
  authority = .SocialDenyPublicationAuthority~new
::method submit
  expose inner gate authority
  use strict arg request
  /* Replayed requests do not produce a new remote dispatch. Preserve the
   * dev4 idempotency rule without allowing stale capabilities to repost. */
  old = inner~lookup(request~id)
  if old <> .nil then do
    if old~fingerprint <> request~fingerprint then raise syntax 93.900 array ('Publication ID reused with altered payload')
    return old
  end
  snapshot = gate~check(request)
  inner~authority = authority
  return inner~submit(request)
::method lookup
  expose inner
  use strict arg requestId
  return inner~lookup(requestId)
::method reconcile
  expose inner
  use strict arg requestId, providerStatus, remoteEvidence, verifier
  return inner~reconcile(requestId,providerStatus,remoteEvidence,verifier)

::requires 'SocialPublication.cls'
