#!/usr/bin/env python3
"""Independent OFFLINE test: are camera-only memory lookbacks actually nearby?
Never supplies simulator coordinates or verdicts to the ooRexx pilot.
"""
from __future__ import annotations
import argparse, csv, json, math, statistics
from pathlib import Path

def rows(path):
    with open(path, newline='', encoding='utf8') as fh:
        return list(csv.DictReader(fh))

def audit(prefix):
    truth = {int(r['step']):tuple(float(r[k]) for k in ('x_east_m','y_north_m','z_m'))
             for r in rows(str(prefix)+'_truth_ORACLE_ONLY.csv')}
    truth[0]=(270.0,-610.0,65.0)
    memory=rows(str(prefix)+'_visual_memory.csv')
    pairs=[]
    for r in memory:
        if r['recognition'] not in ('RECOGNISED_PREVIOUS_VIEW','VISUAL_SIMILARITY_CANDIDATE'):
            continue
        step=int(r['step']); old=int(r['source_step'])
        if step not in truth or old not in truth:
            raise ValueError(f'Memory reference outside sealed trajectory: {step}, {old}')
        delta=math.dist(truth[step],truth[old])
        pairs.append({'step':step,'matched_step':old,'image_score_degrees':float(r['score']),
                      'oracle_separation_m_FOR_AUDIT_ONLY':round(delta,3)})
    n=len(pairs)
    seps=[r['oracle_separation_m_FOR_AUDIT_ONLY'] for r in pairs]
    return {'source':str(prefix),'review_scope':'SAMPLED_LOGGED_MEMORIES_ONLY',
            'matching_threshold_deg':6,'model_used_only_for_offline_audit':True,
            'logged_visual_candidates':n,
            'within_25m':sum(d<=25 for d in seps),
            'within_50m':sum(d<=50 for d in seps),
            'over_50m':sum(d>50 for d in seps),
            'max_separation_m':max(seps,default=None),
            'median_separation_m':statistics.median(seps) if seps else None,
            'conclusion':'IMAGE_MATCH_NOT_VERIFIED_PLACE_REVISIT',
            'worst_examples':sorted(pairs,key=lambda r:r['oracle_separation_m_FOR_AUDIT_ONLY'],reverse=True)[:5]}

if __name__=='__main__':
    a=argparse.ArgumentParser();a.add_argument('prefix',nargs='+');a.add_argument('--out',required=True)
    args=a.parse_args();result=[audit(Path(p)) for p in args.prefix]
    Path(args.out).write_text(json.dumps(result,indent=2)+'\n',encoding='utf8')
    print(json.dumps([{k:v for k,v in o.items() if k!='worst_examples'} for o in result],indent=2))
