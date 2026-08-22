#!/usr/bin/env python3
import socket, struct, sys
host='127.0.0.1'; port=int(sys.argv[1])
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

def decode_two_varchars(row):
    assert row[0]==0
    # 2 cols => one NULL-bitmap byte at row[1]
    o=2; a,o=field(row,o); b,o=field(row,o); return [a,b]

s=socket.create_connection((host,port),timeout=5); s.settimeout(10)
readpkt(s)
r=struct.pack('<I',FLAGS)+struct.pack('<I',16*1024*1024)+bytes([45])+b'\0'*23+b'nosql\0'+b'\0'+b'mysql_native_password\0'
sendpkt(s,1,r); _,p=readpkt(s); assert p[0]==0,p

stmt_a,cols_a,params_a=prepare(s,'SELECT action_code,disposition FROM ryta_actions ORDER BY action_code')
stmt_t,cols_t,params_t=prepare(s,'SELECT sequence,event_text FROM ryta_trace')
assert params_a==0 and params_t==0
_,stats=query(s,'SELECT invocations FROM algrel_provider_stats'); assert stats==[['0']],stats
print('PASS two COM_STMT_PREPARE calls provider invocations=0')

assert execute_cursor(s,stmt_a)==2
_,stats=query(s,'SELECT invocations FROM algrel_provider_stats'); assert stats==[['1']],stats
print('PASS cursor EXECUTE materialized provider exactly once')

r1,st1=fetch(s,stmt_a,2); assert len(r1)==2 and (st1 & 64) and not(st1 & 128),(len(r1),st1)
r2,st2=fetch(s,stmt_a,99); assert st2 & 128,(len(r2),st2)
rows=[decode_two_varchars(x) for x in r1+r2]
assert any(x==['UPSELL','PROHIBITED'] for x in rows),rows
_,stats=query(s,'SELECT invocations FROM algrel_provider_stats'); assert stats==[['1']],stats
print('PASS COM_STMT_FETCH batches reuse frozen materialization')

assert execute_cursor(s,stmt_t)==2
tr,st=fetch(s,stmt_t,3); assert len(tr)==3,(len(tr),st)
_,stats=query(s,'SELECT invocations FROM algrel_provider_stats'); assert stats==[['1']],stats
print('PASS second prepared relation shares same provider materialization')

sendpkt(s,0,b'\x1a'+struct.pack('<I',stmt_a)); _,p=readpkt(s); assert p[0]==0,p
assert execute_cursor(s,stmt_a)==2
rr,st=fetch(s,stmt_a,1); assert len(rr)==1
_,stats=query(s,'SELECT invocations FROM algrel_provider_stats'); assert stats==[['1']],stats
print('PASS RESET + re-EXECUTE still provider invocations=1')

sendpkt(s,0,b'\x19'+struct.pack('<I',stmt_a)); sendpkt(s,0,b'\x19'+struct.pack('<I',stmt_t)); sendpkt(s,0,b'\x01'); s.close()
print('MYSQL WIRE PREPARED CURSOR ALGORITHM RELATION V0.69: OK')
