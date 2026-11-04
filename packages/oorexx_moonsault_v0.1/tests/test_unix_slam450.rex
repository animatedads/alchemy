/* Unix-second compatibility regression for SLAM450 / Moonsault.
 * End-to-end against the actual ephemeris. Verify exact match to strict ISO.
 */
numeric digits 17
cases = .array~new
cases~append(.array~of(0,'1970-01-01T00:00:00Z',0,0))
cases~append(.array~of(1,'1970-01-01T00:00:01Z',0,0))
cases~append(.array~of(86400,'1970-01-02T00:00:00Z',0,0))
cases~append(.array~of(951782400,'2000-02-29T00:00:00Z',51.5,-0.1))
cases~append(.array~of(1793621760,'2026-11-02T12:16:00Z',-33.8688,151.2093))
cases~append(.array~of(1793833200,'2026-11-04T23:00:00Z',-33.8688,151.2093))
cases~append(.array~of(4102444799,'2099-12-31T23:59:59Z',0,0))
do item over cases
  a = .MoonsaultEphemeris~sunMoon(item[1],item[3],item[4])
  b = .MoonsaultEphemeris~sunMoon(item[2],item[3],item[4])
  if a['utc'] \== item[2] then do
    say 'FAIL timestamp' item[1] 'got' a['utc']
    exit 2
  end
  do body over .array~of('sun','moon')
    do key over .array~of('altitudeTrueDeg','azimuthTrueDeg','altitudeRefractedDeg',
      'azimuthRefractedDeg','illuminatedFraction','horizontalParallaxDeg')
      if abs(a[body][key]-b[body][key]) > 0.00000000001 then do
        say 'FAIL prediction mismatch' item[1] body key
        exit 2
      end
    end
  end
  if a['status'] \== 'PREDICTION_ONLY' | a['observationIndependent'] then do
    say 'FAIL prediction authority' item[1]
    exit 2
  end
end
say 'MOONSAULT SLAM450 UNIX-UTC CONTRACT PASS: 7 epochs, both bodies, unchanged prediction flags'
exit 0
::requires 'MoonsaultEphemeris.cls'
