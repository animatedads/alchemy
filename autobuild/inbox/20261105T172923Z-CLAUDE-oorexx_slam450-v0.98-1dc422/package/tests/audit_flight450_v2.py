#!/usr/bin/env python3
"""Independent offline flight auditor. Pilot and world simulation are native
iooRexx. Python audit reads sealed evidence only; not used for navigation.
"""
import argparse,csv,math,json,statistics
from pathlib import Path

def load(p):
    b=Path(p).read_bytes()
    if b'\0' in b: raise ValueError(f'Corrupt NUL bytes in {p}')
    with Path(p).open(newline='',encoding='utf8') as f:return list(csv.DictReader(f))

def cuboid(r):
    return [tuple(float(r[f'v{k}{q}']) for q in 'xyz') for k in [1,2,3,5]]

def hitbox(a,b,vertices,margin=0):
    v1,v2,v3,v5=vertices
    ux0=v3[0]-v1[0];uy0=v3[1]-v1[1]
    vx0=v2[0]-v1[0];vy0=v2[1]-v1[1]
    la=math.hypot(ux0,uy0);lb=math.hypot(vx0,vy0)
    assert la>0.01 and lb>0.01
    ux,uy=ux0/la,uy0/la;vx,vy=vx0/lb,vy0/lb
    cx=v1[0]+(ux0+vx0)/2;cy=v1[1]+(uy0+vy0)/2
    def transform(p):
        dx=p[0]-cx;dy=p[1]-cy
        return (dx*ux+dy*uy,dx*vx+dy*vy,p[2])
    s=transform(a);e=transform(b)
    low=(-la/2-margin,-lb/2-margin,v1[2]-margin)
    high=(la/2+margin,lb/2+margin,v5[2]+margin)
    enter=0;leave=1
    for i in range(3):
        d=e[i]-s[i]
        if abs(d)<1e-12:
            if s[i]<low[i] or s[i]>high[i]:return False
        else:
            t1=(low[i]-s[i])/d;t2=(high[i]-s[i])/d
            enter=max(enter,min(t1,t2));leave=min(leave,max(t1,t2))
            if enter>leave:return False
    return leave>0 and enter<1

def angle(a,b):return (a-b+180)%360-180

def audit(prefix,scene,out):
    rs=load(prefix+'_truth_ORACLE_ONLY.csv')
    course=load(prefix+'_course_ORACLE_ONLY.csv')
    feeds=load(prefix+'_fixed_requests.csv')
    poses=load(prefix+'_estimated.csv')
    mem=load(prefix+'_visual_memory.csv')
    boxes=[(r['name'],cuboid(r)) for r in load(scene)]
    problems=[];arrivals=[];distance=0;maxstep=0;maxturn=0;minheight=65
    if len(course)!=5:problems.append('COURSE_COUNT_NOT_FIVE')
    if len(rs)<10:problems.append('INSUFFICIENT_TRAJECTORY')
    if [int(r['step']) for r in rs]!=list(range(1,len(rs)+1)):problems.append('MISSING_DUPLICATE_OR_NONCONSECUTIVE_STEPS')
    if any(r['status'] not in ('RUNNING','COMPLETE') for r in rs):problems.append('INTERRUPTED_OR_COLLIDED')
    if rs[-1]['status']!='COMPLETE' or int(rs[-1]['active_target'])!=6:problems.append('COURSE_NOT_FINISHED')
    last=(270.,-610.,65.,230.)
    prevstage=1
    for r in rs:
        xyz=tuple(float(r[k]) for k in ('x_east_m','y_north_m','z_m'))
        yaw=float(r['yaw_deg']);step=int(r['step'])
        d=math.dist(last[:3],xyz);turn=abs(angle(yaw,last[3]))
        distance+=d;maxstep=max(maxstep,d);maxturn=max(maxturn,turn);minheight=min(minheight,xyz[2])
        if d>9 or turn>25.001:problems.append(f'SPATIAL_JUMP_{step}')
        if xyz[2]<=2:problems.append(f'WATER_CONTACT_{step}')
        for name,verts in boxes:
            if hitbox(last[:3],xyz,verts,1.9):
                problems.append(f'STRUCTURE_BUFFER_CONTACT_{step}_{name}')
        stage=int(r['active_target'])
        if stage>prevstage:
            if stage!=prevstage+1:problems.append(f'SKIPPED_TARGET_{step}')
            if stage-2>=len(course):problems.append(f'UNKNOWN_TARGET_{step}')
            else:
                target=course[stage-2]
                dest=tuple(float(target[k]) for k in ('x_east_m','y_north_m','z_m'))
                delta=math.dist(xyz,dest)
                arrivals.append({'target':stage-1,'step':step,'distance_m':round(delta,3),'region':target['region']})
                if delta>2.5001:problems.append(f'FALSE_TARGET_REACHED_{step}')
        if stage<prevstage:problems.append(f'BACKWARD_TARGET_COUNTER_{step}')
        prevstage=stage;last=(*xyz,yaw)
    if len(arrivals)!=5:problems.append('TARGET_ARRIVAL_COUNT')
    grants=[r for r in feeds if r['result']=='GRANTED']
    if len(grants)!=len(feeds):problems.append('INVALID_FIXED_CAMERA_REQUEST')
    permitted={'CAFE_SYDNEY','OPERA_WEST_WALK','KIRRIBILLI','NORTH_PTZ','BLUES_PT'}
    if any(r['camera'] not in permitted for r in grants):problems.append('INVALID_FIXED_CAMERA_SITE')
    steps=[int(r['step']) for r in grants]
    gaps=[b-a for a,b in zip(steps,steps[1:])]
    if steps and steps[0]<5:problems.append('CAMERA_TOO_EARLY')
    if any(g<5 for g in gaps):problems.append('FIXED_CAMERA_RATE_VIOLATION')
    poseerrs=[]
    prior={int(r['step']):r for r in rs}
    for p in poses:
        if p['status']!='IMAGE_BEARING_ESTIMATE':continue
        j=int(p['step'])
        truth=(270.,-610.,65.,230.) if j==0 else tuple(float(prior[j][k]) for k in ('x_east_m','y_north_m','z_m','yaw_deg')) if j in prior else None
        if truth is None:continue
        est=tuple(float(p[k]) for k in ('x_east_m','y_north_m','z_m','yaw_deg'))
        poseerrs.append((math.dist(truth[:3],est[:3]),abs(angle(truth[3],est[3]))))
    yaw_starts=[float(r['steering_response']) for r in mem if r['steering_response']]
    updates=[int(r['steering_updates']) for r in mem if r['steering_updates']]
    route_len=math.dist((270,-610,65),tuple(float(course[0][k]) for k in ('x_east_m','y_north_m','z_m')))
    route_len+=sum(math.dist(tuple(float(a[k]) for k in ('x_east_m','y_north_m','z_m')),tuple(float(b[k]) for k in ('x_east_m','y_north_m','z_m'))) for a,b in zip(course,course[1:]))
    summary={
        'status':'PASS_SYNTHETIC_MODEL_ONLY' if not problems else 'FAIL',
        'source':'PowerSLAM v0.40: current 125-cuboid map-snapped approach, unsurveyed, no full shoreline/DSM',
        'steps':len(rs), 'targets_reached':len(arrivals),'arrivals':arrivals,
        'distance_m':round(distance,3),'straight_leg_sum_m':round(route_len,3),
        'route_efficiency_percent':round(100*route_len/distance,2),
        'max_single_step_m':round(maxstep,3),'max_yaw_step_deg':round(maxturn,3),
        'minimum_model_altitude_m':round(minheight,3),'model_structures':len(boxes),
        'fixed_camera_grants':len(grants),'minimum_fixed_camera_step_gap':min(gaps,default=None),
        'memory_observation_samples':len(mem),'memory_last_slots':int(mem[-1]['slots']) if mem else 0,
        'yaw_start_response':round(yaw_starts[0],3) if yaw_starts else None,
        'yaw_end_logged_response':round(yaw_starts[-1],4) if yaw_starts else None,
        'yaw_response_updates_logged':max(updates) if updates else 0,
        'position_error_median_m':round(statistics.median(e[0] for e in poseerrs),3) if poseerrs else None,
        'position_error_max_m':round(max(e[0] for e in poseerrs),3) if poseerrs else None,
        'problems':problems,
        'limitations':['Synthetic collision only; not real-world airworthiness','No surveyed building DSM or shoreline admission','No confirmed live external camera access: still synthetic fixed panoramas']
    }
    Path(out).write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps({k:v for k,v in summary.items() if k not in ['arrivals','limitations']},indent=2))
    if problems:raise SystemExit(7)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('prefix');p.add_argument('--scene',required=True);p.add_argument('--out',required=True)
    args=p.parse_args();audit(args.prefix,args.scene,args.out)
