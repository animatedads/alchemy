#!/usr/bin/env python3
"""SPASH source-hash-gated match-only listening replay (not source separation).

Consumes spash.example.search/0.1 JSON from spash_find_similar.py.
Exports exact PCM intervals with source hash, sample range, and clip hash.
"""
import argparse
import hashlib
import json
import sys
import wave
from pathlib import Path

REQUIRED_SCHEMA = 'spash.example.search/0.1'


def sha256_file(path):
    digest = hashlib.sha256()
    with open(path, 'rb') as source:
        while True:
            data = source.read(1024 * 1024)
            if not data:
                break
            digest.update(data)
    return digest.hexdigest()


def read_region(path, expected_sha256, start_s, end_s):
    path = Path(path)
    if sha256_file(path) != expected_sha256:
        raise ValueError(f'SOURCE_HASH_MISMATCH: {path}')
    with wave.open(str(path), 'rb') as source:
        if (source.getnchannels(), source.getsampwidth(), source.getframerate(),
                source.getcomptype()) != (1, 2, 8000, 'NONE'):
            raise ValueError(f'UNSUPPORTED_WAV: {path}')
        start = round(float(start_s) * 8000)
        end = round(float(end_s) * 8000)
        if not (0 <= start < end <= source.getnframes()):
            raise ValueError(f'BAD_SAMPLE_RANGE: {path}: [{start}, {end})')
        source.setpos(start)
        data = source.readframes(end - start)
    if len(data) != 2 * (end - start):
        raise ValueError(f'TRUNCATED_WAV: {path}')
    return data, start, end


def write_wav_exclusive(path, data):
    with open(path, 'xb') as output:
        with wave.open(output, 'wb') as dest:
            dest.setnchannels(1)
            dest.setsampwidth(2)
            dest.setframerate(8000)
            dest.writeframes(data)


def render(report, output_dir, max_matches=5):
    if report.get('schema') != REQUIRED_SCHEMA:
        raise ValueError('INVALID_SEARCH_REPORT_SCHEMA')
    if not isinstance(report.get('matches'), list):
        raise ValueError('MISSING_MATCHES_ARRAY')
    if not isinstance(max_matches, int) or not 1 <= max_matches <= 100:
        raise ValueError('INVALID_MAX_MATCHES')
    chosen = report['matches'][:max_matches]
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    manifest_path = output_dir / 'SPASH_REPLAY_MANIFEST.json'
    destinations = [manifest_path]
    for i, match in enumerate(chosen, start=1):
        destinations.extend([output_dir / f'match_{i:03d}_query.wav',
                             output_dir / f'match_{i:03d}_candidate.wav'])
    if any(p.exists() for p in destinations):
        raise ValueError('OUTPUT_ALREADY_EXISTS: refusing to overwrite listening evidence')
    prepared = []
    for i, match in enumerate(chosen, start=1):
        if match.get('authority') != 'ALGORITHM_CANDIDATE_ONLY':
            raise ValueError('UNSUPPORTED_MATCH_AUTHORITY')
        qdata, qs, qe = read_region(report['query'], report['query_sha256'],
                                   match['query_start_s'], match['query_end_s'])
        cdata, cs, ce = read_region(match['candidate'], match['candidate_sha256'],
                                   match['candidate_start_s'], match['candidate_end_s'])
        prepared.append((i, match, qdata, cdata, qs, qe, cs, ce))
    receipts = []
    for i, match, qdata, cdata, qs, qe, cs, ce in prepared:
        qpath = output_dir / f'match_{i:03d}_query.wav'
        cpath = output_dir / f'match_{i:03d}_candidate.wav'
        write_wav_exclusive(qpath, qdata)
        write_wav_exclusive(cpath, cdata)
        receipts.append({
            'rank': i,
            'similarity_algorithm_score_not_probability': match['likeness'],
            'query': {'source_path': report['query'],
                      'source_sha256': report['query_sha256'],
                      'start_sample': qs, 'end_sample_exclusive': qe,
                      'clip': qpath.name, 'clip_sha256': sha256_file(qpath)},
            'candidate': {'source_path': match['candidate'],
                          'source_sha256': match['candidate_sha256'],
                          'start_sample': cs, 'end_sample_exclusive': ce,
                          'clip': cpath.name, 'clip_sha256': sha256_file(cpath)},
            'authority': 'LISTENING_CLIPS_FROM_SOURCE_BYTES_NOT_INDEPENDENT_RECOVERY',
        })
    manifest = {
        'schema': 'spash.replay.receipt/0.1',
        'source_query_sha256': report['query_sha256'], 'clips': receipts,
        'limitations': ['No source identity', 'No location recovered',
                        'No independent microphone measurement',
                        'Listening copies, not original source evidence']
    }
    with open(manifest_path, 'x', encoding='utf-8') as output:
        json.dump(manifest, output, indent=2)
        output.write('\n')
    return manifest


def main():
    parser = argparse.ArgumentParser(description='SPASH match-only replay with source hash gate')
    parser.add_argument('--result', type=Path, required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--max-matches', type=int, default=5)
    args = parser.parse_args()
    try:
        with args.result.open(encoding='utf-8') as source:
            report = json.load(source)
        receipt = render(report, args.output_dir, args.max_matches)
    except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError, wave.Error) as exc:
        print(json.dumps({'status':'REPLAY_REFUSED', 'reason':str(exc)}), file=sys.stderr)
        return 2
    print(json.dumps({'status':'REPLAY_PLAN_RENDERED', 'clips':len(receipt['clips']),
                      'manifest':str(args.output_dir/'SPASH_REPLAY_MANIFEST.json')}, indent=2))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
