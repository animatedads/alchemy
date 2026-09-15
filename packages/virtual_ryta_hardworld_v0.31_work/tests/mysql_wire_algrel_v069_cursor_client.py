#!/usr/bin/env python3
"""msqlshim v0.10 prepared cursor over a lazy Algorithm Relation."""
import socket, struct, sys
HOST='127.0.0.1'; PORT=int(sys.argv[1]) if len(sys.argv)>1 else 3640
FLAGS=1|4|512|8192|32768|131072|524288
CURSOR_EXISTS=64; LAST_ROW_SENT=128

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
def lstrb(buf,off):
    n,off=lenenc(buf,off); return buf[off:off+n],off+n

def auth(s):
    readpkt(s)
    resp=struct.pack('<I',FLAGS)+struct.pack('<I',16*1024*1024)+bytes([45])+b'\0'*23+b'nosql\0'+b'\0'+b'mysql_native_password\0'
    sendpkt(s,1,resp); _,p=readpkt(s); assert p[0]==0,p

def field(payload,pos):
    n,pos=lenenc(payload,pos)
    return payload[pos:pos+n].decode('utf-8','replace'),pos+n

def text_query(s,sql):
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
    rows=text_query(s,'SELECT invocations FROM algrel_provider_stats')
    assert len(rows)==1,rows
    return int(rows[0][0])

def prepare(s,sql):
    sendpkt(s,0,b'\x16'+sql.encode())
    _,p=readpkt(s); assert p[0]==0,p
    stmt=int.from_bytes(p[1:5],'little'); cols=int.from_bytes(p[5:7],'little'); params=int.from_bytes(p[7:9],'little')
    for _ in range(params): readpkt(s)
    if params: readpkt(s)
    for _ in range(cols): readpkt(s)
    if cols: readpkt(s)
    return stmt,cols,params

def execute_cursor(s,stmt):
    payload=b'\x17'+struct.pack('<I',stmt)+b'\x01'+struct.pack('<I',1)
    sendpkt(s,0,payload)
    _,p=readpkt(s); assert p[0]!=0xff,p
    cols,_=lenenc(p)
    for _ in range(cols): readpkt(s)
    _,eof=readpkt(s); assert eof[0]==0xfe,eof
    status=int.from_bytes(eof[3:5],'little')
    assert status & CURSOR_EXISTS,status
    return cols

def fetch(s,stmt,n,cols):
    sendpkt(s,0,b'\x1c'+struct.pack('<I',stmt)+struct.pack('<I',n))
    rows=[]
    while True:
        _,p=readpkt(s)
        if p[0]==0xfe and len(p)<9:
            return rows,int.from_bytes(p[3:5],'little')
        assert p[0]==0,p
        # 2 projected VARCHAR columns => one null-bitmap byte after row marker.
        null_bytes=(cols+7+2)//8
        off=1+null_bytes
        row=[]
        for _ in range(cols):
            v,off=lstrb(p,off); row.append(v.decode('utf-8','replace'))
        rows.append(row)

s=socket.create_connection((HOST,PORT),timeout=5); s.settimeout(10); auth(s)
assert invocations(s)==0
stmt,cols,params=prepare(s,"SELECT action_code,disposition FROM ryta_actions ORDER BY action_code LIMIT 5")
assert (cols,params)==(2,0),(cols,params)
trace_stmt,trace_cols,trace_params=prepare(s,"SELECT event_text FROM ryta_trace ORDER BY sequence LIMIT 3")
assert (trace_cols,trace_params)==(1,0),(trace_cols,trace_params)
assert invocations(s)==0
print('PASS two COM_STMT_PREPARE relations provider invocations=0')

ccols=execute_cursor(s,stmt); assert ccols==2
assert invocations(s)==1
print('PASS COM_STMT_EXECUTE cursor materialized Algorithm Relation once')

rows1,status1=fetch(s,stmt,2,ccols)
assert len(rows1)==2 and status1 & CURSOR_EXISTS and not(status1 & LAST_ROW_SENT),(rows1,status1)
assert invocations(s)==1
rows2,status2=fetch(s,stmt,20,ccols)
assert len(rows2)==3 and status2 & LAST_ROW_SENT,(rows2,status2)
assert invocations(s)==1
allrows=rows1+rows2
expected=[
 ['ANSWER_QUERY','PERMITTED'],
 ['ASK_INFORMATION','PERMITTED'],
 ['BIG_UPSELL','PROHIBITED'],
 ['ESCALATE','PERMITTED'],
 ['SELL_PRODUCT','SUPPRESSED'],
]
assert allrows==expected,allrows
print('PASS COM_STMT_FETCH 2+3 rows provider invocations remains=1')

# A second prepared cursor over a different relation from the same provider must
# reuse the one Algorithm Relation materialisation.
tcols=execute_cursor(s,trace_stmt); assert tcols==1
assert invocations(s)==1
trace_rows,trace_status=fetch(s,trace_stmt,10,tcols)
assert len(trace_rows)==3 and trace_status & LAST_ROW_SENT,(trace_rows,trace_status)
assert trace_rows[0][0].startswith('MODEL '),trace_rows[0]
assert invocations(s)==1
print('PASS second prepared relation reuses provider materialization')

# Reset/re-execute rematerializes the protocol cursor, not the algorithm.
sendpkt(s,0,b'\x1a'+struct.pack('<I',stmt)); _,p=readpkt(s); assert p[0]==0,p
execute_cursor(s,stmt)
assert invocations(s)==1
rows3,status3=fetch(s,stmt,20,ccols)
assert len(rows3)==5 and status3 & LAST_ROW_SENT,(len(rows3),status3)
assert invocations(s)==1
print('PASS cursor reset/re-execute reuses Algorithm Relation materialization')

sendpkt(s,0,b'\x19'+struct.pack('<I',stmt))
sendpkt(s,0,b'\x19'+struct.pack('<I',trace_stmt))
sendpkt(s,0,b'\x01'); s.close()
print('MYSQL WIRE V0.10 PREPARED CURSOR ALGORITHM RELATION V0.69: OK')
