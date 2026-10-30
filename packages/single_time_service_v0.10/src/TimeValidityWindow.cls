/* Single Time Service v0.10 - uncertainty-aware validity intervals.
 * Pure ooRexx domain objects; no system clock, network, TLS validation,
 * ConnectSelector, LDAP, transport or queue dependency. The caller must
 * independently validate and authorise the clock source and credential.
 */
::class 'TimeClockInterval' public
::method init
  expose lower upper sourceId authorityState
  use strict arg lower, upper, sourceId, authorityState = 'UNVERIFIED'
  numeric digits 30
  if \datatype(lower,'W') | \datatype(upper,'W') then raise syntax 93.900 array ('integer UTC/POSIX bounds required')
  if lower > upper then raise syntax 93.900 array ('lower clock bound exceeds upper bound')
  if sourceId == '' | sourceId~length > 128 then raise syntax 93.900 array ('bounded clock source id required')
  if authorityState \== 'UNVERIFIED' & authorityState \== 'POLICY_AUTHORISED' then
    raise syntax 93.900 array ('unsupported clock authority state')
  self~lower = lower
  self~upper = upper
  self~sourceId = sourceId
  self~authorityState = authorityState
::attribute lower get
::attribute upper get
::attribute sourceId get
::attribute authorityState get

::class 'TimeValidityWindow' public
::method assess
  use strict arg notBefore, notAfter, clock
  numeric digits 30
  if \datatype(notBefore,'W') | \datatype(notAfter,'W') then
    raise syntax 93.900 array ('integer validity bounds required')
  if notAfter <= notBefore then raise syntax 93.900 array ('empty or inverted validity period')
  if \clock~isA(.TimeClockInterval) then raise syntax 93.900 array ('TimeClockInterval required')
  result = .directory~new
  result['schema'] = 'single.time.validity/0.1'
  result['notBeforePosix'] = notBefore
  result['notAfterExclusivePosix'] = notAfter
  result['clockLowerPosix'] = clock~lower
  result['clockUpperPosix'] = clock~upper
  result['clockSourceId'] = clock~sourceId
  result['clockAuthorityState'] = clock~authorityState
  result['isCertificateValidation'] = .false
  result['authorisesUse'] = .false
  select
    when clock~upper < notBefore then result['status'] = 'DEFINITELY_TOO_EARLY'
    when clock~lower >= notAfter then result['status'] = 'DEFINITELY_EXPIRED'
    when clock~lower >= notBefore & clock~upper < notAfter then result['status'] = 'INSIDE_TIME_WINDOW'
    otherwise result['status'] = 'INDETERMINATE'
  end
  /* A mathematically inside interval is not authentication or chain trust. */
  result['timeCriterionSatisfied'] = (result['status'] == 'INSIDE_TIME_WINDOW' &,
     clock~authorityState == 'POLICY_AUTHORISED')
  return result
