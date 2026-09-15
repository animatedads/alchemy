#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json
from pathlib import Path

p=argparse.ArgumentParser()
p.add_argument('--input', required=True)
p.add_argument('--output', required=True)
p.add_argument('--label', required=True)
a=p.parse_args()
src=Path(a.input); out=Path(a.output); out.mkdir(parents=True, exist_ok=True)
h=hashlib.sha256(src.read_bytes()).hexdigest()
(out/'smoke-result.json').write_text(json.dumps({'label':a.label,'input_sha256':h},sort_keys=True)+'\n')
print('managed smoke complete', a.label)
