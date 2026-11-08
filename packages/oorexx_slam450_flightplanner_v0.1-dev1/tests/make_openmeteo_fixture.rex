/* make_openmeteo_fixture.rex - saved-response stand-ins for fp_get_wind.rex:
 * Open-Meteo's multi-location archive JSON (an array, one object per point),
 * 2 hours, one value null.
 *   rexx make_openmeteo_fixture.rex <n> <outFile>            ERA5 wind and weather
 *   rexx make_openmeteo_fixture.rex <n> <outFile> snow       ERA5-Land snow depth
 * Written by: Claude (Opus 5.5), 2026-11-07; temperature, pressure and the
 * snow response 2026-11-08. */
parse arg n outFile kind
locs = .array~new
do i = 1 to n
  h = .directory~new
  h['time'] = .array~of('2026-10-24T00:00', '2026-10-24T01:00')
  if kind == 'snow' then do
    h['snow_depth'] = .array~of(0.12, .nil)
  end
  else do
    h['wind_speed_10m'] = .array~of(4.1, 4.4); h['wind_direction_10m'] = .array~of(250, 255)
    h['wind_speed_100m'] = .array~of(6.2, .nil); h['wind_direction_100m'] = .array~of(252, 258)
    h['wind_gusts_10m'] = .array~of(9.0, 9.5); h['cloud_cover_low'] = .array~of(10, 20)
    h['precipitation'] = .array~of(0, 0.4)
    h['temperature_2m'] = .array~of(11.5, 12.0); h['pressure_msl'] = .array~of(1015.2, 1014.8)
  end
  o = .directory~new; o['latitude'] = -33.75; o['longitude'] = 151.25; o['elevation'] = 10 * i; o['hourly'] = h
  locs~append(o)
end
call charout outFile, .json~toJson(locs), 1
call stream outFile, 'c', 'close'
::requires 'json.cls'
