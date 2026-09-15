#!/usr/bin/env python3
import socket, struct, sys
host='127.0.0.1'; port=int(sys.argv[1])
FLAGS=1|4|512|8192|32768|131072|524288

def recvn(s,n):
    out=b''
    while len(out)<n:
        part=s.recv(n-len(out))
        if not part: raise EOFError
        out+=part
    return out

def readpkt(s):
    h=recvn(s,4); n=int.from_bytes(h[:3],'little'); return h[3],recvn(s,n)
def sendpkt(s,seq,payload): s.sendall(len(payload).to_bytes(3,'little')+bytes([seq])+payload)
def lenc(payload,pos=0):
    b=payload[pos]
    if b < 0xfb: return b,pos+1
    if b == 0xfb: return None,pos+1
    if b == 0xfc: return int.from_bytes(payload[pos+1:pos+3],'little'),pos+3
    if b == 0xfd: return int.from_bytes(payload[pos+1:pos+4],'little'),pos+4
    if b == 0xfe: return int.from_bytes(payload[pos+1:pos+9],'little'),pos+9
    raise ValueError(b)
def field(payload,pos):
    n,pos=lenc(payload,pos)
    if n is None: return None,pos
    return payload[pos:pos+n].decode('utf-8','replace'),pos+n

def query(sock,sql):
    sendpkt(sock,0,b'\x03'+sql.encode())
    _,payload=readpkt(sock)
    if payload[0] == 0xff: raise RuntimeError(f'wire error for {sql}: {payload.hex()}')
    if payload[0] == 0x00: return [],[]
    count,_=lenc(payload,0)
    columns=[]
    for _ in range(count):
        _,col=readpkt(sock); pos=0; parts=[]
        for __ in range(6):
            value,pos=field(col,pos); parts.append(value)
        columns.append(parts[4])
    readpkt(sock)
    rows=[]
    while True:
        _,row=readpkt(sock)
        if row and row[0] == 0xfe and len(row) < 9: break
        pos=0; values=[]
        for _ in range(count):
            value,pos=field(row,pos); values.append(value)
        rows.append(values)
    return columns,rows

s=socket.create_connection((host,port),timeout=5)
readpkt(s)
response=struct.pack('<I',FLAGS)+struct.pack('<I',16*1024*1024)+bytes([45])+b'\0'*23+b'nosql\0'+b'\0'+b'mysql_native_password\0'
sendpkt(s,1,response); _,payload=readpkt(s); assert payload[0]==0

_,tables=query(s,'SHOW TABLES')
seen={r[0].lower() for r in tables}
for wanted in {'toy_policy','ryta_actions','ryta_trace','table_feed_decisions','table_feed_trace','algrel_pipeline_stats'}: assert wanted in seen, (wanted,seen)
_,cols=query(s,'SHOW COLUMNS FROM table_feed_decisions'); assert len(cols)==14, len(cols)
_,stats=query(s,'SELECT upstream_invocations,downstream_invocations FROM algrel_pipeline_stats'); assert stats==[['1','0']],stats
print('PASS table-fed wire metadata upstream=1 downstream=0')

_,rows=query(s,"SELECT row_id,preference_score,upstream_disposition,disposition,final_selected FROM table_feed_decisions ORDER BY row_id")
byid={r[0]:r for r in rows}
assert byid['BIG_UPSELL']==['BIG_UPSELL','1000000','PROHIBITED','PROHIBITED','0'],byid['BIG_UPSELL']
assert byid['WARNING']==['WARNING','-1000000','REQUIRED','REQUIRED','1'],byid['WARNING']
assert byid['SELL_PRODUCT'][3:]==['SUPPRESSED','0'],byid['SELL_PRODUCT']
assert byid['ANSWER_QUERY'][3:]==['PERMITTED','1'],byid['ANSWER_QUERY']
_,stats=query(s,'SELECT upstream_invocations,downstream_invocations FROM algrel_pipeline_stats'); assert stats==[['1','1']],stats
print('PASS first downstream wire read upstream=1 downstream=1')

_,selected=query(s,"SELECT row_id FROM table_feed_decisions WHERE final_selected=1 ORDER BY row_id")
assert selected==[['ANSWER_QUERY'],['WARNING']],selected
_,joined=query(s,"SELECT d.row_id,d.disposition,p.label FROM table_feed_decisions d JOIN toy_policy p ON d.row_id=p.action_code WHERE d.final_selected=1 ORDER BY d.row_id")
assert joined==[['ANSWER_QUERY','PERMITTED','answer'],['WARNING','REQUIRED','warn']],joined
_,trace=query(s,'SELECT COUNT(*) AS n FROM table_feed_trace'); assert trace==[['5']],trace
_,stats=query(s,'SELECT upstream_invocations,downstream_invocations FROM algrel_pipeline_stats'); assert stats==[['1','1']],stats
print('PASS downstream wire rescans/join trace upstream=1 downstream=1')
print('MYSQL WIRE TABLE-FED ALGORITHM PIPELINE V0.8: OK')
sendpkt(s,0,b'\x01'); s.close()
