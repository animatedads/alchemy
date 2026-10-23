#!/usr/bin/env python3
import json,sys
from pathlib import Path
FORBIDDEN_KEYS={'domNode','jcomponent','gtkWidget','androidView','composeNode','hwnd','rowOrdinal','url','uri','href','src','path','html','copy','description','textContent'}
def load(p): return json.loads(Path(p).read_text())
def walk(v,at='$'):
    if isinstance(v,dict):
      for k,x in v.items():
        if k in FORBIDDEN_KEYS: raise ValueError(f"forbidden renderer/content-authority key {k!r} at {at}")
        walk(x,f'{at}.{k}')
    elif isinstance(v,list):
      for i,x in enumerate(v): walk(x,f'{at}[{i}]')
def validate(t):
    if not isinstance(t,list): raise ValueError('transcript must be a JSON array')
    walk(t)
    for i,e in enumerate(t):
      if not isinstance(e,dict) or 'op' not in e: raise ValueError(f'entry {i} must be object with op')
      op=e['op']
      if op=='action.emit':
        if not isinstance(e.get('renderedRevision'),int): raise ValueError(f'action entry {i} missing integer renderedRevision')
        if e.get('action')=='WorkspaceCommand':
          wc=e.get('detail',{}).get('workspaceContext')
          if not isinstance(wc,dict) or wc.get('workspaceRef')!='MAIL.WORKSPACE' or not isinstance(wc.get('resultRevision'),int):
            raise ValueError(f'workspace action {i} missing opaque server workspaceContext evidence')
      if op=='collection.select':
        ident=e.get('identity')
        if not isinstance(ident,str) or not ident or ident.isdigit(): raise ValueError(f'collection entry {i} must carry stable application identity, not row ordinal')
      if op=='collection.range-request':
        if not isinstance(e.get('start'),int) or e['start']<0 or not isinstance(e.get('count'),int) or e['count']<=0:
          raise ValueError(f'range request {i} must carry bounded non-negative start and positive count')
      if op=='resource.require':
        for req in ('resourceId','version','contentAddress'):
          if req not in e: raise ValueError(f'resource entry {i} missing {req}')
        if not str(e['contentAddress']).startswith(('sha256:','sha512:')): raise ValueError(f'resource entry {i} lacks cryptographic content address')
      if op=='definition.deauthorised' and e.get('actionsBlocked') is not True: raise ValueError(f'deauthorised definition {i} must block actions')
    return True
def main(a):
    if len(a)!=3: print(f'usage: {a[0]} EXPECTED ACTUAL',file=sys.stderr); return 2
    x,y=load(a[1]),load(a[2])
    try: validate(x); validate(y)
    except ValueError as exc: print(f'INVALID: {exc}',file=sys.stderr); return 3
    if x!=y:
      print('MISMATCH',file=sys.stderr)
      for i in range(max(len(x),len(y))):
        aa=x[i] if i<len(x) else '<missing>'; bb=y[i] if i<len(y) else '<missing>'
        if aa!=bb: print(json.dumps({'index':i,'expected':aa,'actual':bb},indent=2),file=sys.stderr); break
      return 1
    print('PASS renderer semantic transcript matches canonical Wire UI contract v0.2'); return 0
if __name__=='__main__': raise SystemExit(main(sys.argv))