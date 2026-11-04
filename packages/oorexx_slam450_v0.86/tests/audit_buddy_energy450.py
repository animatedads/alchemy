#!/usr/bin/env python3
"""Independent, audit-only check of A2<->A3 energy telemetry provenance.
Never imported by the native ooRexx controllers or the race referee.
"""
import argparse
import collections
import csv
import json
import math
from pathlib import Path

THEORIES = {
    'INITIAL_SAMPLE', 'REMOTE_LOOKUPS_DOMINATE', 'CLIMB_ADDS_DRAIN',
    'HIGH_RECENT_DRAIN', 'LOW_BATTERY_RESERVE', 'NORMAL_CRUISE_DRAIN'
}


def read_csv(path):
    with path.open(newline='') as f:
        return list(csv.DictReader(f))


def audit(prefix):
    prefix = str(prefix)
    rows = read_csv(Path(prefix+'_team_energy.csv'))
    radio = read_csv(Path(prefix+'_team_radio.csv'))
    battery = {a: read_csv(Path(prefix+f'_{a}_battery.csv')) for a in ('A1','A2','A3')}
    memories = {a: read_csv(Path(prefix+f'_{a}_received_energy.csv')) for a in ('A2','A3')}
    faults=[]
    transmitted={}
    received={}
    counts=collections.Counter()
    total_ticks=len(battery['A1'])
    for row in rows:
        tick=int(row['tick'])
        sample=int(row['sample_tick'])
        frm=row['from'];to=row['to'];event=row['event']
        counts[event]+=1
        key=(frm,to,sample)
        if (frm,to) not in (('A2','A3'),('A3','A2')):
            faults.append(f'{event} invalid sender/receiver {frm}->{to}')
        if sample<0 or sample!=tick-(1 if event=='ENERGY_STORED' else 0):
            faults.append(f'{key} invalid sample/delivery tick {tick}')
        remaining=float(row['remaining']);capacity=float(row['capacity'])
        pct=float(row['percent']);n=int(row['window_turns'])
        df=float(row['delta_flight']);dr=float(row['delta_remote']);dc=float(row['delta_radio'])
        rate=float(row['burn_rate'])
        if not all(math.isfinite(x) for x in (remaining,capacity,pct,df,dr,dc,rate)):
            faults.append(f'{key} non-finite numeric')
            continue
        if not (capacity>0 and 0<=remaining<=capacity and 0<=pct<=100):
            faults.append(f'{key} invalid battery range')
        if abs(pct-100*remaining/capacity)>0.001:
            faults.append(f'{key} percent inconsistent')
        if any(x<0 for x in (n,df,dr,dc,rate)):
            faults.append(f'{key} negative energy window')
        if n and abs(rate-(df+dr+dc)/n)>0.00015:
            faults.append(f'{key} recent burn does not match category deltas')
        if n==0 and abs(rate)>0.00001:
            faults.append(f'{key} missing history yet reported nonzero burn')
        if row['theory'] not in THEORIES:
            faults.append(f'{key} unqualified theory')
        if row['confidence'] not in {'TENTATIVE','OBSERVED_COST'}:
            faults.append(f'{key} unqualified confidence')
        if event=='SENT':
            if key in transmitted: faults.append(f'duplicate send {key}')
            transmitted[key]=row
            # At sample tick, the last stored ledger reading is the most the
            # sender could claim (bids/ACK may have been sent after that snapshot).
            previous=900 if sample==0 else float(battery[frm][sample-1]['remaining'])
            if remaining>previous+0.0002 or previous-remaining>0.13:
                faults.append(f'{key} self-report not consistent with preceding meter')
        elif event=='ENERGY_STORED':
            if key in received: faults.append(f'duplicate receipt {key}')
            received[key]=row
        else:
            faults.append(f'bad energy radio event {event}')
    for key,sent in transmitted.items():
        mate=received.get(key)
        if mate is None:
            if int(sent['sample_tick'])+1<total_ticks:
                faults.append(f'not delivered despite next tick {key}')
            continue
        for name in ('remaining','capacity','percent','window_turns',
                     'delta_flight','delta_remote','delta_radio','burn_rate',
                     'cruise_steps_est','theory','confidence'):
            if sent[name]!=mate[name]:
                faults.append(f'packet mutated in transit: {key} {name}')
    if set(received)-set(transmitted):
        faults.append('received packet never sent')
    for craft in ('A2','A3'):
        expected=[r for r in rows if r['event']=='ENERGY_STORED' and r['to']==craft]
        if len(memories[craft]) != min(48,len(expected)):
            faults.append(f'{craft} received-memory length mismatch')
        for a,b in zip(memories[craft], expected[-48:]):
            if int(a['sample_tick'])!=int(b['sample_tick']) or a['theory']!=b['theory']:
                faults.append(f'{craft} stored peer report mismatch')
    queued=collections.Counter((r['from'],int(r['tick'])) for r in radio
                                if r['kind']=='ENERGY' and r['event']=='QUEUED_NEXT_TICK')
    sent=collections.Counter((r['from'],int(r['tick'])) for r in rows if r['event']=='SENT')
    if sent!=queued: faults.append('energy transmission not matched in billed radio log')
    result={
        'status':'PASS' if not faults else 'FAIL',
        'sampled_flight_ticks':total_ticks,
        'sent_energy_reports':len(transmitted),
        'delivered_energy_reports':len(received),
        'A2_stored_peer_reports':len(memories['A2']),
        'A3_stored_peer_reports':len(memories['A3']),
        'evidence_basis':'sender self-reported battery telemetry; independent ledger validates accounting',
        'faults':faults,
    }
    return result

if __name__=='__main__':
    p=argparse.ArgumentParser()
    p.add_argument('prefix',type=Path)
    p.add_argument('--out',type=Path)
    args=p.parse_args()
    result=audit(args.prefix)
    encoded=json.dumps(result,indent=2)
    print(encoded)
    if args.out: args.out.write_text(encoded+'\n')
    raise SystemExit(0 if result['status']=='PASS' else 2)
