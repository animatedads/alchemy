#!/usr/bin/env python3
"""Independent offline audit of all five cost proposals; never imported into pilots.
Checks recorded bid consistency, chosen-cost provenance, peer agreement and risk veto.
Does not claim that estimated costs predict real future expenditure accurately.
"""
import argparse, csv, json, collections
from pathlib import Path

def load(path):
    with open(path,newline='') as f: return list(csv.DictReader(f))

def audit(prefix):
    rows=load(str(prefix)+'_team_target_costs.csv')
    radios=load(str(prefix)+'_team_radio.csv')
    faults=[];bids={};proposals=collections.defaultdict(list)
    allowed_risks={'LOW','UNCERTAIN','CAUTION','HIGH','STRANDED','CLAIMED'}
    allowed_conf={'LOW','MEDIUM','HIGH','NONE'}
    for row in rows:
        epoch=int(row['epoch']); craft=row['sender']; target=int(row['target'])
        if craft not in {'A2','A3'}: faults.append('unrecognised sender')
        if row['event']=='BID':
            if target not in range(1,6): faults.append('invalid bid target')
            k=(epoch,craft,target)
            if k in bids: faults.append(f'duplicate bid {k}')
            bids[k]=row
            try: cost=float(row['estimate_energy']);remaining=float(row['reported_battery']);reserve=float(row['reported_reserve'])
            except ValueError: faults.append(f'bad number {k}');continue
            if cost<0 or cost>100000: faults.append(f'bad cost {k}')
            if reserve<0 or remaining<reserve: faults.append(f'bad reserve {k}')
            if row['risk'] not in allowed_risks: faults.append(f'unknown risk {k}')
            if row['confidence'] not in allowed_conf: faults.append(f'unknown confidence {k}')
            if not row['theory']: faults.append(f'missing theory {k}')
        elif row['event']=='PROPOSED':
            proposals[epoch].append(row)
            if target==0:
                if row['risk']!='HOLD': faults.append(f'missing hold marking {epoch} {craft}')
                continue
            b=bids.get((epoch,craft,target))
            if b is None: faults.append(f'proposal without own earlier bid {epoch} {craft} {target}');continue
            for key in ('risk','estimate_energy','theory'):
                if row[key]!=b[key]: faults.append(f'{epoch} {craft} proposal {key} differs from sent bid')
            if row['risk']=='STRANDED': faults.append(f'{epoch} {craft} assigned predicted-stranding target')
        else: faults.append(f'unknown event {row["event"]}')
    for epoch, proposals_for_epoch in proposals.items():
        versions=collections.defaultdict(set)
        for p in proposals_for_epoch:
            versions[p['sender']].add((p['target'],p['estimate_energy'],p['risk']))
        for craft in ('A2','A3'):
            if len(versions[craft])!=1: faults.append(f'epoch {epoch} contradictory {craft} proposals')
        if len(proposals_for_epoch)!=4: faults.append(f'epoch {epoch} missing reciprocal proposal')
        picked=[int(x['target']) for x in proposals_for_epoch if int(x['target'])>0]
        if len(set(picked))>2: faults.append(f'epoch {epoch} more than 2 chosen targets')
        chosen={int(next(iter(versions[c]))[0]) for c in versions if versions[c]}
        if len(chosen-{0})!=len([c for c in versions if next(iter(versions[c]))[0]!='0']):
            faults.append(f'epoch {epoch} conflicting assignments')
    sent_bid=[r for r in radios if r['kind']=='BID' and r['event']=='QUEUED_NEXT_TICK']
    sent_ack=[r for r in radios if r['kind']=='ACK' and r['event']=='QUEUED_NEXT_TICK']
    agreed=[r for r in radios if r['kind']=='ACK' and r['event']=='AGREED']
    if len(sent_bid)*5 < len(bids): faults.append('priced bids without accepted radio messages')
    if len(sent_ack)!=2*len(proposals): faults.append('priced proposals not paired with ACK transmissions')
    if len(agreed)!=len(sent_ack): faults.append('not all negotiation ACKs committed')
    out={'status':'PASS' if not faults else 'FAIL','flight_status':'PARTIAL_OR_COMPLETE_UNCHECKED',
         'priced_target_bids':len(bids),'negotiation_rounds':len(proposals),
         'recorded_assignment_proposals':sum(map(len,proposals.values())),
         'accepted_bid_packets':len(sent_bid),'reciprocal_acknowledgements':len(agreed),
         'stranding_vetoes_in_sent_bids':sum(r['risk']=='STRANDED' for r in bids.values()),
         'unsafe_stranding_assignments':sum(r['event']=='PROPOSED' and r['risk']=='STRANDED' for r in rows),
         'faults':faults}
    return out

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('prefix',type=Path);p.add_argument('--out',type=Path)
    a=p.parse_args();result=audit(a.prefix)
    if a.out: a.out.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
    raise SystemExit(0 if result['status']=='PASS' else 2)
