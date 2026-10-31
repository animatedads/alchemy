#!/usr/bin/env python3
"""Synthetic offline SPASH V7 archive integrity tests; no intercepted audio."""
import csv
import hashlib
import io
import json
import sys
import tempfile
import zipfile
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from spash_v7_validate import validate

def sha(x):
    return hashlib.sha256(x).hexdigest()

with tempfile.TemporaryDirectory(prefix='spash-v7-qc-') as root:
    root=Path(root)
    source=root/'private-original.ogg'
    source.write_bytes(b'dummy-only-not-real-audio')
    clip=b'dummy-derivative-for-hash-validation'
    columns=('id','start_s','end_s','duration_s','tier','relative_path','sha256','size_bytes')
    row={'id':'T-001','start_s':'2.0','end_s':'3.0','duration_s':'1.0','tier':'A',
         'relative_path':'hour_00/T-001.ogg','sha256':sha(clip),'size_bytes':str(len(clip))}
    manifest={'schema':'spash.v7.full_clip_library/0.1',
              'source_duration_s':10.0,'source_sha256':sha(source.read_bytes()),
              'candidate_number':1,'rendered_clips':1,
              'total_encoded_bytes':len(clip),
              'classification_authority':'VOICE_LIKE_CANDIDATE_NOT_VERIFIED'}
    output=io.StringIO()
    writer=csv.DictWriter(output,fieldnames=columns)
    writer.writeheader();writer.writerow(row)

    def write(name, m=manifest, r=output.getvalue(), data=clip):
        with zipfile.ZipFile(name,'w',compression=zipfile.ZIP_DEFLATED) as z:
            z.writestr('SPASH_V7/manifest.json',json.dumps(m))
            z.writestr('SPASH_V7/index.csv',r)
            z.writestr('SPASH_V7/hour_00/T-001.ogg',data)

    valid=root/'valid.zip'
    write(valid)
    actual=validate(valid,source)
    assert actual['status']=='PASS'
    assert actual['clip_hashes_verified']==1
    assert actual['source_hash_checked'] is True
    assert actual['classification_authority']=='NOT_VERIFIED_BY_INTEGRITY_TEST'

    def refused(path,expected,source_path=None):
        try:
            validate(path,source_path)
        except ValueError as error:
            assert expected in str(error),(expected,str(error))
            return
        raise AssertionError('missing refusal '+expected)

    bad=root/'bad.zip'
    write(bad,data=b'edited clip bytes')
    refused(bad,'CLIP_HASH_MISMATCH')
    changed=root/'changed.ogg'
    changed.write_bytes(b'edited source')
    refused(valid,'SOURCE_HASH_MISMATCH',changed)
    wrong=root/'wrong.zip'
    write(wrong,m={**manifest,'classification_authority':'HUMAN_SPEECH_CONFIRMED'})
    refused(wrong,'INVALID_CLASSIFICATION_AUTHORITY')
    count=root/'count.zip'
    write(count,m={**manifest,'candidate_number':2})
    refused(count,'COUNT_MISMATCH')
    traversal=root/'traversal.zip'
    with zipfile.ZipFile(valid) as z, zipfile.ZipFile(traversal,'w') as out:
        for name in z.namelist(): out.writestr(name,z.read(name))
        out.writestr('SPASH_V7/../../private.bin','x')
    refused(traversal,'UNSAFE_ARCHIVE_PATH')
    print('SPASH V7 offline integrity validator: 9/9 PASS')
