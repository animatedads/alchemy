#!/usr/bin/env python3
"""Independent energy-ledger replay. Audit-only; never imported by the pilot."""
import argparse
import collections
import csv
import json
import math
from pathlib import Path

def records(path):
    with path.open(newline='') as file:
        return list(csv.DictReader(file))

def clamp(x, lower, upper):
    return max(lower, min(upper, x))

RADIO = 0.03
SCANNER = 0.020    # v0.92 short-range scanner, unit/s (2.9 W of a 143.45 W hover)
VISUAL_FIX = 0.03     # v0.92 one grid lookup = one radio message's price
VISUAL_DETAIL = 0.03  # v0.92 one landmark detail request
ALTIMETER = 0.007  # v0.92 radio altimeter, unit/s (1.0 W)
GPS = 0.9          # v0.92 GPS receiver, unit/s ('halves the battery', Tom Dyer)
REMOTE = 100 * RADIO
RHO = 1.225
G = 9.80665

# ---------------------------------------------------------------------------
# v0.88: independent re-implementation of Physics World dev51 power models.
# Written from the published equations, NOT by calling the ooRexx code.
QUAD = dict(m=1.2, n=4, R=0.1143, FM=0.6, tip=95.8, f=0.04, eta=0.75, av=2.0, kappa=1.15)

def quad_power(v, vc, q=QUAD):
    A = q['n'] * math.pi * q['R'] ** 2
    W = q['m'] * G
    D = RHO * q['f'] * v * v / 2
    T = math.hypot(W, D)
    vh = math.sqrt(T / (2 * RHO * A))
    c = max(0.0, vc)
    vi = vh
    for _ in range(60):
        g = vi**4 + 2*c*vi**3 + (v*v + c*c)*vi*vi - vh**4
        dg = 4*vi**3 + 6*c*vi*vi + 2*(v*v + c*c)*vi
        if dg <= 0:
            break
        nxt = vi - g / dg
        if nxt <= 0:
            nxt = vi / 2
        if abs(nxt - vi) < 1e-14:
            vi = nxt
            break
        vi = nxt
    p_ideal = W * math.sqrt(W / (2 * RHO * A))
    p0 = p_ideal * (1 / q['FM'] - q['kappa'])
    shaft = q['kappa']*T*vi + T*c + p0*(1 + 4.65*(v/q['tip'])**2) + D*v
    return shaft / q['eta'] + q['av']

HOVER_J = quad_power(0.0, 0.0)

def quad_quote(row):
    fwd = clamp(float(row['forward_cmd']), -3, 7)
    up = clamp(float(row['up_cmd']), -4, 4)
    side = clamp(float(row['side_cmd']), -3, 3)
    return quad_power(math.hypot(fwd, side), up) / HOVER_J

WING = dict(m=1.4, S=0.4, cd0=0.044, AR=7.0, e=0.8, clmax=1.3, a0=-2.0,
            Ts=8.0, vp=18.0, Rp=0.127, etap=0.85, etam=0.8, av=2.0)

def wing_tables(w=WING):
    k = 1 / (math.pi * w['e'] * w['AR'])
    slope = (2*math.pi*w['AR'] / (2 + math.sqrt(4 + w['AR']**2))) * math.pi / 180
    stall = w['a0'] + w['clmax'] / slope
    al, cl, cd = [], [], []
    a = -6.0
    while a < stall:
        c = slope * (a - w['a0'])
        al.append(a); cl.append(c); cd.append(w['cd0'] + k*c*c)
        a += 1.0
    al.append(stall); cl.append(w['clmax']); cd.append(w['cd0'] + k*w['clmax']**2)
    return al, cl, cd

AL, CL, CD = wing_tables()

def wing_drag(v, gamma_deg, bank_deg, w=WING):
    n = 1 / math.cos(math.radians(bank_deg))
    q = RHO * v * v / 2
    clreq = w['m'] * G * math.cos(math.radians(gamma_deg)) * n / (q * w['S'])
    if clreq > CL[-1]:
        return None
    for i in range(len(AL) - 1):
        if CL[i] <= clreq <= CL[i+1]:
            f = (clreq - CL[i]) / (CL[i+1] - CL[i])
            cd = CD[i] + f * (CD[i+1] - CD[i])
            return q * w['S'] * cd
    return None

def wing_step_energy(v0, thr, bank, gamma, w=WING, substeps=4):
    """Replay one 1 s tick: returns (joules, final airspeed)."""
    h = 1.0 / substeps
    v = v0
    joules = 0.0
    area = math.pi * w['Rp'] ** 2
    for _ in range(substeps):
        d = wing_drag(v, gamma, bank)
        if d is None:
            return None, v
        T = w['Ts'] * thr * max(0.0, 1 - v / w['vp'])
        vi = 0.0 if T <= 0 else (-v + math.sqrt(v*v + 2*T/(RHO*area))) / 2
        p = 0.0 if T <= 0 else T * (v + vi) / w['etap'] / w['etam']
        a = (T - d - w['m'] * G * math.sin(math.radians(gamma))) / w['m']
        v += a * h
        joules += (p + w['av']) * h
    return joules, v

def audit(prefix):
    frames = {r['aircraft']: r for r in records(Path(f'{prefix}_airframes.csv'))}
    report = {'status': 'PASS', 'aircraft': {}, 'faults': [], 'constants':
              {'radio': RADIO, 'remote': REMOTE, 'hover_joules_per_unit': HOVER_J},
              'method': 'independent Python replay of Physics World dev51 equations'}
    camera = collections.Counter()
    for row in records(Path(f'{prefix}_fixed_camera.csv')):
        if row['status'] == 'GRANTED':
            camera[(row['aircraft'], int(row['tick']) + 1)] += 1
    messages = collections.Counter()
    for row in records(Path(f'{prefix}_team_radio.csv')):
        if row['event'] != 'QUEUED_NEXT_TICK':
            continue
        # Wind OBS after movement; other messages sent before movement.
        effective_tick = int(row['tick']) + (0 if row['kind'] == 'OBS' else 1)
        messages[(row['from'], effective_tick)] += 1
    for id_ in sorted(frames):   # v0.89: every craft in <prefix>_airframes.csv
        rows = records(Path(f'{prefix}_{id_}_battery.csv'))
        # v0.92: scanner / radio-altimeter power (SENSOR) from its own ledger.
        sensor = {}
        spath = Path(f'{prefix}_{id_}_sensor_power.csv')
        for srow in (records(spath) if spath.exists() else []):
            c = float(srow['cost'])
            if srow['scanner_on'] not in ('0', '1') or srow['altimeter_on'] not in ('0', '1'):
                report['faults'].append(f'{id_}: bad sensor switch row at {srow["tick"]}')
            expect = int(srow['scanner_on']) * SCANNER + int(srow['altimeter_on']) * ALTIMETER + int(srow.get('gps_on', '0')) * GPS
            if abs(c - expect) > 1e-9:
                report['faults'].append(f'{id_}: sensor cost {c} != {expect} at {srow["tick"]}')
            if srow['debited'] == '1':
                sensor[int(srow['tick'])] = c
        # v0.92: visual position-fix data charge (VISUAL) from its own ledger.
        visual = {}
        vpath = Path(f'{prefix}_{id_}_visual_power.csv')
        for vrow in (records(vpath) if vpath.exists() else []):
            c = float(vrow['cost'])
            expect = int(vrow['grid_fixes']) * VISUAL_FIX + int(vrow['detail_requests']) * VISUAL_DETAIL
            if abs(c - expect) > 1e-9:
                report['faults'].append(f'{id_}: visual cost {c} != {expect} at {vrow["tick"]}')
            if vrow['debited'] == '1':
                visual[int(vrow['tick'])] = c
        total_sensor = 0.0
        truth = records(Path(f'{prefix}_{id_}_truth_ORACLE_ONLY.csv'))
        total_flight = total_lookup = total_radio = 0.0
        kind = frames[id_]['airframe']
        capacity = float(frames[id_]['capacity'])
        energy = capacity
        last_tick = 0
        prev_speed = 8.0
        worst = 0.0
        for row in rows:
            t = int(row['tick'])
            tag = f'{id_} tick {t}'
            if t != last_tick+1:
                report['faults'].append(f'{tag}: discontinuous battery tick')
            last_tick = t
            if kind == 'QUAD':
                cost = quad_quote(row)
            else:
                logged = float(row['flight_price'])
                joules, vend = wing_step_energy(prev_speed, float(row['throttle']),
                                                float(row['bank_deg']), float(row['gamma_deg']))
                if joules is None:
                    report['faults'].append(f'{tag}: wing replay stalled')
                    cost = logged
                else:
                    cost = joules / HOVER_J
                    if row['powered'] == '1' and abs(cost - logged) > 1e-6 * max(1.0, logged):
                        report['faults'].append(f'{tag}: wing price {logged} != replay {cost:.9f}')
                    if abs(vend - float(row['airspeed'])) > 1e-6:
                        report['faults'].append(f'{tag}: wing airspeed {row["airspeed"]} != replay {vend:.9f}')
                    if row['powered'] != '1':
                        cost = logged   # brown-out rows: cost capped at remaining charge
                worst = max(worst, abs(cost - logged))
                prev_speed = float(row['airspeed'])
            lookup = int(row['lookup_granted'])
            sent = int(row['radio_sent'])
            if lookup not in (0, 1) or sent < 0:
                report['faults'].append(f'{tag}: invalid device count')
            if camera[(id_, t)] != lookup:
                report['faults'].append(f'{tag}: remote views mismatch service')
            if messages[(id_, t)] != sent:
                report['faults'].append(f'{tag}: radio charges mismatch service')
            total_flight += cost
            total_lookup += REMOTE*lookup
            total_radio += RADIO*sent
            total_sensor += sensor.get(t, 0.0)
            energy -= cost + REMOTE*lookup + RADIO*sent + sensor.get(t, 0.0) + visual.get(t, 0.0)
            for field, expected in (
                ('remaining', energy), ('flight_used', total_flight),
                ('remote_used', total_lookup), ('radio_used', total_radio),
                ('percent', 100*energy/capacity)):
                got = float(row[field])
                if not math.isfinite(got) or abs(got-expected) > 0.00015:
                    report['faults'].append(f'{tag}: {field} {got} != {expected:.7f}')
            if energy < -0.00001:
                report['faults'].append(f'{tag}: power overdraft')
        if len(truth) != len(rows):
            report['faults'].append(f'{id_}: position/battery log lengths differ')
        for t, pos in enumerate(truth, start=1):
            if int(pos['tick']) != t:
                report['faults'].append(f'{id_}: position gap at {t}')
        report['aircraft'][id_] = {'airframe': kind, 'capacity': capacity,
            'max_wing_price_residual': worst, 'ticks': len(rows), 'remaining': round(energy, 6),
            'flight_used': round(total_flight, 6), 'remote_used': round(total_lookup, 6),
            'radio_used': round(total_radio, 6), 'paid_views': round(total_lookup / REMOTE),
            'radio_messages': round(total_radio / RADIO), 'sensor_used': round(total_sensor, 6)}
    report['status'] = 'PASS' if not report['faults'] else 'FAIL'
    return report

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('prefix', type=Path)
    parser.add_argument('--out', type=Path)
    args = parser.parse_args()
    report = audit(args.prefix)
    result = json.dumps(report, indent=2)
    if args.out:
        args.out.write_text(result + '\n')
    print(result)
    raise SystemExit(0 if report['status'] == 'PASS' else 2)
