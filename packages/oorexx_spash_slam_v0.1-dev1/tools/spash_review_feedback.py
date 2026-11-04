#!/usr/bin/env python3
"""Bind human review to SPASH candidate intervals without altering algorithm scores.

Human speech-presence review never asserts transcript, physical source or speaker.
A report digest and per-match digests prevent feedback being shifted to new inputs.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path

REVIEWABLE = ('HUMAN_SPEECH_PRESENT', 'NOT_HUMAN_SPEECH', 'UNDETERMINED')
EVIDENCE = 'USER_REPORTED_LISTENING_REVIEW'

def canonical(data):
    return json.dumps(data, sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode('utf-8')

def sha256(data):
    return hashlib.sha256(canonical(data)).hexdigest()

def matches_from(report):
    if report.get('schema') == 'spash.private-fixture-validation/0.2':
        entries = report.get('within_same_recording', {}).get('results')
        source = report.get('source_sha256')
    elif report.get('schema') == 'spash.example.search/0.1':
        entries = report.get('matches')
        source = report.get('query_sha256')
    else:
        raise ValueError('unsupported source report schema')
    if not isinstance(source, str) or len(source) != 64:
        raise ValueError('missing source digest')
    if not isinstance(entries, list):
        raise ValueError('missing search results')
    return entries, source

def validate_match(entry):
    required = ('query_start_s', 'query_end_s', 'candidate_start_s',
                'candidate_end_s', 'likeness')
    for key in required:
        x = entry.get(key)
        if not isinstance(x, (float, int)) or isinstance(x, bool):
            raise ValueError('invalid numeric interval/score: ' + key)
    if entry['query_start_s'] < 0 or entry['candidate_start_s'] < 0:
        raise ValueError('negative interval')
    if entry['query_start_s'] >= entry['query_end_s'] or entry['candidate_start_s'] >= entry['candidate_end_s']:
        raise ValueError('invalid interval order')
    if not 0 <= entry['likeness'] <= 1:
        raise ValueError('invalid algorithm score')
    if entry.get('authority') != 'ALGORITHM_CANDIDATE_ONLY':
        raise ValueError('unexpected algorithm authority')

def interval_clusters(reviewed, source_sha):
    """Count distinct reviewed spans, merging overlaps of the same recording.

    This is NOT a speaker count or a count of independent acoustic sources.
    """
    spans = []
    for row in reviewed:
        m = row['match']
        qsha = m.get('query_sha256', source_sha)
        csha = m.get('candidate_sha256', source_sha)
        spans.append((qsha, m['query_start_s'], m['query_end_s']))
        spans.append((csha, m['candidate_start_s'], m['candidate_end_s']))
    spans.sort()
    merged = []
    for source, start, end in spans:
        if merged and merged[-1][0] == source and start < merged[-1][2]:
            merged[-1] = (source, merged[-1][1], max(merged[-1][2], end))
        else:
            merged.append((source, start, end))
    return len(merged)

def apply(report, review):
    entries, source_sha = matches_from(report)
    if review.get('schema') != 'spash.feedback.request/0.1':
        raise ValueError('invalid review schema')
    if review.get('source_report_sha256') != sha256(report):
        raise ValueError('REPORT_HASH_MISMATCH')
    if review.get('review_authority') != EVIDENCE:
        raise ValueError('unsupported review authority')
    if not isinstance(review.get('decisions'), list) or not review['decisions']:
        raise ValueError('nonempty decisions required')
    reviewed = []
    used = set()
    for decision in review['decisions']:
        if not isinstance(decision, dict):
            raise ValueError('invalid decision')
        index = decision.get('result_index')
        if not isinstance(index, int) or isinstance(index, bool) or not 0 <= index < len(entries):
            raise ValueError('invalid match index')
        if index in used:
            raise ValueError('duplicate review of candidate index')
        used.add(index)
        label = decision.get('label')
        if label not in REVIEWABLE:
            raise ValueError('unknown review label')
        entry = entries[index]
        validate_match(entry)
        if decision.get('match_sha256') != sha256(entry):
            raise ValueError('MATCH_HASH_MISMATCH')
        reviewed.append({
            'result_index': index, 'match_sha256': sha256(entry),
            'label': label, 'evidence_authority': EVIDENCE,
            'match': entry, 'speaker_identity': 'NOT_ASSESSED',
            'transcript_identity': 'NOT_ASSESSED',
            'shared_physical_source': 'NOT_ASSESSED', 'location': 'NOT_ASSESSED'
        })
    positives = sum(r['label'] == 'HUMAN_SPEECH_PRESENT' for r in reviewed)
    negatives = sum(r['label'] == 'NOT_HUMAN_SPEECH' for r in reviewed)
    undetermined = len(reviewed) - positives - negatives
    receipt = {
        'schema': 'spash.feedback.receipt/0.1',
        'source_report_sha256': sha256(report),
        'source_sha256': source_sha, 'review_authority': EVIDENCE,
        'reviewed_candidate_count': len(reviewed),
        'human_speech_positive_count': positives,
        'human_speech_negative_count': negatives,
        'undetermined_count': undetermined,
        'unique_reviewed_source_interval_groups': interval_clusters(reviewed, source_sha),
        'reviewed_precision_only': f'{positives}/{positives+negatives}' if positives + negatives else 'NOT_ESTIMABLE',
        'recall': 'NOT_ESTIMABLE_WITHOUT_REVIEWED_NON_MATCHES',
        'independent_recording_validation': 'NOT_ESTABLISHED',
        'notes': 'User review is separate from acoustic scoring; match edges, speech intervals, and speakers are not interchangeable.',
        'reviewed': reviewed
    }
    receipt['receipt_sha256'] = sha256(receipt)
    return receipt

def main():
    parser = argparse.ArgumentParser(description='Attach external listening review to specific SPASH matches')
    parser.add_argument('--report', type=Path, required=True)
    parser.add_argument('--review', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    try:
        report = json.loads(args.report.read_text(encoding='utf-8'))
        review = json.loads(args.review.read_text(encoding='utf-8'))
        receipt = apply(report, review)
        with args.output.open('x', encoding='utf-8') as stream:
            stream.write(json.dumps(receipt, indent=2) + '\n')
    except (OSError, ValueError, TypeError, KeyError) as error:
        parser.exit(2, 'SPASH_REVIEW_REFUSED: ' + str(error) + '\n')
    print(f"SPASH_REVIEW_RECORDED {receipt['human_speech_positive_count']}/{receipt['reviewed_candidate_count']} positive user reviews; receipt={receipt['receipt_sha256']}")

if __name__ == '__main__':
    main()
