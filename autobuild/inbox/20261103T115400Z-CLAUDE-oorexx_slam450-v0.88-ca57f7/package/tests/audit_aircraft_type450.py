#!/usr/bin/env python3
"""v0.88 offline audit: image-inferred aircraft TYPE vs true airframes.
Audit-only (uses <prefix>_airframes.csv truth); never imported by a pilot.
FAIL on any CONFIRMED belief that names the wrong airframe; report the
confusion matrix of single-sighting classifications as evidence."""
import argparse, collections, csv, json
from pathlib import Path

SEES = {'A1': {'R': 'A2', 'P': 'A3'}, 'A2': {'R': 'A1', 'P': 'A3'}, 'A3': {'R': 'A1', 'P': 'A2'}}

def audit(prefix):
    truth = {r['aircraft']: r['airframe'] for r in csv.DictReader(open(f'{prefix}_airframes.csv'))}
    faults, report = [], {'observers': {}}
    for obs, mapping in SEES.items():
        path = Path(f'{prefix}_{obs}_aircraft_types.csv')
        rows = list(csv.DictReader(open(path))) if path.exists() else []
        conf = collections.Counter(); confirmed = collections.Counter()
        for r in rows:
            actual = truth[mapping[r['symbol']]]
            conf[(actual, r['observed_type'])] += 1
            if r['confidence'] == 'CONFIRMED':
                confirmed[(actual, r['belief'])] += 1
                if r['belief'] != actual:
                    faults.append(f"{obs} tick {r['tick']} {r['symbol']}: CONFIRMED {r['belief']} but is {actual}")
        sightings = sum(conf.values())
        wrong = sum(v for (a, o), v in conf.items() if o not in ('UNKNOWN', a))
        report['observers'][obs] = {
            'sightings': sightings,
            'single_sighting_wrong': wrong,
            'single_sighting_unknown': sum(v for (a, o), v in conf.items() if o == 'UNKNOWN'),
            'confirmed_beliefs': sum(confirmed.values()),
            'confusion': {f'{a}->{o}': v for (a, o), v in sorted(conf.items())}}
    report['faults'] = faults
    report['status'] = 'PASS' if not faults else 'FAIL'
    return report

if __name__ == '__main__':
    ap = argparse.ArgumentParser(); ap.add_argument('prefix'); ap.add_argument('--out')
    a = ap.parse_args(); r = audit(a.prefix); text = json.dumps(r, indent=2)
    if a.out: Path(a.out).write_text(text + '\n')
    print(text); raise SystemExit(0 if r['status'] == 'PASS' else 2)
