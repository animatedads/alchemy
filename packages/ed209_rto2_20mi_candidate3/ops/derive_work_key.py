#!/usr/bin/env python3
"""Derived local channel test key. Never print except via root-owned shell command-substitution."""
import argparse
import hashlib
import hmac
import pathlib
import re
from stage_mi_controller_trust import readenv

def derive(authority,mi):
    values=readenv(pathlib.Path(authority)/'nodes'/mi/'node.env')
    if values.get('GRID_NODE_ID')!=mi:raise ValueError('node binding mismatch')
    mu=values['GRID_MU_ID'];primary=values['GRID_MU_KEY_HEX']
    if not re.fullmatch('[0-9a-fA-F]{64}',primary):raise ValueError('invalid commissioning key')
    data=f'ed209.rto2.smoke.job.key.v1|{mu}|{mi}|l2'.encode('ascii')
    return hmac.new(bytes.fromhex(primary),data,hashlib.sha256).hexdigest()

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--authority',required=True);p.add_argument('--mi',required=True)
    a=p.parse_args();print(derive(a.authority,a.mi))
