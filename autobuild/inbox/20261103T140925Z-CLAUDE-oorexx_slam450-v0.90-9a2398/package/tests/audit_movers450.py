#!/usr/bin/env python3
"""SLAM450 v0.90 independent audit of slow-moving committed targets.

Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-03.

Replays the oracle target track against the logged wind and the PowerSLAM
scene, without importing any Rexx code:
  physics     each step = own air vector + the wind logged for that band;
              horizontal air speed <= airspeed, climb rate <= 2 m/s
  scene       no target segment (7-ray, 2 m offsets) enters a solid or sea
  commitment  destination fixed for a whole leg, on the elected heading,
              within a 1-in-2 gradient; a new leg only after ARRIVE (<= 2 m)
  claims      every claim is a relative swept contact <= 2.5 m with the
              target's own motion over that tick; claimed targets stop
  --compare   a second run with the same seed: every target's track must be
              identical until it is claimed in either run, i.e. no target
              ever reacted to an aircraft
Exit 0 = PASS, 2 = FAIL.
"""
import argparse, csv, importlib.util, json, math
from pathlib import Path

# Load the shared cuboid helper by explicit path (works under python3 -I).
_spec = importlib.util.spec_from_file_location('flight', Path(__file__).resolve().parent / 'audit_flight450_v2.py')
flight = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(flight)

OFFSETS = [(0, 0, 0), (2, 0, 0), (-2, 0, 0), (0, 2, 0), (0, -2, 0), (0, 0, 2), (0, 0, -2)]
MOVE = {'FLY', 'FINAL', 'WAYPOINT', 'ARRIVE', 'HELD_BY_WIND', 'SCENE_GUARD'}
TOL = 6e-4


def load(p):
    p = Path(p)
    return list(csv.DictReader(open(p, newline=''))) if p.exists() else []


def level(z):
    return 1 if z < 55 else (2 if z < 105 else 3)


def track(prefix):
    rows = load(f'{prefix}_targets_track_ORACLE_ONLY.csv')
    out = {}
    for r in rows:
        out.setdefault(int(r['target']), []).append(r)
    return out


def positions(rows):
    """tick -> (x,y,z) after that tick's movement (tick 0 = start)."""
    pos = {}
    for r in rows:
        t = int(r['tick'])
        p = (float(r['east_m']), float(r['north_m']), float(r['z_m']))
        if t == 0 or r['event'] in MOVE:
            pos[t] = p
    return pos


def relative_contact(a0, a1, p0, p1, radius=2.5):
    r = [a0[i] - p0[i] for i in range(3)]
    v = [(a1[i] - a0[i]) - (p1[i] - p0[i]) for i in range(3)]
    s = sum(x * x for x in v)
    t = 0 if s < 1e-12 else max(0, min(1, -sum(r[i] * v[i] for i in range(3)) / s))
    return math.sqrt(sum((r[i] + t * v[i]) ** 2 for i in range(3)))


def audit(prefix, scene, airspeed, compare=None):
    faults, notes = [], {}
    tr = track(prefix)
    if not tr:
        return {'status': 'FAIL', 'faults': ['no target track (static-target race?)']}
    wind = {(int(r['tick']), int(r['level'])): (float(r['east_mps']), float(r['north_mps']))
            for r in load(f'{prefix}_wind_levels_ORACLE_ONLY.csv')}
    claims = {int(r['target']): (int(r['tick']), r['winner']) for r in load(f'{prefix}_claims.csv')}
    solids = [(r['name'], flight.cuboid(r)) for r in flight.load(scene)]
    craft = {}
    for f in Path(prefix).parent.glob(Path(prefix).name + '_A*_truth_ORACLE_ONLY.csv'):
        cid = f.name[len(Path(prefix).name) + 1:].split('_')[0]
        craft[cid] = {int(r['tick']): (float(r['x_east_m']), float(r['y_north_m']), float(r['z_m'])) for r in load(f)}
    legs = arrivals = held = guards = replans = corrections = 0
    max_air = max_climb = max_xtrack = 0.0
    for n, rows in sorted(tr.items()):
        pos = positions(rows)
        last = max(pos)
        stop = claims.get(n, (None,))[0]
        expect = list(range(0, last + 1))
        if sorted(pos) != expect:
            faults.append(f'T{n} track not one move per tick')
        if stop is not None and last > stop:
            faults.append(f'T{n} moved after its claim at tick {stop}')
        # Physics + scene, per movement row.
        prev_heading = None; leg_of_prev = None
        for r in rows:
            t = int(r['tick'])
            if r['event'] not in MOVE or t == 0:
                continue
            a, b = pos[t - 1], pos[t]
            ae, an = float(r['air_east_mps']), float(r['air_north_mps'])
            we, wn = float(r['wind_east_mps']), float(r['wind_north_mps'])
            if r['event'] == 'SCENE_GUARD':
                guards += 1
                if math.dist(a, b) > TOL:
                    faults.append(f'T{n} tick {t} SCENE_GUARD but moved')
                continue
            if wind:
                lw = wind.get((t, level(a[2])))
                if lw is None or abs(lw[0] - we) > TOL or abs(lw[1] - wn) > TOL:
                    faults.append(f'T{n} tick {t} wind {we:.3f},{wn:.3f} != band {level(a[2])} log {lw}')
            if abs(b[0] - a[0] - ae - we) > TOL or abs(b[1] - a[1] - an - wn) > TOL:
                faults.append(f'T{n} tick {t} step != air + wind')
            air = math.hypot(ae, an); max_air = max(max_air, air)
            if air > airspeed + TOL:
                faults.append(f'T{n} tick {t} air speed {air:.3f} > {airspeed}')
            climb = abs(b[2] - a[2]); max_climb = max(max_climb, climb)
            if climb > 2 + TOL:
                faults.append(f'T{n} tick {t} climb {climb:.3f} > 2')
            if b[2] <= 2:
                faults.append(f'T{n} tick {t} at/below 2 m')
            for name, verts in solids:
                if any(flight.hitbox(tuple(a[k] + o[k] for k in range(3)), tuple(b[k] + o[k] for k in range(3)), verts) for o in OFFSETS):
                    faults.append(f'T{n} tick {t} segment intersects {name}'); break
            if r['event'] == 'HELD_BY_WIND':
                held += 1
            hd = math.degrees(math.atan2(ae, an)) % 360
            if prev_heading is not None and leg_of_prev == r['leg']:
                if abs((hd - prev_heading + 180) % 360 - 180) > 0.5:
                    corrections += 1
            prev_heading, leg_of_prev = hd, r['leg']
        # Commitment: legs, destinations, arrivals.
        cur = None; origin = None; elect_ok = True
        for i, r in enumerate(rows):
            t = int(r['tick']); ev = r['event']
            p = (float(r['east_m']), float(r['north_m']), float(r['z_m']))
            if ev == 'ELECT':
                legs += 1
                if t > 0:
                    before = [x['event'] for x in rows[:i] if int(x['tick']) == t]
                    if not ({'ARRIVE', 'FORCED_REELECT', 'NO_LEG'} & set(before)) and cur is not None:
                        faults.append(f'T{n} tick {t} new leg without arriving')
                cur = (float(r['dest_east_m']), float(r['dest_north_m']), float(r['dest_z_m']))
                origin = p
                hdg = float(r['note'].split('heading=')[1].split()[0])
                brg = math.degrees(math.atan2(cur[0] - p[0], cur[1] - p[1])) % 360
                if abs((brg - hdg + 180) % 360 - 180) > 0.2:
                    faults.append(f'T{n} tick {t} destination bearing {brg:.2f} != elected heading {hdg:.2f}')
                hd = math.hypot(cur[0] - p[0], cur[1] - p[1])
                if abs(cur[2] - p[2]) > 0.5 * hd + 0.01:
                    faults.append(f'T{n} tick {t} flight level outside 1-in-2 gradient')
                continue
            if ev == 'REPLAN':
                replans += 1
            if ev in MOVE and cur is not None and r['dest_east_m'] and ev != 'ARRIVE':
                d = (float(r['dest_east_m']), float(r['dest_north_m']), float(r['dest_z_m']))
                if max(abs(d[k] - cur[k]) for k in range(3)) > 1e-3:
                    faults.append(f'T{n} tick {t} destination changed mid-leg')
            if ev == 'ARRIVE':
                arrivals += 1
                if math.dist(p, cur) > 2 + TOL:
                    faults.append(f'T{n} tick {t} ARRIVE {math.dist(p, cur):.2f} m from destination')
            if ev in MOVE and origin is not None and cur is not None:
                ax, ay = cur[0] - origin[0], cur[1] - origin[1]; L = math.hypot(ax, ay)
                if L > 1e-6:
                    max_xtrack = max(max_xtrack, abs((p[0] - origin[0]) * ay - (p[1] - origin[1]) * ax) / L)
    # Claims against the moving target.
    for n, (t, w) in claims.items():
        pos = positions(tr[n])
        if w not in craft or t not in craft[w] or t not in pos or t - 1 not in pos:
            faults.append(f'claim T{n}: missing poses at tick {t}'); continue
        g = relative_contact(craft[w].get(t - 1, craft[w][t]), craft[w][t], pos[t - 1], pos[t])
        if g > 2.5 + 1e-4:
            faults.append(f'claim T{n} by {w}: relative swept miss {g:.3f} m')
    # Cross-run invariance: targets ignore aircraft.
    identical_ticks = None
    if compare:
        other = track(compare)
        oc = {int(r['target']): int(r['tick']) for r in load(f'{compare}_claims.csv')}
        identical_ticks = {}
        for n in tr:
            a, b = positions(tr[n]), positions(other.get(n, []))
            horizon = min(claims.get(n, (10 ** 9,))[0], oc.get(n, 10 ** 9), max(a), max(b) if b else -1)
            same = 0
            for t in range(0, horizon + 1):
                if a.get(t) != b.get(t):
                    faults.append(f'T{n} differs from {Path(compare).name} at tick {t} before any claim'); break
                same = t
            identical_ticks[f'T{n}'] = same
    notes = {'legs': legs, 'arrivals': arrivals, 'replans': replans, 'held_by_wind_ticks': held,
             'scene_guards': guards, 'in_leg_course_corrections_gt_0_5deg': corrections,
             'max_air_speed_mps': round(max_air, 4), 'max_climb_mps': round(max_climb, 4),
             'max_cross_track_m': round(max_xtrack, 3), 'claims': len(claims)}
    if identical_ticks is not None:
        notes['identical_until_claim_ticks'] = identical_ticks
    return {'status': 'PASS' if not faults else 'FAIL', **notes, 'faults': faults[:40],
            'caveat': 'synthetic PowerSLAM model audit, not real-world clearance'}


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('prefix'); ap.add_argument('--scene', required=True)
    ap.add_argument('--airspeed', type=float, default=3.0); ap.add_argument('--compare'); ap.add_argument('--out')
    a = ap.parse_args()
    r = audit(a.prefix, a.scene, a.airspeed, a.compare)
    txt = json.dumps(r, indent=2)
    if a.out:
        Path(a.out).write_text(txt + '\n')
    print(txt)
    raise SystemExit(0 if r['status'] == 'PASS' else 2)
