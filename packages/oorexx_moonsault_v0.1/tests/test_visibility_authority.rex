/* Moonsault visibility authority regression (overcast/night integration).
 * This tests the PREDICTION provider contract only. Actual weather, visible
 * pixels, and heading fixes are strictly SLAM-owned, not modelled here.
 * Requires ooRexx 5.3 and rxmath, with src/ in the requires search path.
 */
numeric digits 17
cases = .array~new
/* Day: sunlight above horizon. */
cases~append(.array~of('2026-11-02T00:00:00Z',-33.8688,151.2093,'DAY'))
/* Sydney night: Moon up, illuminated, and geometrically eligible. */
cases~append(.array~of('2026-11-18T12:00:00Z',-33.8688,151.2093,'MOON_NIGHT'))
/* Sydney night: Moon below horizon; candidate must be rejected. */
cases~append(.array~of('2026-11-02T12:16:00Z',-33.8688,151.2093,'MOON_DOWN'))
checks = 0
do sample over cases
  result = .MoonsaultEphemeris~sunMoon(sample[1],sample[2],sample[3])
  call assert result['status'] == 'PREDICTION_ONLY', 'provider status'
  call assert result['observationIndependent'] == .false, 'not an observation'
  call assert result['skyObservationStatus'] == 'NOT_OBSERVED', 'no observed sky'
  call assert result['visibilityBasis'] == 'GEOMETRIC_EPHEMERIS_ONLY', 'geometry only'
  call assert result['cloudCoverStatus'] == 'UNKNOWN', 'no cloud observation'
  do bodyName over .array~of('sun','moon')
    body = result[bodyName]
    call assert body['observationStatus'] == 'NOT_OBSERVED', bodyName 'no observation'
    call assert body['observedVisibility'] == 'UNKNOWN', bodyName 'not camera visible'
    call assert body['visibilityBasis'] == 'GEOMETRIC_EPHEMERIS_ONLY', bodyName 'geometry'
    call assert body['cloudCoverStatus'] == 'UNKNOWN', bodyName 'cloud unknown'
    checks += 4
  end
  select
    when sample[4] == 'DAY' then
      call assert result['sun']['aboveHorizon'], 'daytime Sun above horizon'
    when sample[4] == 'MOON_NIGHT' then
      call assert result['moon']['visibilityCandidate'], 'night Moon geometric candidate'
    when sample[4] == 'MOON_DOWN' then
      call assert \result['moon']['visibilityCandidate'], 'Moon under horizon'
    otherwise
      say 'FAIL unknown case' sample[4]
      exit 2
  end
  checks += 6
end
say 'MOONSAULT VISIBILITY AUTHORITY PASS:' cases~items 'time cases,' checks 'checks; zero observed claims'
exit 0
assert: procedure
  use arg ok, reason
  if \ok then do
    say 'FAIL' reason
    exit 2
  end
  return
::requires 'MoonsaultEphemeris.cls'
