#!/usr/bin/env python3
import socket, struct, zlib, sys
HOST='127.0.0.1'; PORT=int(sys.argv[1]) if len(sys.argv)>1 else 3453
CLIENT_LONG_PASSWORD=1
CLIENT_LONG_FLAG=4
CLIENT_COMPRESS=32
CLIENT_PROTOCOL_41=512
CLIENT_TRANSACTIONS=8192
CLIENT_SECURE_CONNECTION=32768
CLIENT_MULTI_RESULTS=131072
CLIENT_PLUGIN_AUTH=524288
flags=(CLIENT_LONG_PASSWORD|CLIENT_LONG_FLAG|CLIENT_COMPRESS|CLIENT_PROTOCOL_41|
       CLIENT_TRANSACTIONS|CLIENT_SECURE_CONNECTION|CLIENT_MULTI_RESULTS|CLIENT_PLUGIN_AUTH)

def recvn(s,n):
    out=b''
    while len(out)<n:
        p=s.recv(n-len(out))
        if not p: raise EOFError
        out+=p
    return out

def basic_read(s):
    h=recvn(s,4); n=int.from_bytes(h[:3],'little'); return h[3], recvn(s,n)

def basic_send(s,seq,p):
    s.sendall(len(p).to_bytes(3,'little')+bytes([seq])+p)

def comp_send(s,cseq,inner,force_compress=True):
    if force_compress:
        p=zlib.compress(inner)
        ulen=len(inner)
    else:
        p=inner; ulen=0
    s.sendall(len(p).to_bytes(3,'little')+bytes([cseq])+ulen.to_bytes(3,'little')+p)

def comp_read(s):
    h=recvn(s,7); n=int.from_bytes(h[:3],'little'); cseq=h[3]; ulen=int.from_bytes(h[4:7],'little'); p=recvn(s,n)
    if ulen:
        p=zlib.decompress(p)
        assert len(p)==ulen
    return cseq,p

s=socket.create_connection((HOST,PORT),timeout=5)
seq,greet=basic_read(s)
assert seq==0 and greet[0]==10
payload=(struct.pack('<I',flags)+struct.pack('<I',16*1024*1024)+bytes([45])+b'\0'*23+
         b'nosql\0'+b'\0'+b'mysql_native_password\0')
basic_send(s,1,payload)
seq,ok=basic_read(s)
assert seq==2 and ok[0]==0
print('PASS compressed handshake negotiation')

inner=b'\x01\x00\x00\x00\x0e'  # COM_PING basic packet seq0
comp_send(s,0,inner,True)
cseq,raw=comp_read(s)
assert cseq==1
assert len(raw)>=5
plen=int.from_bytes(raw[:3],'little'); pseq=raw[3]; pp=raw[4:4+plen]
assert pseq==1 and pp[0]==0
print('PASS compressed COM_PING client->server and compressed-layer OK server->client')

# Verify another command exchange resets compressed sequence to 0/1.
query=b'\x03SHOW VARIABLES LIKE \'protocol_compression_algorithms\''
inner=len(query).to_bytes(3,'little')+b'\x00'+query
comp_send(s,0,inner,True)
cseq,raw=comp_read(s)
assert cseq==1
plen=int.from_bytes(raw[:3],'little'); pseq=raw[3]; first=raw[4:4+plen]
assert pseq==1 and first and first[0] != 0xff
print('PASS compressed COM_QUERY response sequence reset')

s.close()
print('MYSQL WIRE COMPRESSION SMOKE PASS')
