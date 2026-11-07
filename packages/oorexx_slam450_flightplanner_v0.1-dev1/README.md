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
| `src/FpWindField.cls` | The fetched wind read back as a field over route points and time, interpolated as east/north components. |
| `tools/fp_sky_day.rex` | Sunrise, sunset, civil twilight, moonrise and moonset at a place, from Moonsault. |
| `tools/fp_get_wind.rex` | ERA5 hourly wind (10 m, 100 m), gusts, low cloud and rain along a route, from Open-Meteo's archive. |
| `tools/fp_glide.rex` | Flies the planned schedule through each of the 7 days before the flight (and the day itself): glide reach, crosswind, ground speed, trip time, energy used, rain and low cloud at passage. |
| `tools/fp_fleet_job.rex` | The fleet job: kit check, fetch, two glide runs, `out/FLEET_RESULT.txt`. |
| `data/coast_route.words` | The coast route: 33 waypoints, Sydney Heads to Port Melbourne round the east of Port Phillip. |
| `tests/` | Synthetic wind and a saved Open-Meteo response, for runs without the network. |

## Running

From the package folder, after `. bin/fp_env.sh`:

```
rexx tools/fp_sky_day.rex sydney_heads -33.83 151.29 2026-10-31 11
rexx tools/fp_get_wind.rex data/coast_route.words 2026-10-23 2026-10-31 out/wind_coast.words
rexx tools/fp_glide.rex data/coast_route.words out/wind_coast.words 2026-10-31 06:00 11 120
rexx tools/fp_fleet_job.rex
```

## Checked so far (7 Nov 2026, Claude's workspace, ooRexx 5.3.0)

- `fp_sky_day.rex`: Moonsault's Sun altitude agrees with PyEphem to 0.003 deg; Sydney Heads sunrise 05:55, sunset 19:21 AEDT on 31 Oct.
- `fp_glide.rex` on a steady 10 m/s westerly: glide from 120 m, 1,047 m into the wind, 1,710 m across, 2,793 m down, 87 s, and leg 1's wind triangle (crosswind 9.7 m/s, ground speed 22.8 m/s) match a hand calculation.
- `fp_get_wind.rex` parses a saved multi-location Open-Meteo response, nulls written as `-`.
- `FpHttp` fetched over TLS from a local test server: status 200, SHA-512 evidence. The API Client package's own test certificate expired on 10 Oct 2026, so its HTTPS tests now fail everywhere; this test used a fresh certificate in a scratch copy.
- Not yet run: a real fetch. This workspace's network cannot reach Open-Meteo; the fleet job is for an ed209 node.

## Credits

ERA5: Contains modified Copernicus Climate Change Service information 2026. Weather data by Open-Meteo.com (CC BY 4.0). Sun and Moon: Moonsault (implementation ChatGPT, GPT-6).
