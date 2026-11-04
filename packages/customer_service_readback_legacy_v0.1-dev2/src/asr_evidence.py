#!/usr/bin/env python3
"""Convert independent provider word evidence to legacy readback's pinned schema.

No online calls, identity inference, approval, or media mutation. Inputs remain
unverified until human review and independent provenance/authentication.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
from pathlib import Path
from urllib.parse import unquote, urlsplit

from legacy_recovery import PLAN_SCHEMA, TRANSCRIPT_SCHEMA, valid_sha

SCHEMA = 'customer.agent.transcript.provider-evidence/0.2'


def offset_s(value):
    if isinstance(value, bool) or value is None:
        raise ValueError('MISSING_WORD_OFFSET')
    if isinstance(value, str) and value.endswith('s'):
        try: result = float(value[:-1])
        except ValueError: raise ValueError('INVALID_WORD_OFFSET') from None
    elif isinstance(value, dict):
        if not ('seconds' in value or 'nanos' in value):
            raise ValueError('MISSING_WORD_OFFSET')
        seconds, nanos = value.get('seconds', 0), value.get('nanos', 0)
        if any(isinstance(v, bool) or not isinstance(v, (int, float, str)) for v in (seconds,nanos)):
            raise ValueError('INVALID_WORD_OFFSET')
        try: result = float(seconds) + float(nanos) / 1_000_000_000
        except ValueError: raise ValueError('INVALID_WORD_OFFSET') from None
    elif isinstance(value, (int, float)):
        result = float(value)
    else:
        raise ValueError('INVALID_WORD_OFFSET')
    if not math.isfinite(result) or result < 0:
        raise ValueError('INVALID_WORD_OFFSET')
    return result


def clip_id(uri):
    """URI basename only; a provider response does not grant media authority."""
    return Path(unquote(urlsplit(str(uri)).path)).stem


def google_words(raw, job, source_uri=None):
    if raw.get('error'):
        raise ValueError('GOOGLE_RESPONSE_ERROR')
    results = raw.get('results')
    if results is None and isinstance(raw.get('response'), dict):
        response = raw['response']
        if response.get('error'): raise ValueError('GOOGLE_RESPONSE_ERROR')
        results = response.get('results')
    if isinstance(results, dict):
        matching = []
        for uri, value in results.items():
            if source_uri is not None:
                matches = uri == source_uri
            else:
                matches = clip_id(uri) == job['id']
            if matches: matching.append((uri, value))
        if len(matching) != 1:
            raise ValueError('GOOGLE_BATCH_CLIP_AMBIGUOUS_OR_MISSING')
        _, entry = matching[0]
        if entry.get('error'):
            raise ValueError('GOOGLE_BATCH_ENTRY_ERROR')
        results = entry.get('transcript', {}).get('results')
    if not isinstance(results, list):
        raise ValueError('MISSING_GOOGLE_RESULTS')
    words = []
    for result in results:
        alternatives = result.get('alternatives', [])
        if not alternatives: continue
        if not isinstance(alternatives, list) or not isinstance(alternatives[0], dict):
            raise ValueError('INVALID_GOOGLE_ALTERNATIVES')
        for word in alternatives[0].get('words', []):
            if 'startOffset' in word or 'endOffset' in word:
                start = offset_s(word.get('startOffset'))
                end = offset_s(word.get('endOffset'))
            else:
                start = offset_s(word.get('startTime'))
                end = offset_s(word.get('endTime'))
            words.append({'word': word.get('word', ''), 'start_s': start, 'end_s':end,
                          'confidence': word.get('confidence')})
    return words


def azure_words(raw, job, source_uri=None):
    if raw.get('status') in ('Failed','Canceled'):
        raise ValueError('AZURE_RESPONSE_FAILED')
    source = raw.get('source')
    if source is not None and (source != source_uri if source_uri is not None else clip_id(source) != job['id']):
        raise ValueError('AZURE_SOURCE_MISMATCH')
    phrases = raw.get('recognizedPhrases')
    if not isinstance(phrases, list):
        raise ValueError('MISSING_AZURE_PHRASES')
    words = []
    for phrase in phrases:
        if phrase.get('recognitionStatus') != 'Success': continue
        alternatives = phrase.get('nBest')
        if not isinstance(alternatives, list) or not alternatives:
            raise ValueError('MISSING_AZURE_ALTERNATIVE')
        best = alternatives[0]
        if 'words' in best: items = best['words']
        else: items = best.get('displayWords', [])
        for word in items:
            start = word.get('offsetInTicks', word.get('offset'))
            duration = word.get('durationInTicks', word.get('duration'))
            if any(isinstance(n,bool) or not isinstance(n, int) or n < 0 for n in (start,duration)):
                raise ValueError('AZURE_WORD_TICKS_REQUIRED')
            words.append({'word':word.get('word',word.get('display','')),
                          'start_s':start/10_000_000,'end_s':(start+duration)/10_000_000,
                          'confidence':word.get('confidence')})
    return words


def normalize(job, provider, raw, raw_bytes, source_uri=None):
    if not isinstance(raw, dict) or not isinstance(raw_bytes, bytes):
        raise ValueError('INVALID_RESPONSE')
    if not isinstance(job,dict) or not valid_sha(job.get('media_ref',{}).get('sha256')) or not valid_sha(job.get('audio_ref',{}).get('sha256')):
        raise ValueError('UNPINNED_MEDIA')
    if provider == 'google': words = google_words(raw, job, source_uri)
    elif provider == 'azure': words = azure_words(raw, job, source_uri)
    else: raise ValueError('UNSUPPORTED_PROVIDER')
    if not words: raise ValueError('NO_WORD_TIMESTAMPS')
    validated=[]
    last_start=-1.0
    media_duration=float(job['duration_s'])
    shift=float(job['source_audio_start_s'])-float(job['source_video_start_s'])
    if not math.isfinite(media_duration) or media_duration<=0 or not math.isfinite(shift):
        raise ValueError('INVALID_SOURCE_CLOCK')
    for i,w in enumerate(words):
        s,e=w['start_s'],w['end_s']
        if not isinstance(w['word'],str) or not w['word'].strip():
            raise ValueError(f'EMPTY_WORD_{i}')
        if not all(math.isfinite(v) for v in (s,e)) or not (0<=s<e) or s<last_start:
            raise ValueError(f'INVALID_WORD_INTERVAL_{i}')
        last_start=s
        if s+shift < -1e-6 or e+shift > media_duration+1e-6:
            raise ValueError(f'WORD_OUTSIDE_SOURCE_MEDIA_{i}')
        conf=w['confidence']
        if conf is not None and (isinstance(conf,bool) or not isinstance(conf,(int,float)) or not math.isfinite(conf) or conf<0 or conf>1):
            raise ValueError(f'INVALID_CONFIDENCE_{i}')
        validated.append({'word':w['word'],'start_s':round(s,9),'end_s':round(e,9),'confidence':conf})
    return {'schema':TRANSCRIPT_SCHEMA,'clip':job['id'],'provider':provider,
            'provider_evidence_schema':SCHEMA,'status':'RECOGNIZED_UNVERIFIED',
            'timestamp_origin':'extracted_audio_start','timestamp_precision':'provider_estimate_not_sample_exact',
            'source_sha256':job['media_ref']['sha256'], 'audio_sha256':job['audio_ref']['sha256'],
            'response_sha256':hashlib.sha256(raw_bytes).hexdigest(),
            'provider_response_authentication':'NOT_ESTABLISHED_BY_LOCAL_IMPORT',
            'asset_authority_granted':False,'words':validated}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--plan',type=Path,required=True);p.add_argument('--clip',required=True)
    p.add_argument('--provider',choices=('google','azure'),required=True)
    p.add_argument('--response',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
    p.add_argument('--source-uri')
    a=p.parse_args()
    plan=json.loads(a.plan.read_text(encoding='utf-8'))
    if plan.get('schema') != PLAN_SCHEMA: raise SystemExit('INVALID_WORK_PLAN')
    jobs=[j for j in plan['jobs'] if j['id']==a.clip]
    if len(jobs)!=1: raise SystemExit('UNLISTED_OR_DUPLICATE_CLIP')
    raw_bytes=a.response.read_bytes()
    evidence=normalize(jobs[0],a.provider,json.loads(raw_bytes),raw_bytes,a.source_uri)
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(evidence,indent=2,sort_keys=True)+'\n',encoding='utf-8')
    print(json.dumps({'clip':a.clip,'provider':a.provider,'words':len(evidence['words']),
                      'status':evidence['status'],'asset_authority_granted':False}))

if __name__ == '__main__':main()
