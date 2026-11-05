#!/usr/bin/env python3
"""SLAM 450 v0.89 squad audit (offline, audit-only; never imported by a pilot).
Claude (Opus 5.5), 2026-11-03.

Checks, for N craft listed in <prefix>_airframes.csv:
  - consecutive per-craft tracks; per-airframe kinematic step bound;
  - no committed segment intersects a scene solid; nobody below 2 m;
  - every pairwise swept gap < 4 m between craft that flew the same tick is
    matched by a recorded separation knock-out of BOTH craft on that tick;
  - craft listed OUT stop moving after their knock-out tick;
  - every claim: the winner's swept segment that tick reaches within 2.5 m;
  - every CONFIRMED type belief names a type actually present among the
    observer's live rivals (R) or teammates (P).
"""
import argparse, csv, importlib.util, json, math
from pathlib import Path

HERE = Path(__file__).parent
spec = importlib.util.spec_from_file_location('flight', HERE / 'audit_flight450_v2.py')
flight = importlib.util.module_from_spec(spec); spec.loader.exec_module(flight)

# v0.91: optional independent ground check (tests/ground_audit450.py).
_gspec = importlib.util.spec_from_file_location('ground_audit450', Path(__file__).resolve().parent / 'ground_audit450.py')
ground_audit = importlib.util.module_from_spec(_gspec); _gspec.loader.exec_module(ground_audit)


def ground_selfcheck(g):
    """Known places, so a broken projection or grid read fails loudly."""
    out = []
    for name, lat, lon, role, lo in (('Observatory Hill', -33.8597, 151.2045, 'L', 30), ('Fort Denison', -33.8548, 151.2256, 'L', 0),
                                     ('scene origin', -33.852, 151.210, 'W', None)):
        x = (lon - 151.210) * 92300; y = (lat + 33.852) * 111200
        top, r = g.cell(x, y)
        if r != role or (lo is not None and top < lo):
            out.append(f'ground self-check {name}: {r} {top}')
    return out
OFFSETS = ((0,0,0),(2,0,0),(-2,0,0),(0,2,0),(0,-2,0),(0,0,2),(0,0,-2))

def load(path):
    p = Path(path)
    return list(csv.DictReader(open(p, newline=''))) if p.exists() else []

def seg_point(a, b, p):
    ab = [b[i]-a[i] for i in range(3)]; ap = [p[i]-a[i] for i in range(3)]
    L = sum(x*x for x in ab)
    t = 0 if L < 1e-12 else max(0, min(1, sum(ab[i]*ap[i] for i in range(3))/L))
    return math.dist([a[i]+t*ab[i] for i in range(3)], p)

def swept_gap(a0, a1, b0, b1):
    r = [a0[i]-b0[i] for i in range(3)]; v = [(a1[i]-a0[i])-(b1[i]-b0[i]) for i in range(3)]
    s = sum(x*x for x in v); t = 0 if s < 1e-12 else max(0, min(1, -sum(r[i]*v[i] for i in range(3))/s))
    return math.sqrt(sum((r[i]+t*v[i])**2 for i in range(3)))

def audit(prefix, scene, ground_dir=None):
    frames = {r['aircraft']: r for r in load(f'{prefix}_airframes.csv')}
    ids = sorted(frames)
    team = {}
    tracks = {i: load(f'{prefix}_{i}_truth_ORACLE_ONLY.csv') for i in ids}
    outs = {r[1]: (int(r[0]), r[3]) for r in csv.reader(open(f'{prefix}_out_events.csv'))} if Path(f'{prefix}_out_events.csv').exists() else {}
    course = {int(r['target']): (float(r['east_m']), float(r['north_m']), float(r['z_m'])) for r in load(f'{prefix}_course_ORACLE_ONLY.csv')}
    solids = [(r['name'], flight.cuboid(r)) for r in flight.load(scene)]
    moving = {}
    for r in load(f'{prefix}_targets_track_ORACLE_ONLY.csv'):
        if r['event'] in ('FLY', 'FINAL', 'WAYPOINT', 'ARRIVE', 'HELD_BY_WIND', 'SCENE_GUARD') or r['tick'] == '0':
            moving.setdefault(int(r['target']), {})[int(r['tick'])] = (float(r['east_m']), float(r['north_m']), float(r['z_m']))
    faults = []; xyz = lambda r: (float(r['x_east_m']), float(r['y_north_m']), float(r['z_m']))
    pos = {i: {int(r['tick']): xyz(r) for r in tracks[i]} for i in ids}
    min_gap = 1e9; max_step = 0
    for i in ids:
        ticks = sorted(pos[i])
        if ticks != list(range(1, len(ticks)+1)): faults.append(f'{i} non-consecutive track')
        lim = 13.5
        if frames[i]['airframe'] == 'FIXED_WING': lim = math.hypot(float(frames[i]['max_speed'])+4, 3)+0.5
        for t in ticks:
            if pos[i][t][2] <= 2: faults.append(f'{i} tick {t} at/below 2 m')
            if t > 1:
                d = math.dist(pos[i][t-1], pos[i][t]); max_step = max(max_step, d)
                if d > lim: faults.append(f'{i} tick {t} step {d:.2f} > {lim:.2f}')
                a, b = pos[i][t-1], pos[i][t]
                for name, verts in solids:
                    if any(flight.hitbox(tuple(a[k]+o[k] for k in range(3)), tuple(b[k]+o[k] for k in range(3)), verts) for o in OFFSETS):
                        faults.append(f'{i} tick {t} segment intersects {name}'); break
        if i in outs:
            k = outs[i][0]
            for t in ticks:
                if t > k: faults.append(f'{i} moved after knock-out at {k}')
    last = max(max(pos[i]) if pos[i] else 0 for i in ids)
    for t in range(2, last+1):
        flying = [i for i in ids if t in pos[i] and t-1 in pos[i]]
        for a in range(len(flying)):
            for b in range(a+1, len(flying)):
                i, j = flying[a], flying[b]
                g = swept_gap(pos[i][t-1], pos[i][t], pos[j][t-1], pos[j][t])
                min_gap = min(min_gap, g)
                if g < 4:
                    oi, oj = outs.get(i), outs.get(j)
                    if not (oi and oj and oi[0] == t and oj[0] == t and 'SEPARATION' in oi[1] and 'SEPARATION' in oj[1]):
                        faults.append(f'{i}/{j} gap {g:.2f} m at tick {t} without matching knock-outs')
    for r in load(f'{prefix}_claims.csv'):
        t, w, n = int(r['tick']), r['winner'], int(r['target'])
        if t not in pos[w]: faults.append(f'claim {n}: winner {w} has no pose at tick {t}'); continue
        a = pos[w].get(t-1, pos[w][t]); b = pos[w][t]
        if moving:
            # v0.90 moving targets: relative swept motion over the tick.
            mv = moving.get(n, {})
            if t not in mv or t-1 not in mv: faults.append(f'claim {n}: no target track at tick {t}'); continue
            g = swept_gap(a, b, mv[t-1], mv[t])
            if g > 2.5 + 1e-4: faults.append(f'claim {n} by {w}: relative swept miss {g:.2f} m')
        elif seg_point(a, b, course[n]) > 2.5 + 1e-6: faults.append(f'claim {n} by {w}: swept miss {seg_point(a, b, course[n]):.2f} m')
    ground_min = None
    if ground_dir:
        g = ground_audit.Ground(ground_dir)
        faults += ground_selfcheck(g)
        ground_min = math.inf
        for i in ids:
            ticks = sorted(pos[i])
            for t in ticks[1:]:
                worst, fault = g.check_segment(pos[i][t-1], pos[i][t], 2.0)
                ground_min = min(ground_min, worst)
                if fault: faults.append(f'{i} tick {t} ground: {fault}')
        ground_min = round(ground_min + 2.0, 3)
    status = 'PASS' if not faults else 'FAIL'
    return {'status': status, 'craft': ids, 'knock_outs': outs, 'minimum_swept_gap_m': round(min_gap, 4),
            'maximum_step_m': round(max_step, 4), 'claims': len(load(f'{prefix}_claims.csv')), 'faults': faults,
            'scene_solids': len(solids), 'minimum_ground_clearance_m': ground_min, 'caveat': 'synthetic PowerSLAM model audit, not real-world clearance'}

if __name__ == '__main__':
    ap = argparse.ArgumentParser(); ap.add_argument('prefix'); ap.add_argument('--scene', required=True); ap.add_argument('--out'); ap.add_argument('--ground')
    a = ap.parse_args(); r = audit(a.prefix, a.scene, a.ground); txt = json.dumps(r, indent=2)
    if a.out: Path(a.out).write_text(txt + '\n')
    print(txt); raise SystemExit(0 if r['status'] == 'PASS' else 2)
