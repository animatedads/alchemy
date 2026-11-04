#!/usr/bin/env python3
"""Evidence-only legacy readback recovery planner; never grants asset authority.

Records: source bytes remain in Storage Fabric; speech and vision are independent
jobs with pinned hashes. This module has no network/dispatch or identity matcher.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
import re
from pathlib import Path

PLAN_SCHEMA = 'customer.agent.readback.legacy.recovery/0.1'
CHECK_SCHEMA = 'customer.agent.readback.legacy.review/0.1'
TRANSCRIPT_SCHEMA = 'customer.agent.transcript.words/0.1'
PATTERN = re.compile(r'^(LETTER|NATO|NUM)_([A-Z]|[0-9]+)$')
ALIASES = {'alfa': 'alpha', 'juliett': 'juliet'}
DURATION_PAD_S = 0.10

def valid_sha(s):
    return isinstance(s, str) and re.fullmatch(r'[0-9a-f]{64}', s) is not None

def canonical(s):
    s = re.sub(r'^[^\w]+|[^\w]+$', '', str(s).casefold())
    return ALIASES.get(s, s)

def plan(manifest, vocabulary):
    if manifest.get('schema') != 'customer.agent.batch.prepare/0.1' or not manifest.get('complete'):
        raise ValueError('PREPARATION_NOT_COMPLETE')
    nato = {row['symbol']: row['word'] for row in vocabulary['phonetic_alphabet']}
    if set(nato) != set('ABCDEFGHIJKLMNOPQRSTUVWXYZ'):
        raise ValueError('INVALID_PHONETIC_VOCABULARY')
    jobs = []
    for clip in manifest['clips']:
        match = PATTERN.fullmatch(clip.get('id', ''))
        if not match:
            continue
        family, symbol = match.groups()
        if family == 'LETTER' and len(symbol) != 1: raise ValueError('INVALID_LETTER')
        if family == 'NATO' and (len(symbol) != 1 or symbol not in nato): raise ValueError('INVALID_NATO')
        if not (valid_sha(clip.get('source_sha256')) and valid_sha(clip.get('prepared_audio_sha256'))):
            raise ValueError('MISSING_PINNED_SOURCE_HASH')
        media = clip.get('video', {})
        dur = float(media.get('duration', 0))
        astart = float(clip.get('audio', {}).get('start_time', 0))
        vstart = float(media.get('start_time', 0))
        if not all(map(math.isfinite, (dur, astart, vstart))) or dur <= 0:
            raise ValueError('INVALID_MEDIA_TIMING')
        hint = symbol if family == 'LETTER' else (nato[symbol] if family == 'NATO' else None)
        jobs.append({'id': clip['id'], 'family': family, 'symbol': symbol,
                     'pronunciation_hint_unverified': hint,
                     'media_ref': {'member': clip['member'], 'sha256': clip['source_sha256']},
                     'audio_ref': {'path': clip['prepared_audio'], 'sha256': clip['prepared_audio_sha256']},
                     'duration_s': dur, 'source_video_start_s': vstart,
                     'source_audio_start_s': astart,
                     'requested_evidence': ['word_timestamps', 'facial_landmarks', 'source_frame_pts'],
                     'status': 'PENDING_TRANSCRIPTION_AND_REVIEW',
                     'promotion_authorized': False})
    jobs.sort(key=lambda x: x['id'])
    if len({j['id'] for j in jobs}) != len(jobs):
        raise ValueError('DUPLICATE_CLIP')
    return {'schema': PLAN_SCHEMA, 'source': manifest.get('archive'),
            'prepared_clips': manifest['processed'], 'candidate_jobs': len(jobs),
            'jobs': jobs, 'job_authority': 'DEFINITION_ONLY_NO_DISPATCH',
            'policy': 'A filename is only a pronunciation hint; require verified spoken media before reuse'}

def review(job, transcript):
    """Produce isolated audible candidates, NEVER final approval.

    A long improvised recording may contain a usable phonetic word, but such a
    candidate must be listened to and checked against facial video by a human.
    """
    errors = []
    if transcript.get('schema') != TRANSCRIPT_SCHEMA: errors.append('INVALID_TRANSCRIPT_SCHEMA')
    if transcript.get('status') not in ('RECOGNIZED_UNVERIFIED','TRANSCRIBED_UNVERIFIED'):
        errors.append('INVALID_TRANSCRIPT_STATUS')
    if transcript.get('timestamp_origin') != 'extracted_audio_start':
        errors.append('INVALID_TIMESTAMP_ORIGIN')
    if Path(str(transcript.get('clip',''))).stem != job['id']: errors.append('CLIP_ID_MISMATCH')
    if transcript.get('source_sha256') != job['media_ref']['sha256']:
        errors.append('SOURCE_SHA256_MISMATCH')
    if transcript.get('audio_sha256') != job['audio_ref']['sha256']:
        errors.append('AUDIO_SHA256_MISMATCH')
    observed = transcript.get('words')
    if not isinstance(observed, list) or not observed: errors.append('MISSING_WORDS')
    tokens=[]
    offset = job['source_audio_start_s'] - job['source_video_start_s']
    prev_start = -1.0
    for i, word in enumerate(observed if isinstance(observed,list) else []):
        if not isinstance(word,dict):errors.append(f'INVALID_WORD_{i}');continue
        s, e = word.get('start_s'), word.get('end_s')
        if not all(isinstance(x,(int,float)) and not isinstance(x,bool) and math.isfinite(x) for x in (s,e)) or s < 0 or not s < e:
            errors.append(f'INVALID_TIME_{i}');continue
        if s < prev_start:errors.append(f'NONMONOTONIC_TIME_{i}')
        prev_start=s
        vs,ve = s + offset, e + offset
        if vs < 0 or ve > job['duration_s']+0.05:
            errors.append(f'OUTSIDE_SOURCE_MEDIA_{i}')
        tokens.append({'index': i, 'heard': word.get('word',''), 'canonical':canonical(word.get('word','')),
                       'audio_start_s':s, 'audio_end_s':e, 'video_start_s':vs, 'video_end_s':ve})
    if errors:
        return {'schema':CHECK_SCHEMA,'clip':job['id'],'decision':'REJECT_EVIDENCE',
                'errors':sorted(set(errors)), 'candidates':[], 'asset_authority_granted':False}
    expected = canonical(job['pronunciation_hint_unverified']) if job['pronunciation_hint_unverified'] else None
    matches = [t for t in tokens if t['canonical'] == expected] if expected else []
    candidates=[]
    for t in matches:
        before = tokens[t['index']-1]['video_end_s'] if t['index'] else 0
        after = tokens[t['index']+1]['video_start_s'] if t['index']+1<len(tokens) else job['duration_s']
        start=max(0,t['video_start_s']-DURATION_PAD_S,before)
        end=min(job['duration_s'],t['video_end_s']+DURATION_PAD_S,after)
        if start <= t['video_start_s'] and end >= t['video_end_s'] and end>start:
            candidates.append({'word_index':t['index'],'heard':t['heard'],
                               'video_interval_s':[round(start,6),round(end,6)],
                               'source_frame_pts_required':True,
                               'contamination': 'EXTRA_SPEECH_PRESENT' if len(tokens)>1 else 'NOT_ESTABLISHED',
                               'state':'REVIEW_AUDIO_VIDEO_REQUIRED'})
    return {'schema':CHECK_SCHEMA,'clip':job['id'],
            'decision':'CANDIDATES_REQUIRE_REVIEW' if candidates else 'NO_MATCH_REGENERATE_OR_REVIEW',
            'errors':[], 'candidate_count':len(candidates), 'candidates':candidates,
            'recognized_word_count':len(tokens), 'pronunciation_hint_unverified':expected,
            'asset_authority_granted':False}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    sub=parser.add_subparsers(dest='command',required=True)
    p=sub.add_parser('plan');p.add_argument('--prepared',required=True,type=Path)
    p.add_argument('--vocab',required=True,type=Path);p.add_argument('--output',required=True,type=Path)
    v=sub.add_parser('review');v.add_argument('--plan',required=True,type=Path)
    v.add_argument('--clip',required=True);v.add_argument('--transcript',required=True,type=Path)
    v.add_argument('--output',required=True,type=Path)
    args=parser.parse_args()
    if args.command=='plan':
        result=plan(json.loads(args.prepared.read_text()),json.loads(args.vocab.read_text()))
    else:
        plan_data=json.loads(args.plan.read_text());match=[j for j in plan_data['jobs'] if j['id']==args.clip]
        if len(match)!=1:raise SystemExit('UNLISTED_CLIP')
        result=review(match[0],json.loads(args.transcript.read_text()))
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+'\n',encoding='utf-8')
    print(json.dumps({k:result[k] for k in ('schema','decision','candidate_jobs') if k in result}))

if __name__=='__main__':main()
