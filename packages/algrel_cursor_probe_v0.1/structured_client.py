#!/usr/bin/env python3
import socket, struct, sys
host='127.0.0.1'; port=int(sys.argv[1])
expected_external_integration = sys.argv[2] if len(sys.argv) > 2 else ''
FLAGS=1|4|512|8192|32768|131072|524288

def recvn(s,n):
    out=b''
    while len(out)<n:
        p=s.recv(n-len(out))
        if not p: raise EOFError
        out+=p
    return out

def readpkt(s):
    h=recvn(s,4); return h[3],recvn(s,int.from_bytes(h[:3],'little'))
def sendpkt(s,seq,p): s.sendall(len(p).to_bytes(3,'little')+bytes([seq])+p)
def lenc(p,o=0):
    b=p[o]
    if b<0xfb:return b,o+1
    if b==0xfc:return int.from_bytes(p[o+1:o+3],'little'),o+3
    if b==0xfd:return int.from_bytes(p[o+1:o+4],'little'),o+4
    if b==0xfe:return int.from_bytes(p[o+1:o+9],'little'),o+9
    if b==0xfb:return None,o+1
    raise ValueError(b)
def field(p,o):
    n,o=lenc(p,o)
    if n is None:return None,o
    return p[o:o+n].decode('utf-8','replace'),o+n

def query(s,sql):
    sendpkt(s,0,b'\x03'+sql.encode()); _,p=readpkt(s)
    if p[0]==0xff: raise RuntimeError(p)
    c,_=lenc(p); cols=[]
    for _ in range(c):
        _,q=readpkt(s); o=0; parts=[]
        for __ in range(6): v,o=field(q,o); parts.append(v)
        cols.append(parts[4])
    readpkt(s); rows=[]
    while True:
        _,q=readpkt(s)
        if q and q[0]==0xfe and len(q)<9: break
        o=0; r=[]
        for _ in range(c): v,o=field(q,o); r.append(v)
        rows.append(r)
    return cols,rows

def prepare(s,sql):
    sendpkt(s,0,b'\x16'+sql.encode()); _,p=readpkt(s)
    assert p[0]==0,p
    stmt=int.from_bytes(p[1:5],'little'); cols=int.from_bytes(p[5:7],'little'); params=int.from_bytes(p[7:9],'little')
    for _ in range(params): readpkt(s)
    if params: readpkt(s)
    for _ in range(cols): readpkt(s)
    if cols: readpkt(s)
    return stmt,cols,params

def execute_cursor(s,stmt):
    sendpkt(s,0,b'\x17'+struct.pack('<I',stmt)+b'\x01'+struct.pack('<I',1))
    _,p=readpkt(s)
    if p[0]==0xff: raise RuntimeError(p)
    cols,_=lenc(p)
    for _ in range(cols): readpkt(s)
    _,eof=readpkt(s); assert eof[0]==0xfe
    status=int.from_bytes(eof[3:5],'little'); assert status & 64,status
    return cols

def fetch(s,stmt,n):
    sendpkt(s,0,b'\x1c'+struct.pack('<I',stmt)+struct.pack('<I',n))
    rows=[]
    while True:
        _,p=readpkt(s)
        if p[0]==0xfe and len(p)<9:
            return rows,int.from_bytes(p[3:5],'little')
        rows.append(p)

def decode_varchars(row,count):
    assert row[0]==0
    # null bitmap for prepared result rows: (count + 7 + 2) // 8 bytes
    nb=(count+9)//8
    o=1+nb
    vals=[]
    for _ in range(count):
        v,o=field(row,o); vals.append(v)
    return vals

s=socket.create_connection((host,port),timeout=5); s.settimeout(10)
readpkt(s)
r=struct.pack('<I',FLAGS)+struct.pack('<I',16*1024*1024)+bytes([45])+b'\0'*23+b'nosql\0'+b'\0'+b'mysql_native_password\0'
sendpkt(s,1,r); _,p=readpkt(s); assert p[0]==0,p

stmt,cols,params=prepare(s,"SELECT fact_id,source_format,source_path,lexical_value FROM pnr_fact_sources ORDER BY fact_id")
assert cols==4 and params==0,(cols,params)
_,stats=query(s,'SELECT invocations,native_identity_preserved,source_rows,envelope_status,external_integration FROM structured_probe_stats')
assert len(stats)==1 and stats[0][:4]==['0','TRUE','3','INVALID'],stats
external_integration=stats[0][4]
assert external_integration and external_integration.startswith('NOSQL-ALGREL-EXTERNAL-'),stats
if expected_external_integration:
    assert external_integration==expected_external_integration,(external_integration,expected_external_integration)
print('PASS PREPARE/catalog path is observational and native identities are retained external_integration=' + external_integration)

assert execute_cursor(s,stmt)==4
_,stats=query(s,'SELECT invocations,native_identity_preserved FROM structured_probe_stats')
assert stats==[['1','TRUE']],stats
print('PASS cursor EXECUTE crosses Algorithm Relation materialisation exactly once')

r1,st1=fetch(s,stmt,1); assert len(r1)==1,(len(r1),st1)
r2,st2=fetch(s,stmt,99); assert len(r2)==2 and (st2 & 128),(len(r2),st2)
rows=[decode_varchars(x,4) for x in r1+r2]
assert {r[0] for r in rows}=={'G07:G07A:NSST','G07:G07B:NSST','G07:G07C:NSST'},rows
assert all(r[1]=='EDIFACT' for r in rows),rows
assert all(r[3]=='SEAT NOT PURCHASED' for r in rows),rows
assert len({r[2] for r in rows})==3,rows
_,stats=query(s,'SELECT invocations,native_identity_preserved FROM structured_probe_stats')
assert stats==[['1','TRUE']],stats
print('PASS FETCH batches reuse frozen materialisation and preserve three distinct native source paths')

_,pres=query(s,"SELECT fact_id,native_object_preserved FROM pnr_fact_sources ORDER BY fact_id")
assert len(pres)==3 and all(r[1]=='1' for r in pres),pres
_,summary=query(s,"SELECT fact_id,scalar_value,source_count FROM pnr_fact_summary ORDER BY fact_id")
assert len(summary)==3 and all(r[1]=='SEAT NOT PURCHASED' and r[2]=='1' for r in summary),summary
_,stats=query(s,'SELECT invocations,native_identity_preserved FROM structured_probe_stats')
assert stats==[['1','TRUE']],stats
print('PASS consumer sees scalar relation while evidence-bearing input/native objects remain intact')

sendpkt(s,0,b'\x19'+struct.pack('<I',stmt)); sendpkt(s,0,b'\x01'); s.close()
print('NATIVE EVIDENCE -> STRUCTURED RELATION -> ALGREL CURSOR -> CONSUMER: OK')
