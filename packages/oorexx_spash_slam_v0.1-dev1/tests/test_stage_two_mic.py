"""Synthetic SPASH keypoint staging and fail-closed tests, no private audio."""
import copy,json,tempfile,pathlib,sys
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'tools'))
from spash_stage_two_mic import stage
with tempfile.TemporaryDirectory() as td:
 p=pathlib.Path(td)/'test.json'
 def key(i,split):
  return {'keypointId':f'T-{i}','experimentPartition':split,
          'sourceTime':{'startSeconds':i*10,'anchorSeconds':i*10+3,
                        'endSeconds':i*10+7,'originalFeedSampleIndex':None},
          'originalFeedMapping':'NOT_YET_PINNED'}
 o={'schema':'spash.spatial.keypoints/0.1','keypointCount':3,
    'sourceType':'DERIVED_V7_LISTENING_PRODUCT','virtualMicrophoneMeasurements':0,
    'sourceDurationSeconds':100,
    'splitCounts':{'FIT_CANDIDATE':1,'HELD_OUT_FOR_QUALIFICATION':1,
                   'EMBARGO_NOT_SCORED':1},
    'keypoints':[key(0,'FIT_CANDIDATE'),key(1,'HELD_OUT_FOR_QUALIFICATION'),
                 key(2,'EMBARGO_NOT_SCORED')]}
 p.write_text(json.dumps(o));r=stage(p)
 assert r['keypointCount']==3
 assert r['counts']==o['splitCounts']
 assert r['sourceStatus']=='MISSING_ORIGINAL_FEED_GEOMETRY_AND_CLOCK_MAPPING'
 assert r['modelFitStatus']=='NOT_RUN'
 assert r['tasks'][0]['virtualMicrophones']=={'count':4,'authority':'MODEL_ONLY'}
 assert all(t['geometryStatus']=='NOT_LOCALIZED' for t in r['tasks'])
 def fail(mod,error):
  bad=copy.deepcopy(o);mod(bad);p.write_text(json.dumps(bad))
  try:stage(p)
  except ValueError as e:assert error in str(e),(error,str(e))
  else:raise AssertionError('invalid queue admitted: '+error)
 fail(lambda z:z.update({'sourceType':'INDEPENDENT_FEED'}),'INVALID_SOURCE_AUTHORITY')
 fail(lambda z:z['keypoints'][0].update({'originalFeedMapping':'GUESSED'}),'UNQUALIFIED_SOURCE_MAPPING')
 fail(lambda z:z['keypoints'][1].update({'keypointId':'T-0'}),'DUPLICATE_KEYPOINT')
 fail(lambda z:z.update({'splitCounts':{'FIT_CANDIDATE':2,
     'HELD_OUT_FOR_QUALIFICATION':0,'EMBARGO_NOT_SCORED':1}}),'SPLIT_MISMATCH')
 print('SPASH 3D staging queue: 10/10 PASS')
