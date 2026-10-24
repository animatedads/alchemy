#!/usr/bin/env python3
from pathlib import Path
import re, sys
root=Path(__file__).resolve().parents[1]
lines=(root/'mvs/asm/MASLIVE.asm').read_text().splitlines()

def decode_values(data):
    p=0; out=[]
    while p < len(data):
        if p+8 > len(data): raise ValueError(f'prefix truncated at {p}')
        typ,flags,taglen,res=data[p:p+4]
        if res != 0: raise ValueError(f'reserved byte nonzero at {p+3}')
        vlen=int.from_bytes(data[p+4:p+8],'big'); p+=8
        if p+taglen+vlen > len(data):
            raise ValueError(f'value truncated at {p}: tag={taglen} value={vlen} total={len(data)}')
        tag=data[p:p+taglen]; p+=taglen
        value=data[p:p+vlen]; p+=vlen
        out.append((typ,tag,value))
    return out

def extract(label):
    start=None
    for i,line in enumerate(lines):
        if re.match(r'^'+re.escape(label)+r'\s+DC\s+',line): start=i; break
    if start is None: raise ValueError(f'missing {label}')
    data=b''
    for line in lines[start:]:
        if line is not lines[start] and False: pass
        if re.match(r'^[A-Z0-9]+L\s+EQU\s+\*-'+re.escape(label)+r'\b',line): break
        mx=re.search(r'\bDC\s+X\'([0-9A-F]+)\'',line)
        if mx: data += bytes.fromhex(mx.group(1)); continue
        mf=re.search(r'\bDC\s+F\'(-?\d+)\'',line)
        if mf: data += int(mf.group(1)).to_bytes(4,'big',signed=True)
    return data

expected={
 'HELLOP':[(3,b'CCSID',4)], 'PINGP':[(1,b'ECHO',5)],
 'QOPENP':[(2,b'NAME',8)], 'QPUTP':[(6,b'HANDLE',4),(1,b'DATA',7)],
 'QDEPTHP':[(6,b'HANDLE',4)], 'QGETP':[(6,b'HANDLE',4)],
 'DBOPENP':[(2,b'NAME',9)], 'DBPUTP':[(6,b'HANDLE',4),(1,b'KEY',2),(1,b'VALUE',3)],
 'DBGETP':[(6,b'HANDLE',4),(1,b'KEY',2)], 'MLISTP':[(6,b'HANDLE',4)],
 'MOPENP':[(6,b'HANDLE',4),(2,b'MAILBOX',7),(3,b'UIDVALIDITY',4),(3,b'UID',4)],
 'MBODYP':[(6,b'MESSAGE',4)], 'SFROMP':[(6,b'HANDLE',4),(2,b'ADDRESS',21)],
 'STOP':[(6,b'HANDLE',4),(2,b'ADDRESS',19)], 'STEXTP':[(6,b'HANDLE',4),(1,b'DATA',9)],
 'SSIGNP':[(6,b'HANDLE',4),(3,b'VERIFIED',4)],
 'SSENDP':[(6,b'HANDLE',4),(3,b'AUTHORIZED',4),(3,b'EGRESS',4)],
 'POPNWP':[(2,b'PATH',18),(2,b'OPTS',23),(2,b'FILEDATA',8)],
 'PWRITEP':[(6,b'HANDLE',4),(1,b'DATA',13)], 'PCLOSEP':[(6,b'HANDLE',4)],
 'POPNRP':[(2,b'PATH',18),(2,b'OPTS',9),(2,b'FILEDATA',8)],
 'PREADP':[(6,b'HANDLE',4)]
}
errors=[]
for label,want in expected.items():
    try:
        got=[(t,tag,len(v)) for t,tag,v in decode_values(extract(label))]
    except Exception as e:
        errors.append(f'{label}: {e}'); continue
    if got != want: errors.append(f'{label}: got={got!r} expected={want!r}')
if errors:
    print('FAIL MVS_TYPED_PAYLOADS')
    for e in errors: print(' -',e)
    sys.exit(1)
print(f'PASS MVS_TYPED_PAYLOADS payloads={len(expected)}')
