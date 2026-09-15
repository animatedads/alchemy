#!/usr/bin/env python3
import socket, struct, sys
HOST='127.0.0.1'; PORT=int(sys.argv[1]) if len(sys.argv)>1 else 3676
FLAGS=1|4|512|8192|32768|131072|524288

def recvn(s,n):
    out=b''
    while len(out)<n:
        p=s.recv(n-len(out))
        if not p: raise EOFError
        out+=p
    return out

def readpkt(s):
    h=recvn(s,4); n=int.from_bytes(h[:3],'little'); return h[3],recvn(s,n)
def sendpkt(s,seq,p): s.sendall(len(p).to_bytes(3,'little')+bytes([seq])+p)

def lenenc(buf,off=0):
    b=buf[off]
    if b<0xfb: return b,off+1
    if b==0xfc: return int.from_bytes(buf[off+1:off+3],'little'),off+3
    if b==0xfd: return int.from_bytes(buf[off+1:off+4],'little'),off+4
    if b==0xfe: return int.from_bytes(buf[off+1:off+9],'little'),off+9
    raise ValueError(b)

def auth(s):
    readpkt(s)
    resp=struct.pack('<I',FLAGS)+struct.pack('<I',16*1024*1024)+bytes([45])+b'\0'*23+b'nosql\0'+b'\0'+b'mysql_native_password\0'
    sendpkt(s,1,resp); _,p=readpkt(s); assert p[0]==0,p

def field(payload,pos):
    if payload[pos]==0xfb: return None,pos+1
    n,pos=lenenc(payload,pos)
    return payload[pos:pos+n].decode('utf-8','replace'),pos+n

def query(s,sql):
    sendpkt(s,0,b'\x03'+sql.encode())
    _,p=readpkt(s)
    if p[0]==0xff: raise AssertionError((sql,p))
    if p[0]==0x00: return []
    cols,_=lenenc(p)
    for _ in range(cols): readpkt(s)
    readpkt(s)
    rows=[]
    while True:
        _,p=readpkt(s)
        if p[0]==0xfe and len(p)<9: break
        off=0; row=[]
        for _ in range(cols):
            v,off=field(p,off); row.append(v)
        rows.append(row)
    return rows

def invocations(s):
    rows=query(s,'SELECT invocations FROM structured_provider_stats')
    assert len(rows)==1,rows
    return int(rows[0][0])

s=socket.create_connection((HOST,PORT),timeout=5); s.settimeout(10); auth(s)
assert invocations(s)==0

tables={r[0] for r in query(s,'SHOW TABLES')}
assert {'structured_fact_summary','structured_fact_sources','structured_fact_trace','structured_provider_stats'} <= tables,tables
cols=query(s,'SHOW COLUMNS FROM structured_fact_summary')
assert len(cols)>=10,len(cols)
assert invocations(s)==0
print('PASS metadata/catalog provider invocations=0')

summary=query(s,"SELECT fact_id,evidence_state,projection_state,scalar_value,source_count,authority_disposition FROM structured_fact_summary ORDER BY fact_id")
assert len(summary)==4,summary
by_id={r[0]:r for r in summary}
q=by_id['ORDER_QUANTITY']
assert q[1]=='CONFLICT',q
assert q[2]=='SCALAR_REFUSED',q
assert q[3] is None,q
assert q[4]=='2',q
assert q[5]=='EVIDENCE_ONLY',q
assert invocations(s)==1
print('PASS first data read materialized once; quantity conflict remained non-scalar')

sources=query(s,"SELECT source_format,source_kind,source_path,lexical_value,native_object_preserved FROM structured_fact_sources WHERE fact_id='ORDER_QUANTITY' ORDER BY source_format")
assert len(sources)==2,sources
formats={r[0] for r in sources}
assert formats=={'XML','X12'},sources
assert all(r[4] in ('1','TRUE','true') for r in sources),sources
assert all(r[2] for r in sources),sources
assert invocations(s)==1
print('PASS two native quantity provenance rows survive wire projection; provider still=1')

all_sources=query(s,'SELECT fact_id,source_format,source_path FROM structured_fact_sources ORDER BY fact_id,source_format')
assert len(all_sources)==5,all_sources
assert invocations(s)==1
print('PASS repeated/scalar source reads provider invocations remains=1')

sendpkt(s,0,b'\x01'); s.close()
print('MYSQL WIRE STRUCTURED RICH EVIDENCE V0.16: OK')
