#!/usr/bin/env python3
import argparse, json, struct
from pathlib import Path

def parse(path: Path):
    raw=path.read_bytes(); p=0; prev=0; blocks=[]; file_no=1; rec_no=0
    while p < len(raw):
        if p+6 > len(raw): raise ValueError(f'truncated AWS header at {p}')
        cur, previous, flags = struct.unpack_from('<HHH', raw, p); p += 6
        if previous != prev:
            raise ValueError(f'previous-block chain mismatch at {p-6}: expected {prev}, got {previous}')
        if cur == 0:
            blocks.append({'kind':'tapemark','file':file_no,'offset':p-6,'flags':flags})
            file_no += 1; rec_no=0; prev=0
            continue
        if p+cur > len(raw): raise ValueError(f'truncated AWS record at {p-6}')
        data=raw[p:p+cur]; p += cur; rec_no += 1
        blocks.append({'kind':'record','file':file_no,'record':rec_no,'offset':p-cur-6,'length':cur,'flags':flags,'data':data})
        prev=cur
    return blocks

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('image', type=Path)
    ap.add_argument('--json', action='store_true')
    a=ap.parse_args(); b=parse(a.image)
    records=[x for x in b if x['kind']=='record']; marks=[x for x in b if x['kind']=='tapemark']
    first=''
    if records:
        try: first=records[0]['data'].decode('cp037')
        except Exception: first=''
    if a.json:
        out={'bytes':a.image.stat().st_size,'records':len(records),'tapemarks':len(marks),'files':(len(marks)+1 if b else 0),'first_record_cp037':first}
        print(json.dumps(out,sort_keys=True))
    else:
        print('PASS AWS_PARSE')
        print('AWS_BYTES='+str(a.image.stat().st_size))
        print('AWS_RECORDS='+str(len(records)))
        print('AWS_TAPEMARKS='+str(len(marks)))
        print('AWS_FIRST_CP037='+first)
if __name__=='__main__': main()
