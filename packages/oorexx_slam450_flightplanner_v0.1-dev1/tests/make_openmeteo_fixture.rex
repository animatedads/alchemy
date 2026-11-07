/* make_openmeteo_fixture.rex - a saved-response stand-in for fp_get_wind.rex:
 * Open-Meteo's multi-location archive JSON (an array, one object per point),
 * 2 hours, one value null. Written by: Claude (Opus 5.5), 2026-11-07. */
parse arg n outFile
locs = .array~new
do i = 1 to n
  h = .directory~new
  h['time'] = .array~of('2026-10-24T00:00', '2026-10-24T01:00')
  h['wind_speed_10m'] = .array~of(4.1, 4.4); h['wind_direction_10m'] = .array~of(250, 255)
  h['wind_speed_100m'] = .array~of(6.2, .nil); h['wind_direction_100m'] = .array~of(252, 258)
  h['wind_gusts_10m'] = .array~of(9.0, 9.5); h['cloud_cover_low'] = .array~of(10, 20)
  h['precipitation'] = .array~of(0, 0.4)
  o = .directory~new; o['latitude'] = -33.75; o['longitude'] = 151.25; o['hourly'] = h
  locs~append(o)
end
call charout outFile, .json~toJson(locs), 1
call stream outFile, 'c', 'close'
::requires 'json.cls'
