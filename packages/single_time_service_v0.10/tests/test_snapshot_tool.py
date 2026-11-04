"""Offline snapshot publication/verifier tests, executable on Python 3.9+."""
from pathlib import Path
import importlib.util
import os
import shutil
import subprocess
import sys
import tempfile

script=Path(__file__).resolve().parents[1]/'tools'/'time_snapshot.py'
spec=importlib.util.spec_from_file_location('time_snapshot',script)
snapshot=importlib.util.module_from_spec(spec)
spec.loader.exec_module(snapshot)
fixture=Path(__file__).resolve().parents[1]/'fixtures'


def rejects(fn, message):
    try: fn()
    except (snapshot.SnapshotError, OSError): return
    raise AssertionError('expected rejection: '+message)

with tempfile.TemporaryDirectory() as tmp:
    root=Path(tmp)
    src=root/'source';(src/'Europe').mkdir(parents=True)
    (src/'Europe'/'London').write_bytes((fixture/'Europe'/'London').read_bytes())
    (src/'Europe'/'UTC').write_bytes((fixture/'Etc'/'UTC').read_bytes())
    snapshot.publish(src,root/'archives','a','2025b',['Europe/London'])
    snap=root/'archives'/'a'
    edition,entries,witness=snapshot.verify(root/'archives','a')
    assert edition=='2025b' and list(entries)==['Europe/London'] and len(witness)==64
    rejects(lambda:snapshot.publish(src,root/'archives','a','2025b',['Europe/London']),'create-only')
    rejects(lambda:snapshot.publish(src,root/'archives','../escape','2025b',['Europe/London']),'traversal')
    rejects(lambda:snapshot.publish(src,root/'archives','b','2025b',['../etc/passwd']),'zone traversal')
    manifest=snap/'MANIFEST.tsv'
    original=manifest.read_bytes()
    manifest.write_bytes(original.replace(b'END|1',b'END|2'))
    rejects(lambda:snapshot.verify(root/'archives','a'),'manifest count')
    manifest.write_bytes(original)
    target=snap/'zones'/'Europe'/'London'
    original=target.read_bytes()
    target.write_bytes(original[:55]+bytes([original[55]^1])+original[56:])
    rejects(lambda:snapshot.verify(root/'archives','a'),'tampered TZif')
    target.write_bytes(original)
    assert snapshot.verify(root/'archives','a')[0]=='2025b'
    snapshot.publish(src,root/'archives','b','2025b',['Europe/UTC'])
    snapshot.compare(root/'archives','a','b')
    outside=root/'outside.tzif';outside.write_bytes(original)
    link=src/'Europe'/'Outside';link.symlink_to(outside)
    rejects(lambda:snapshot.publish(src,root/'archives','escape','2025b',['Europe/Outside']),'source symlink escape')
    assert sorted(p.name for p in (root/'archives').iterdir())==['a','b']
print('PASS: publish, verify, create-only, tamper, bounds, traversal and changed sets')
