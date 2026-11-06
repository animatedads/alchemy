#!/usr/bin/env python3
"""SLAM 450 v0.93: check the stand-in Sun/Moon ephemeris against PyEphem.

Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-04.
Independent code (PyEphem, the XEphem engine) on the same instants, Sydney
Harbour. Passes when the worst Sun error is under 0.05 deg and the worst
Moon error under 0.6 deg in altitude and azimuth (azimuth error scaled by
cos(alt) so it measures sky angle), for bodies above -5 deg.
usage: check_sky450.py [rexx-dump-output-file]   (default: run the dump;
       SLAM450_EPHEMERIS=MOONSAULT checks Moonsault via the adapter, MOONSAULT_SRC=its src)
"""
import math, subprocess, sys, os
try:
    import ephem
except ImportError:
    print("SKIP: PyEphem not installed (pip install ephem)"); sys.exit(0)
LAT, LON = -33.852, 151.210
here = os.path.dirname(os.path.abspath(__file__))
if len(sys.argv) > 1:
    lines = open(sys.argv[1]).read().split()
else:
    provider = os.environ.get("SLAM450_EPHEMERIS", "STANDIN")
    out = subprocess.run(["rexx", os.path.join(here, "..", "bin", "sky450_dump.rex"),
                          str(LAT), str(LON), "1767225600", "400", "79231", provider],
                         capture_output=True, text=True, check=True).stdout
    lines = out.split()
rows = [lines[i:i + 7] for i in range(0, len(lines), 7)]
obs = ephem.Observer(); obs.lat, obs.lon = str(LAT), str(LON); obs.elevation = 0; obs.pressure = 0
worst = {"sun_alt": 0, "sun_az": 0, "moon_alt": 0, "moon_az": 0, "illum": 0}
n = 0
for r in rows:
    t, sa, sz, ma, mz, il, _ = r
    obs.date = ephem.Date((float(t) / 86400.0) + 2440587.5 - 2415020.0)
    sun, moon = ephem.Sun(obs), ephem.Moon(obs)
    s_alt, s_az = math.degrees(sun.alt), math.degrees(sun.az)
    m_alt, m_az = math.degrees(moon.alt), math.degrees(moon.az)
    def daz(a, b):
        d = abs(a - b) % 360
        return min(d, 360 - d)
    if s_alt > -5:
        worst["sun_alt"] = max(worst["sun_alt"], abs(float(sa) - s_alt))
        worst["sun_az"] = max(worst["sun_az"], daz(float(sz), s_az) * math.cos(math.radians(s_alt)))
    if m_alt > -5:
        worst["moon_alt"] = max(worst["moon_alt"], abs(float(ma) - m_alt))
        worst["moon_az"] = max(worst["moon_az"], daz(float(mz), m_az) * math.cos(math.radians(m_alt)))
    worst["illum"] = max(worst["illum"], abs(float(il) - moon.phase / 100.0))
    n += 1
ok = worst["sun_alt"] < 0.05 and worst["sun_az"] < 0.05 and worst["moon_alt"] < 0.6 and worst["moon_az"] < 0.6 and worst["illum"] < 0.05
print(("PASS" if ok else "FAIL"), "check_sky450", os.environ.get("SLAM450_EPHEMERIS", "STANDIN"), n, "instants;", " ".join(f"{k}={v:.4f}" for k, v in worst.items()))
sys.exit(0 if ok else 1)
