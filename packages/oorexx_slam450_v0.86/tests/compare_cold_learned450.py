#!/usr/bin/env python3
"""Offline matched-course evidence comparator (never available to the pilot)."""
import csv, json, hashlib, statistics, math, argparse
from pathlib import Path

def read_csv(p):
    with open(p, newline='', encoding='utf8') as fd:
        return list(csv.DictReader(fd))

def checksum(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def compare(cold, learned, cold_audit, learned_audit):
    a=read_csv(cold+'_truth_ORACLE_ONLY.csv')
    b=read_csv(learned+'_truth_ORACLE_ONLY.csv')
    ac=read_csv(cold+'_course_ORACLE_ONLY.csv')
    bc=read_csv(learned+'_course_ORACLE_ONLY.csv')
    if ac!=bc:raise ValueError('NOT MATCHED: course and target placements differ')
    c=json.loads(Path(cold_audit).read_text())
    w=json.loads(Path(learned_audit).read_text())
    if c['status']!='PASS_SYNTHETIC_MODEL_ONLY' or w['status']!='PASS_SYNTHETIC_MODEL_ONLY':
        raise ValueError('NOT QUALIFIED: one or both independent audits failed')
    delta=[]
    for r,s in zip(a,b):
        p=tuple(float(r[f]) for f in ['x_east_m','y_north_m','z_m'])
        q=tuple(float(s[f]) for f in ['x_east_m','y_north_m','z_m'])
        delta.append(math.dist(p,q))
    report={
        'classification':'MATCHED_SEED_SYNTHETIC_COMPARISON',
        'same_five_course_targets':True,
        'cold_start_response':c['yaw_start_response'],
        'learned_start_response':w['yaw_start_response'],
        'cold_steps':c['steps'],'learned_steps':w['steps'],
        'steps_saved':c['steps']-w['steps'],
        'cold_distance_m':c['distance_m'],'learned_distance_m':w['distance_m'],
        'distance_saved_m':round(c['distance_m']-w['distance_m'],3),
        'cold_median_image_pose_error_m':c['position_error_median_m'],
        'learned_median_image_pose_error_m':w['position_error_median_m'],
        'paired_positions_compared':len(delta),
        'median_paired_position_difference_m':round(statistics.median(delta),3),
        'max_paired_position_difference_m':round(max(delta),3),
        'cold_course_sha256':checksum(cold+'_course_ORACLE_ONLY.csv'),
        'learned_course_sha256':checksum(learned+'_course_ORACLE_ONLY.csv'),
        'cold_truth_sha256':checksum(cold+'_truth_ORACLE_ONLY.csv'),
        'learned_truth_sha256':checksum(learned+'_truth_ORACLE_ONLY.csv'),
        'verdict':'NO_MEASURABLE_STEP_OR_DISTANCE_IMPROVEMENT' if c['steps']==w['steps'] and abs(c['distance_m']-w['distance_m'])<0.01 else 'MEASURABLE_DIFFERENCE_REQUIRES_MULTISEED_VALIDATION',
        'qualifications':['Simulator-only safety; no surveyed terrain or DSM',
            'No transfer of oracle trajectory or targets to learned pilot',
            'Yaw calibration transfers but effect on same-course path is not established by test success alone']
    }
    return report

if __name__=='__main__':
    a=argparse.ArgumentParser();a.add_argument('cold');a.add_argument('learned');a.add_argument('--cold-audit',required=True);a.add_argument('--learned-audit',required=True);a.add_argument('--out',required=True)
    v=a.parse_args()
    result=compare(v.cold,v.learned,v.cold_audit,v.learned_audit)
    Path(v.out).write_text(json.dumps(result,indent=2)+'\n',encoding='utf8')
    print(json.dumps({k:v for k,v in result.items() if 'sha256' not in k and k!='qualifications'},indent=2))
