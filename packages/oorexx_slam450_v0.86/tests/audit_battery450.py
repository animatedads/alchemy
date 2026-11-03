#!/usr/bin/env python3
"""Independent energy-ledger replay. Audit-only; never imported by the pilot."""
import argparse
import collections
import csv
import json
import math
from pathlib import Path

CAPACITY = 900.0
RADIO = 0.03
REMOTE = 100 * RADIO

def records(path):
    with path.open(newline='') as file:
        return list(csv.DictReader(file))

def clamp(x, lower, upper):
    return max(lower, min(upper, x))

def quote(row):
    yaw = clamp(float(row['yaw_cmd']), -25, 25)
    fwd = clamp(float(row['forward_cmd']), -3, 7)
    up = clamp(float(row['up_cmd']), -4, 4)
    side = clamp(float(row['side_cmd']), -3, 3)
    return 0.08 + 0.92*(abs(fwd)/3)**2 + 0.35*(abs(side)/3)**2 + 0.06*abs(yaw)/25 + 0.9*max(0,up)

def audit(prefix):
    report = {'status': 'PASS', 'aircraft': {}, 'faults': [], 'constants':
              {'capacity': CAPACITY, 'radio': RADIO, 'remote': REMOTE}}
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
    for id_ in ('A1', 'A2', 'A3'):
        rows = records(Path(f'{prefix}_{id_}_battery.csv'))
        truth = records(Path(f'{prefix}_{id_}_truth_ORACLE_ONLY.csv'))
        total_flight = total_lookup = total_radio = 0.0
        energy = CAPACITY
        last_tick = 0
        for row in rows:
            t = int(row['tick'])
            tag = f'{id_} tick {t}'
            if t != last_tick+1:
                report['faults'].append(f'{tag}: discontinuous battery tick')
            last_tick = t
            cost = quote(row)
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
            energy -= cost + REMOTE*lookup + RADIO*sent
            for field, expected in (
                ('remaining', energy), ('flight_used', total_flight),
                ('remote_used', total_lookup), ('radio_used', total_radio),
                ('percent', 100*energy/CAPACITY)):
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
        report['aircraft'][id_] = {'ticks': len(rows), 'remaining': round(energy, 6),
            'flight_used': round(total_flight, 6), 'remote_used': round(total_lookup, 6),
            'radio_used': round(total_radio, 6), 'paid_views': round(total_lookup / REMOTE),
            'radio_messages': round(total_radio / RADIO)}
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
