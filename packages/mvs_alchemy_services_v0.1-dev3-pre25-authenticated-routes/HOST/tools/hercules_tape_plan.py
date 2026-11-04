#!/usr/bin/env python3
import argparse, json
from pathlib import Path
ap=argparse.ArgumentParser(description='Generate, but do not execute, a Hercules tape attach plan.')
ap.add_argument('image', type=Path)
ap.add_argument('--device', default='0480')
ap.add_argument('--machine', default='ED209Z')
a=ap.parse_args()
if not a.image.is_file(): raise SystemExit('image not found')
print(json.dumps({
  'schema':'mvs.alchemy.hercules-tape-plan/1',
  'machine':a.machine,
  'device':a.device.upper(),
  'image':str(a.image.resolve()),
  'observe_first':['DEVLIST '+a.device.upper(),'QD '+a.device.upper()],
  'mutation':['DEVINIT '+a.device.upper()+' '+str(a.image.resolve())],
  'executed':False,
  'requires_authority':'hercules.device.manage'
},indent=2))
