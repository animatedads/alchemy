/* ConnectSelector authenticated interconnect policy.
 * This wraps an explicit route policy; it does not authenticate by trusting
 * application-provided intention metadata. A separately supplied platform
 * authority must validate LDAP identity + endpoint security at the boundary.
 * Safe without a live connection: a missing, false or faulting attestor denies.
 */
::class ConnectAuthenticatedRoutePolicy public
::method init
  expose routes authority secured
  use strict arg routes, authority
  if \routes~hasMethod('permitted') then
    raise syntax 93.900 additional('routes must implement permitted(intent,provider)')
  if \authority~hasMethod('authorizeRoute') then
    raise syntax 93.900 additional('authority must implement authorizeRoute(intent,provider)')
  secured = .Table~new
::method requireAuthenticated
  expose secured
  use strict arg destination, provider
  if destination == '' then raise syntax 93.900 additional('authenticated route destination required')
  provider = provider~string~translate
  if provider \== 'RPC' then do
    if provider \== 'QUEUE' then do
      if provider \== 'RTO2' then do
        if provider \== 'DIRECT' then
          raise syntax 93.900 additional('unsupported route provider')
      end
    end
  end
  secured[destination~string~translate || '|' || provider] = .true
  return self
::method permitted
  expose routes authority secured
  use strict arg intention, provider
  /* Exact route ACL is authoritative regardless of attestation. */
  if \routes~permitted(intention,provider) then return .false
  /* All remote providers are protected by default; DIRECT is local. */
  provider = provider~string~translate
  requiresProof = provider == 'RPC' | provider == 'QUEUE' | provider == 'RTO2'
  if \requiresProof then do
    if \secured~hasIndex(intention~destination~string~translate || '|' || provider) then return .true
  end
  /* Calling the attestor must not grant rights when it faults or returns nil. */
  signal on syntax name authorityFault
  signal on error name authorityFault
  admitted = authority~authorizeRoute(intention,provider)
  signal off syntax
  signal off error
  if admitted == .true then return .true
  return .false
authorityFault:
  /* Announce only redacted diagnostic presence; not identity/secret text. */
  say 'ConnectSelector route authority fault' rc sigl condition('C') 'detail-redacted=' (condition('D') \== '')
  ignoredDetail = condition('D')
  signal off syntax
  signal off error
  return .false
::requires 'ConnectSelector.cls'
