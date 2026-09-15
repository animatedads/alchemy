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

# Metadata-only wire work must not execute the provider.
_,tables=query(s,'SHOW TABLES')
seen={r[0].lower() for r in tables}
for wanted in {'action_labels','algrel_provider_stats','ryta_actions','ryta_trace'}: assert wanted in seen
_,cols=query(s,'SHOW COLUMNS FROM ryta_actions'); assert len(cols)==20
_,stats=query(s,'SELECT invocations FROM algrel_provider_stats'); assert stats==[['0']], stats
print('PASS wire metadata/catalog provider invocations=0')

_,rows=query(s,"SELECT action_code,disposition FROM ryta_actions WHERE disposition='PROHIBITED' ORDER BY action_code")
assert rows==[['BIG_UPSELL','PROHIBITED'],['UPSELL','PROHIBITED']], rows
_,stats=query(s,'SELECT invocations FROM algrel_provider_stats'); assert stats==[['1']], stats
print('PASS first wire row read provider invocations=1')

_,joined=query(s,"SELECT a.action_code,a.disposition,l.label FROM ryta_actions a JOIN action_labels l ON a.action_code=l.action_code WHERE a.disposition='PROHIBITED' ORDER BY a.action_code")
assert joined==[['BIG_UPSELL','PROHIBITED','Large upsell'],['UPSELL','PROHIBITED','Upsell']], joined
_,count=query(s,'SELECT COUNT(*) AS n FROM ryta_trace'); assert count==[['26']], count
_,selected=query(s,'SELECT action_code FROM ryta_actions WHERE final_selected=1 ORDER BY action_code'); assert selected==[['ANSWER_QUERY'],['WARNING']], selected
_,stats=query(s,'SELECT invocations FROM algrel_provider_stats'); assert stats==[['1']], stats
print('PASS wire rescans/join/second relation provider invocations=1')
print('MYSQL WIRE LAZY ALGORITHM RELATION NOSQLSERVER V0.68: OK')
sendpkt(s,0,b'\x01'); s.close()
