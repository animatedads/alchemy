#!/usr/bin/env python3
"""Independent offline SLAM 450 two-aircraft race audit, NEVER pilot input.
Does not rely on the race referee's collision assertions; intersects 125 model
solids with each swept craft path and verifies concurrent 3D separation.
"""
from __future__ import annotations
import argparse,csv,json,math,sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from audit_flight450_v2 import load,cuboid,hitbox

def xyz(row): return tuple(float(row[k]) for k in ('x_east_m','y_north_m','z_m'))
def sweptgap(p0,p1,q0,q1):
    r=[p0[i]-q0[i] for i in range(3)]
    v=[(p1[i]-p0[i])-(q1[i]-q0[i]) for i in range(3)]
    den=sum(x*x for x in v)
    t=max(0,min(1,-sum(r[i]*v[i] for i in range(3))/den)) if den>1e-12 else 0
    return math.sqrt(sum((r[i]+t*v[i])**2 for i in range(3)))

def audit(prefix, scene, out):
    p=Path(prefix)
    tracks={a:load(str(p)+'_'+a+'_truth_ORACLE_ONLY.csv') for a in ['A1','A2']}
    feeds=load(str(p)+'_fixed_camera.csv');claims=load(str(p)+'_claims.csv')
    course={int(r['target']):xyz({'x_east_m':r['east_m'],'y_north_m':r['north_m'],'z_m':r['z_m']}) for r in load(str(p)+'_course_ORACLE_ONLY.csv')}
    boxes=[(r['name'],cuboid(r)) for r in load(scene)]
    issues=[];minimum_gap=float('inf');minimum_z=float('inf');max_step=0
    n=min(len(tracks['A1']),len(tracks['A2']))
    if n<10 or n!=len(tracks['A1']) or n!=len(tracks['A2']):issues.append('INCOMPLETE_OR_UNEQUAL_TRACKS')
    for name,rs in tracks.items():
        if [int(r['tick']) for r in rs]!=list(range(1,len(rs)+1)):issues.append(name+':NONCONSECUTIVE_TICKS')
        for k,entry in enumerate(rs):
            dest=xyz(entry);minimum_z=min(minimum_z,dest[2])
            if dest[2]<=2:issues.append(name+f':OCEAN_CONTACT_TICK_{k+1}')
            if k==0:continue # initial positions validated separately by the referee
            start=xyz(rs[k-1]);max_step=max(max_step,math.dist(start,dest))
            if math.dist(start,dest)>13.5:issues.append(name+f':JUMP_{k+1}')
            for bname,verts in boxes:
                # Exactly the referee's 2m axis-aligned displacement shell.
                offsets=((0,0,0),(2,0,0),(-2,0,0),(0,2,0),(0,-2,0),(0,0,2),(0,0,-2))
                for o in offsets:
                    if hitbox(tuple(start[i]+o[i] for i in range(3)),tuple(dest[i]+o[i] for i in range(3)),verts):
                        issues.append(name+f':SOLID_INTERCEPT_{k+1}_{bname}');break
    for k in range(n):
        p1=xyz(tracks['A1'][k]);p2=xyz(tracks['A2'][k]);gap=math.dist(p1,p2)
        if k>0:gap=min(gap,sweptgap(xyz(tracks['A1'][k-1]),p1,xyz(tracks['A2'][k-1]),p2))
        minimum_gap=min(minimum_gap,gap)
        if gap<3.999:issues.append(f'AIRCRAFT_CONTACT_TICK_{k+1}')
    steps=[int(r['tick']) for r in feeds if r['status']=='GRANTED']
    if any(r['status']!='GRANTED' for r in feeds):issues.append('FIXED_CAMERA_DENIED_IN_SCHEDULED_SLOTS')
    if steps and steps[0]<5:issues.append('FIXED_CAMERA_EARLY')
    if any(b-a<5 for a,b in zip(steps,steps[1:])):issues.append('FIXED_CAMERA_RATE_VIOLATION')
    claimlist=[]
    for c in claims:
        step=int(c['tick']);idx=int(c['target']);who=c['winner'];f=float(c['contact_fraction'])
        if idx not in course or who not in tracks or not 0<=f<=1:issues.append(f'INVALID_CLAIM_{step}');continue
        if step<2 or step>n:issues.append(f'CLAIM_WITHOUT_VALID_STEP_{step}');continue
        old=xyz(tracks[who][step-2]);new=xyz(tracks[who][step-1]);target=course[idx]
        pos=tuple(old[i]+f*(new[i]-old[i]) for i in range(3))
        contact=math.dist(pos,target)
        claimlist.append(dict(tick=step,target=idx,winner=who,intercept_m=round(contact,4)))
        if contact>2.51:issues.append(f'CLAIM_OUTSIDE_CAPTURE_RADIUS_{idx}')
    if len({x['target'] for x in claimlist})!=len(claimlist):issues.append('DUPLICATE_TARGET_CLAIM')
    log={}
    for name in tracks:
        mem=load(str(p)+'_'+name+'_rival_air_memory.csv')
        sensor=load(str(p)+'_'+name+'_sensors.csv')
        if len(mem)>48:issues.append(name+':MEMORY_EXCEEDS_BOUND')
        if any('east_mps' in field or 'bearing_deg' in field or 'true' in field for field in mem[0].keys() if mem):issues.append(name+':POTENTIAL_ORACLE_LEAK')
        if len(sensor)!=n:issues.append(name+':MISSING_RESTRICTED_SENSORS')
        log[name]={'wind_image_memory_slots':len(mem),'altitude_trials':max(0,len(load(str(p)+'_'+name+'_altitude_trials.csv'))),'wind_ideas':sorted({x['wind_idea'] for x in mem})}
    result={'status':'PASS_PARTIAL_RACE_SYNTHETIC_ONLY' if not issues else 'FAIL',
       'steps':n,'shared_claims':claimlist,'claims_total':len(claimlist),'aircraft_minimum_swept_gap_m':round(minimum_gap,4),
       'minimum_altitude_m':round(minimum_z,4),'max_displacement_per_tick_m':round(max_step,4),
       'fixed_camera_grants_global':len(steps),'minimum_grant_spacing_steps':min((b-a for a,b in zip(steps,steps[1:])),default=None),
       'structure_count':len(boxes),'private_memories':log,'problems':issues,
       'cautions':['Partial 75-step race: NOT all 5 targets collected',
                   'Only synthetic PowerSLAM solids and sea surface checked, not complete real Sydney terrain',
                   'Rival motion and wind explanations are image hypotheses, not independently measured meteorological truth']}
    Path(out).write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k not in ('cautions','private_memories')},indent=2))
    return not issues

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('prefix');p.add_argument('--scene',required=True);p.add_argument('--out',required=True)
    a=p.parse_args();sys.exit(0 if audit(a.prefix,a.scene,a.out) else 7)
