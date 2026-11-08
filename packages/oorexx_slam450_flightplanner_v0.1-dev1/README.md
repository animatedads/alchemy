# SLAM 450 Flight Planner v0.1-dev1

Plans a SLAM 450 flight from Sydney Harbour to the Port of Melbourne on 31 October 2026, in the sky and weather as they were that day. It sits beside SLAM 450 and flies nothing.

Architecture: Tom Dyer. Coding: Claude (Opus 5.5). Design document: "SLAM 450 Flight Planner: Sydney to Melbourne, port to port (design v0.1)" (Claude Docs).

## What is here

| File | What it does |
| --- | --- |
| `src/FpLog.cls` | Progress log for every tool through oorexx_logging v0.7: one line per event on the console as it happens. |
| `src/FpHttp.cls` | Every fetch goes through Alchemy's API Client v0.4.1 (HTTP/1.1, OpenSSL through Foreign Runtime v0.22.6), never curl. Kit check first; each response comes with its evidence (URL, status, bytes, SHA-512 from crypto.cls, time). |
| `src/FpRoute.cls` | Route files: `point\|name\|lat\|lon` in flying order. |
| `src/FpAirframe.cls` | The planning fixed wing (cruise 27 m/s, best glide 22 m/s at L/D 16, crosswind 12 m/s, 24 h budget, 30% reserve; `FP_*` overrides), its glide reach and wind triangle; `FpGeo` distances and bearings. All trigonometry through the Maths package. |
| `src/FpWindField.cls` | The fetched wind read back as a field over route points and time, interpolated as east/north components; each point's ground height. |
| `tools/fp_sky_day.rex` | Sunrise, sunset, civil twilight, moonrise and moonset at a place, from Moonsault. |
| `tools/fp_get_wind.rex` | ERA5 hourly wind (10 m, 100 m above ground), gusts, low cloud and rain along a route, and each point's ground height, from Open-Meteo's archive. |
| `tools/fp_glide.rex` | Flies the planned schedule through each of the 7 days before the flight (and the day itself): glide reach, crosswind, ground speed, trip time, energy used (thinner air and climbs counted), rain and low cloud at passage. |
| `tools/fp_fleet_job.rex` | The fleet job: kit check, then for each route a fetch and two glide runs, `out/FLEET_RESULT.txt`. |
| `data/coast_route.words` | The coast route: 33 waypoints, Sydney Heads to Port Melbourne round the east of Port Phillip. |
| `data/alpine_route.words` | The alpine route (Tom Dyer's "quick deviation around Mt Kosciuszko"): 20 waypoints, Hume to Goulburn, the Monaro to Cooma, Jindabyne, Perisher, Charlotte Pass, the summit, Thredbo, the Alpine Way to Khancoban, Albury and the Hume to Melbourne. |
| `tests/` | Synthetic wind and a saved Open-Meteo response, for runs without the network. |

## Running

From the package folder, after `. bin/fp_env.sh`:

```
rexx tools/fp_sky_day.rex sydney_heads -33.83 151.29 2026-10-31 11
rexx tools/fp_get_wind.rex data/coast_route.words 2026-10-23 2026-10-31 out/wind_coast.words
rexx tools/fp_glide.rex data/coast_route.words out/wind_coast.words 2026-10-31 06:00 11 120
rexx tools/fp_get_wind.rex data/alpine_route.words 2026-10-23 2026-10-31 out/wind_alpine.words
rexx tools/fp_glide.rex data/alpine_route.words out/wind_alpine.words 2026-10-31 06:00 11 120
rexx tools/fp_fleet_job.rex
```

## Checked so far (Claude's workspace, ooRexx 5.3.0)

7 Nov 2026:

- `fp_sky_day.rex`: Moonsault's Sun altitude agrees with PyEphem to 0.003 deg; Sydney Heads sunrise 05:55, sunset 19:21 AEDT on 31 Oct.
- `fp_glide.rex` on a steady 10 m/s westerly: glide from 120 m, 1,047 m into the wind, 1,710 m across, 2,793 m down, 87 s, and leg 1's wind triangle (crosswind 9.7 m/s, ground speed 22.8 m/s) match a hand calculation (sea-level air, before 8 Nov).
- `fp_get_wind.rex` parses a saved multi-location Open-Meteo response, nulls written as `-`.
- `FpHttp` fetched over TLS from a local test server: status 200, SHA-512 evidence. The API Client package's own test certificate expired on 10 Oct 2026, so its HTTPS tests now fail everywhere; this test used a fresh certificate in a scratch copy.
- First real fetch: ed209h, commit 6469555e (coast route, 24-31 Oct; 24 Oct not flown because the fetch started on 24 Oct UTC).

8 Nov 2026 (ground height and thin air, for the alpine route):

- `fp_get_wind.rex` writes an `elev|` line per point from Open-Meteo's `elevation` (saved response: 11 lines).
- `FpAirframe`: ISA density ratio, true airspeed at height, budget per hour scaled by 1/sqrt(sigma), climbs costed at dz x L/D of cruise. Hand check, alpine leg Charlotte Pass to the summit in a synthetic 10 m/s westerly (mean 2,114 m AMSL): sigma 0.812, true airspeed 29.96 m/s, ground speed 20.6 m/s, glide into wind 1,133 m; total climb over the route 2,248 m.
- Coast regression on the 6469555e wind: trips 5-8 minutes shorter (120 m air is 0.6% thinner), budget percentages within 1 point.
- `fp_fleet_job.rex` with both routes: kit passes in the repo layout; the fetch stops here only because this workspace has no direct outbound route.

8 Nov 2026, later (the day's own air, and snow):

- `fp_get_wind.rex` also takes ERA5 `temperature_2m` and `pressure_msl`, and ERA5-Land `snow_depth` from a second, optional request per batch (ERA5 0.25 deg has no snow depth). Tested with saved responses, with and without the snow file. Lesson: every line of the output file is now written from one method, because a `lineout` to the same file name from a second method lost its line.
- `FpAirframe~densityRatioMet`: pressure reduced from sea level through a 6.5 C/km column above the ground, then density. With standard values it gives the standard atmosphere exactly (0.79326 at 2,348 m). Hand check, summit at 10 C and 1015 hPa: 769.7 hPa, sigma 0.7751, density altitude 2,575 m.
- `fp_glide.rex` on a synthetic mild day (10 C everywhere at the ground, 1015 hPa, 0.3 m of snow at the summit and Charlotte Pass): leg 9 density altitude 2,270 m by hand and by tool; trip 5 minutes longer than in the standard atmosphere because 10 C at sea level is denser than 15 C; 2 legs counted over snow. Wind files from before 8 Nov still read, in the standard atmosphere.

## Credits

ERA5: Contains modified Copernicus Climate Change Service information 2026. Weather data by Open-Meteo.com (CC BY 4.0). Sun and Moon: Moonsault (implementation ChatGPT, GPT-6).
