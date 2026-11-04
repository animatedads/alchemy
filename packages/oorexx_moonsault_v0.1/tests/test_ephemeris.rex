/* Independent reference (Swiss Ephemeris 2.10.03, topocentric, 1010 hPa 10 C)
 * 2026 coordinates from swe.calc_ut(FLG_EQUATORIAL|FLG_TOPOCTR), swe.azalt().
 * Regression tolerance 0.10 deg Sun, 0.30 deg Moon, not navigation accuracy.
 */
numeric digits 17
pass = 0
c = .array~new
c~append(.array~of('2026-11-02T12:16:00Z',-33.8688,151.2093,-37.4581,205.4696,-37.7869,95.2183))
c~append(.array~of('2026-11-01T19:58:00Z',-33.8688,151.2093,12.0140,99.6754,35.8753,0.2047))
c~append(.array~of('2026-11-02T00:00:00Z',-33.8688,151.2093,60.5805,55.3264,12.7443,304.0368))
c~append(.array~of('2026-11-04T12:00:00Z',51.5074,-0.1278,22.9402,184.1675,22.0778,246.2722))
c~append(.array~of('2026-06-21T12:00:00Z',51.5074,-0.1278,61.9257,178.8649,2.0568,93.6977))
c~append(.array~of('2026-11-02T04:00:00Z',-37.8136,144.9631,55.4542,304.0291,-27.1274,272.7758))
do item over c
  answer=.MoonsaultEphemeris~sunMoon(item[1],item[2],item[3])
  sun=answer['sun'];moon=answer['moon']
  call near sun['altitudeTrueDeg'], item[4], 0.10, 'Sun altitude' item[1]
  call nearAngle sun['azimuthTrueDeg'], item[5], 0.10, 'Sun azimuth' item[1]
  call near moon['altitudeTrueDeg'], item[6], 0.30, 'Moon altitude' item[1]
  call nearAngle moon['azimuthTrueDeg'], item[7], 0.30, 'Moon azimuth' item[1]
  if moon['illuminatedFraction'] < 0 | moon['illuminatedFraction'] > 1 then do
    say 'FAIL invalid fraction' item[1]; exit 2
  end
  if sun['azimuthTrueDeg'] < 0 | sun['azimuthTrueDeg'] >= 360 then do
    say 'FAIL bad azimuth' item[1]; exit 2
  end
  if answer['status'] \= 'PREDICTION_ONLY' | answer['observationIndependent'] then do
    say 'FAIL independence flag'; exit 2
  end
end
answer=.MoonsaultEphemeris~sunMoon('2026-11-02T18:00:00Z',-33.8688,151.2093)
call assert answer['moon']['visibilityCandidate'], 'Moon predicted visible in Sydney pre-dawn'
call assert \answer['sun']['visibilityCandidate'], 'Sun under horizon in Sydney pre-dawn'
answer=.MoonsaultEphemeris~sunMoon('2026-11-02T12:16:00Z',-33.8688,151.2093)
call assert \answer['moon']['visibilityCandidate'], 'Moon below horizon Sydney late evening'
answer=.MoonsaultEphemeris~sunMoon('2000-01-01T12:00:00Z',0,0)
call near answer['julianDate'],2451545,0.00001, 'J2000 epoch'
say 'MOONSAULT SUN+MOON EPHEMERIS PASS: 6 independent reference cases; 24 angles + visibility + J2000'
exit 0
near: procedure
  use arg actual, expected, tolerance, label
  if abs(actual-expected) > tolerance then do
    say 'FAIL' label 'expected' expected 'actual' actual
    exit 2
  end
  return
nearAngle: procedure
  use arg actual, expected, tolerance, label
  diff=abs(actual-expected)
  if diff > 180 then diff=360-diff
  if diff > tolerance then do
    say 'FAIL' label 'expected' expected 'actual' actual
    exit 2
  end
  return
assert: procedure
  use arg ok,label
  if \ok then do
    say 'FAIL' label
    exit 2
  end
  return
::requires 'MoonsaultEphemeris.cls'
