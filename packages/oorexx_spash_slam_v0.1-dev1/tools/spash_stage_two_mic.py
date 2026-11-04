#!/usr/bin/env python3
"""Private source-verified SPASH 3D experiment queue; no fabricated feed geometry."""
from pathlib import Path
import argparse
import hashlib
import json
import math

SCHEMA='spash.spatial.two_mic.queue/0.2'

def sha256(path):
    h=hashlib.sha256()
    with open(path,'rb') as f:
        for chunk in iter(lambda:f.read(1024*1024),b''):h.update(chunk)
    return h.hexdigest()

def stage(keypoints_path):
    p=Path(keypoints_path)
    data=json.loads(p.read_text(encoding='utf-8'))
    if data.get('schema')!='spash.spatial.keypoints/0.1':
        raise ValueError('INVALID_KEYPOINT_SCHEMA')
    keys=data.get('keypoints',[])
    if len(keys)!=data.get('keypointCount') or not keys:
        raise ValueError('KEYPOINT_POPULATION_MISMATCH')
    if (data.get('sourceType')!='DERIVED_V7_LISTENING_PRODUCT'
            or data.get('virtualMicrophoneMeasurements')!=0):
        raise ValueError('INVALID_SOURCE_AUTHORITY')
    roles=['FIT_CANDIDATE','HELD_OUT_FOR_QUALIFICATION','EMBARGO_NOT_SCORED']
    counts={r:0 for r in roles}
    tasks=[]; seen=set()
    for row in keys:
        identifier=row['keypointId']
        if identifier in seen:raise ValueError('DUPLICATE_KEYPOINT')
        seen.add(identifier)
        group=row['experimentPartition']
        if group not in counts:raise ValueError('INVALID_PARTITION')
        counts[group]+=1
        span=row['sourceTime']
        first,anchor,last=[float(span[k]) for k in ('startSeconds','anchorSeconds','endSeconds')]
        if not all(map(math.isfinite,[first,anchor,last])) or not (0<=first<=anchor<=last<=data['sourceDurationSeconds']):
            raise ValueError('INVALID_TIME_SPAN')
        if span['originalFeedSampleIndex'] is not None or row['originalFeedMapping']!='NOT_YET_PINNED':
            raise ValueError('UNQUALIFIED_SOURCE_MAPPING')
        tasks.append({
            'keypointId':identifier,
            'experimentPartition':group,
            'derivedTimeWindow':{'startSeconds':first,'anchorSeconds':anchor,'endSeconds':last},
            'measuredInputs':{'originalFeedFC':'REQUIRED_NOT_SUPPLIED',
                              'originalFeedFD':'REQUIRED_NOT_SUPPLIED',
                              'twoMicrophonePose':'REQUIRED_NOT_SUPPLIED',
                              'observedTdoaAndUncertainty':'REQUIRED_NOT_SUPPLIED',
                              'clockMappingToV7':'REQUIRED_NOT_SUPPLIED'},
            'cameraInputs':{'vehicleTrajectory':'OPTIONAL_NOT_SUPPLIED',
                            'videoClockModel':'REQUIRED_FOR_VISUAL_CORROBORATION'},
            'candidateMethods':['DIRECT_PATH','STATIC_REFLECTION','MOVING_VEHICLE_REFLECTION'],
            'virtualMicrophones':{'count':4,'authority':'MODEL_ONLY'},
            'processingPolicy':{'gainProvider':'AUDIO_V9_WHISPER_TRACKER',
                                'holdGainDuringVehicleOrLoudTransient':True,
                                'dynamicFiltering':'AUDIO_V9_RECONSTRUCTION_ONLY',
                                'noAutomaticVoiceDeletion':True},
            'status':'AWAIT_VERIFIED_ORIGINAL_FEEDS_AND_LOCATION_MODEL',
            'geometryStatus':'NOT_LOCALIZED'
        })
    if counts!=data.get('splitCounts'):raise ValueError('SPLIT_MISMATCH')
    return {'schema':SCHEMA,'sourceKeypointFileSha256':sha256(p),
            'keypointCount':len(keys),'counts':counts,
            'observedMicrophoneCountRequired':2,'virtualMicrophoneCount':4,
            'processingIntent':'ORIGINAL_FEED_FC_FD_WITH_PHYSICS_WORLD_AND_AUDIO_V9',
            'cameraMotionRole':'TIME_PRIOR_AND_REFLECTOR_PATH_CONTEXT_NOT_MIC_MEASUREMENT',
            'sourceStatus':'MISSING_ORIGINAL_FEED_GEOMETRY_AND_CLOCK_MAPPING',
            'modelFitStatus':'NOT_RUN','tasks':tasks}

def main():
    ap=argparse.ArgumentParser(description='Stage SPASH private V7 3D experiment queue')
    ap.add_argument('--keypoints',type=Path,required=True)
    ap.add_argument('--output',type=Path,required=True)
    a=ap.parse_args()
    result=stage(a.keypoints)
    with a.output.open('x',encoding='utf-8') as f:
        json.dump(result,f,indent=2);f.write('\n')
    print(json.dumps({k:v for k,v in result.items()
                      if k not in ('tasks','sourceKeypointFileSha256')},indent=2))
if __name__=='__main__':main()
