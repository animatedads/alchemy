#!/usr/bin/env python3
"""SPASH human-review receipt integrity and noninflation tests (synthetic)."""
import copy
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from spash_review_feedback import apply, sha256, EVIDENCE

sample_sha = 'a'*64
def entry(q0,q1,c0,c1,score):
    return {'query_start_s':q0,'query_end_s':q1,'candidate_start_s':c0,'candidate_end_s':c1,
            'likeness':score,'authority':'ALGORITHM_CANDIDATE_ONLY'}
report = {'schema':'spash.private-fixture-validation/0.2','source_sha256':sample_sha,
          'within_same_recording':{'results':[
              entry(8.96,9.92,6.88,7.68,.873957),
              entry(6.72,7.68,8.96,9.92,.869682),
              entry(6.72,7.68,1.92,2.72,.862893)]}}
review = {'schema':'spash.feedback.request/0.1',
          'source_report_sha256':sha256(report),
          'review_authority':EVIDENCE,
          'decisions':[{'result_index':i,'match_sha256':sha256(x),
                        'label':'HUMAN_SPEECH_PRESENT'}
                       for i,x in enumerate(report['within_same_recording']['results'])]}
n=0
receipt=apply(report,review)
for condition in (
    receipt['reviewed_candidate_count']==3,
    receipt['human_speech_positive_count']==3,
    receipt['human_speech_negative_count']==0,
    receipt['reviewed_precision_only']=='3/3',
    receipt['unique_reviewed_source_interval_groups']==3,
    receipt['recall']=='NOT_ESTIMABLE_WITHOUT_REVIEWED_NON_MATCHES',
    receipt['independent_recording_validation']=='NOT_ESTABLISHED',
    all(x['speaker_identity']=='NOT_ASSESSED' for x in receipt['reviewed']),
    all(x['shared_physical_source']=='NOT_ASSESSED' for x in receipt['reviewed']),
    sha256(receipt)!=receipt['receipt_sha256']
):
    assert condition
    n+=1

def refused(changed,expected):
    global n
    try:
        apply(report,changed)
    except ValueError as exc:
        assert expected in str(exc),str(exc)
        n+=1
        return
    raise AssertionError('expected refusal: '+expected)

bad=copy.deepcopy(review)
bad['source_report_sha256']='0'*64
refused(bad,'REPORT_HASH_MISMATCH')
bad=copy.deepcopy(review)
bad['decisions'][0]['match_sha256']='b'*64
refused(bad,'MATCH_HASH_MISMATCH')
bad=copy.deepcopy(review)
bad['decisions'][0]['label']='SAME_SPEAKER'
refused(bad,'unknown review label')
bad=copy.deepcopy(review)
bad['decisions'].append(copy.deepcopy(bad['decisions'][1]))
refused(bad,'duplicate review')
bad=copy.deepcopy(review)
bad['review_authority']='ALGORITHM_CANDIDATE_ONLY'
refused(bad,'unsupported review authority')
assert apply(report,review)['receipt_sha256']==receipt['receipt_sha256']
n+=1
assert n==16,n
print('SPASH human review provenance and noninflation: 16/16 PASS')
