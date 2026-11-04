#!/usr/bin/env python3
"""Oracle-only independent auditor of 3-craft SLAM450 race logs.
Never imported by a learner. Assesses synthetic PowerSLAM solids only.
"""
import sys,csv,json,math,argparse,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from audit_flight450_v2 import load,cuboid,hitbox

def xyz(row):
    return tuple(float(row[k]) for k in ('x_east_m','y_north_m','z_m'))
def swept(p0,p1,q0,q1):
    r=tuple(p0[i]-q0[i] for i in range(3))
    v=tuple(p1[i]-p0[i]-q1[i]+q0[i] for i in range(3))
    den=sum(z*z for z in v)
    t=max(0,min(1,-sum(r[i]*v[i] for i in range(3))/den)) if den>1e-12 else 0
    return math.sqrt(sum((r[i]+t*v[i])**2 for i in range(3)))
def audit(prefix, scene, camera_mode="legacy"):
    tracks={i:load(f'{prefix}_{i}_truth_ORACLE_ONLY.csv') for i in ('A1','A2','A3')}
    course={int(r['target']):(float(r['east_m']),float(r['north_m']),float(r['z_m'])) for r in load(f'{prefix}_course_ORACLE_ONLY.csv')}
    solids=[(r['name'],cuboid(r)) for r in load(scene)]
    msgs=load(f'{prefix}_team_radio.csv')
    claims=load(f'{prefix}_claims.csv')
    feeds=load(f'{prefix}_fixed_camera.csv')
    faults=[];lengths={i:len(r) for i,r in tracks.items()}
    n=min(lengths.values())
    if n==0 or len(set(lengths.values()))!=1: faults.append('UNEQUAL_OR_EMPTY_TRACKS')
    if any([int(r['tick']) for r in rows]!=list(range(1,len(rows)+1)) for rows in tracks.values()):
        faults.append('NON_CONSECUTIVE_FLIGHT_STEPS')
    minGap=100000;maxJump=0;minZ=100000
    offsets=((0,0,0),(2,0,0),(-2,0,0),(0,2,0),(0,-2,0),(0,0,2),(0,0,-2))
    for aircraft,rows in tracks.items():
        for j,row in enumerate(rows):
            nxt=xyz(row);minZ=min(minZ,nxt[2])
            if nxt[2]<=2:faults.append(f'{aircraft}_WATER_TICK_{j+1}')
            if j==0:continue
            prev=xyz(rows[j-1]);maxJump=max(maxJump,math.dist(prev,nxt))
            if math.dist(prev,nxt)>13.5:faults.append(f'{aircraft}_JUMP_TICK_{j+1}')
            for name,vertices in solids:
                if any(hitbox(tuple(prev[k]+o[k] for k in range(3)),tuple(nxt[k]+o[k] for k in range(3)),vertices) for o in offsets):
                    faults.append(f'{aircraft}_STRUCTURE_TICK_{j+1}_{name}')
    for i,j in itertools.combinations(tracks,2):
        for k in range(n):
            a=xyz(tracks[i][k]);b=xyz(tracks[j][k]);gap=math.dist(a,b)
            if k>0:gap=min(gap,swept(xyz(tracks[i][k-1]),a,xyz(tracks[j][k-1]),b))
            minGap=min(minGap,gap)
            if gap<3.999:faults.append(f'SEPARATION_{i}_{j}_{k+1}')
    grants=[int(r['tick']) for r in feeds if r['status']=='GRANTED']
    if any(r['status']!='GRANTED' for r in feeds):faults.append('DENIED_SCHEDULED_CAMERA')
    if camera_mode=='legacy':
        if grants and grants[0]<5:faults.append('EARLY_CAMERA')
        if any(b-a<5 for a,b in zip(grants,grants[1:])):faults.append('CAMERA_RATE_VIOLATION')
    elif camera_mode=='battery':
        keys=[(r['aircraft'], int(r['tick'])) for r in feeds if r['status']=='GRANTED']
        if len(keys)!=len(set(keys)):faults.append('DUPLICATE_AIRCRAFT_LOOKUP_SAME_TICK')
        if any(t<0 or t>=n for _,t in keys):faults.append('CAMERA_REQUEST_TICK_OUT_OF_RANGE')
    else: raise ValueError('invalid camera audit mode')
    winners=[]
    for r in claims:
        tick=int(r['tick']);number=int(r['target']);winner=r['winner'];f=float(r['contact_fraction'])
        if tick<2 or tick>n or winner not in tracks or not 0<=f<=1:
            faults.append('INVALID_CLAIM_RECORD');continue
        old=xyz(tracks[winner][tick-2]);new=xyz(tracks[winner][tick-1]);goal=course[number]
        at=tuple(old[k]+f*(new[k]-old[k]) for k in range(3))
        separation=math.dist(at,goal)
        if separation>2.51:faults.append(f'FALSE_CLAIM_{number}')
        winners.append({'target':number,'winner':winner,'tick':tick,'intercept_error_m':round(separation,4)})
    if len({w['target'] for w in winners})!=len(winners):faults.append('DUPLICATE_CLAIM')
    acks=[m for m in msgs if m['kind']=='ACK' and m['event']=='QUEUED_NEXT_TICK']
    b2=load(f'{prefix}_A2_buddy_memory.csv');b3=load(f'{prefix}_A3_buddy_memory.csv')
    if len(b2)>48 or len(b3)>48:faults.append('BUDDY_MEMORY_OVERFLOW')
    if any(m['from'] not in ('A2','A3') or m['to'] not in ('A2','A3') or m['from']==m['to'] for m in msgs):
        faults.append('A1_RADIO_LEAK')
    if any(r.get('status')=='COMMITTED' and r.get('leader') not in ('A2','A3') for r in b2+b3):
        faults.append('INVALID_ELECTED_PEER')
    for id in tracks:
        s=load(f'{prefix}_{id}_sensors.csv')
        if len(s)!=n:faults.append(id+'_SENSOR_COUNT')
        if any('east_mps' in x or 'true' in x or 'wind_bearing' in x for x in s[0].keys()) if s else False:
            faults.append(id+'_SENSOR_ORACLE_COLUMN')
    leaders={m['leader'] for m in msgs if m['kind']=='ACK' and m['event']=='QUEUED_NEXT_TICK'}
    result={'status':('PASS_COMPLETE_SYNTHETIC' if len(winners)==5 else 'PASS_PARTIAL_SYNTHETIC') if not faults else 'FAIL',
            'completed_steps':n,'tracks':lengths,'claims':winners,'all_five_collected':len(winners)==5,
            'pairwise_minimum_swept_separation_m':round(minGap,4),
            'minimum_altitude_m':round(minZ,4),'maximum_interstep_distance_m':round(maxJump,4),
            'camera_mode':camera_mode,'fixed_camera_grants':len(grants),'negotiation_acks_sent':len(acks),
            'leader_candidates_recorded':sorted(leaders),'team_radio_events':len(msgs),
            'memory_slots_A2':len(b2),'memory_slots_A3':len(b3),'solids':len(solids),
            'faults':faults,'caveat':'Synthetic model audit only; flight dynamics and observations not real-world certified'}
    return result
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('prefix');p.add_argument('--scene',required=True);p.add_argument('--out',required=True);p.add_argument('--camera-mode',choices=['legacy','battery'],default='legacy')
    a=p.parse_args();res=audit(a.prefix,a.scene,a.camera_mode)
    Path(a.out).write_text(json.dumps(res,indent=2)+'\n')
    print(json.dumps(res,indent=2));sys.exit(0 if not res['faults'] else 7)
