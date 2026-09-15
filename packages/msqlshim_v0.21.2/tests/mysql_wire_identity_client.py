#!/usr/bin/env python3
import socket, struct, sys
HOST='127.0.0.1'; PORT=int(sys.argv[1]) if len(sys.argv)>1 else 3461
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

def query_scalar(s,sql):
    sendpkt(s,0,b'\x03'+sql.encode())
    _,p=readpkt(s)
    if p[0]==0xff: raise AssertionError(p)
    cols,_=lenenc(p)
    assert cols==1,(sql,cols)
    for _ in range(cols): readpkt(s)
    _,p=readpkt(s)
    if p[0]==0xfe and len(p)<9:
        _,p=readpkt(s)
    n,off=lenenc(p)
    value=p[off:off+n].decode()
    # consume the final result-set terminator before issuing the next command
    readpkt(s)
    return value

s=socket.create_connection((HOST,PORT),timeout=5)
readpkt(s)
resp=struct.pack('<I',FLAGS)+struct.pack('<I',16*1024*1024)+bytes([45])+b'\0'*23+b'nosql\0'+b'\0'+b'mysql_native_password\0'
sendpkt(s,1,resp); _,p=readpkt(s); assert p[0]==0
checks={
    '@@msqlshim_version':'0.21.2',
    '@@nosqlserver_release':'0.79',
    '@@nosqlserver_sql_level':'0.79',
    '@@alchemy_object_version':'0.8',
}
for expr,want in checks.items():
    got=query_scalar(s,'SELECT '+expr)
    assert got==want,(expr,got,want)
    print('PASS',expr,'=',got)
s.close()
print('MYSQL WIRE IDENTITY SMOKE PASS')
