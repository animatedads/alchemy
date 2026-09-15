#!/usr/bin/env python3
import socket, struct, sys
HOST='127.0.0.1'; PORT=int(sys.argv[1]) if len(sys.argv)>1 else 3468
CLIENT_LONG_PASSWORD=1
CLIENT_LONG_FLAG=4
CLIENT_CONNECT_WITH_DB=8
CLIENT_PROTOCOL_41=512
CLIENT_TRANSACTIONS=8192
CLIENT_SECURE_CONNECTION=32768
CLIENT_MULTI_RESULTS=131072
CLIENT_PLUGIN_AUTH=524288
CLIENT_CONNECT_ATTRS=1<<20
FLAGS=(CLIENT_LONG_PASSWORD|CLIENT_LONG_FLAG|CLIENT_CONNECT_WITH_DB|CLIENT_PROTOCOL_41|
       CLIENT_TRANSACTIONS|CLIENT_SECURE_CONNECTION|CLIENT_MULTI_RESULTS|
       CLIENT_PLUGIN_AUTH|CLIENT_CONNECT_ATTRS)

def recvn(s,n):
    out=b''
    while len(out)<n:
        p=s.recv(n-len(out))
        if not p: raise EOFError('socket closed')
        out += p
    return out

def readpkt(s):
    h=recvn(s,4); n=int.from_bytes(h[:3],'little'); return h[3],recvn(s,n)

def sendpkt(s,seq,p):
    s.sendall(len(p).to_bytes(3,'little')+bytes([seq])+p)

def le(s):
    b=s if isinstance(s,bytes) else s.encode()
    if len(b)>=251: raise ValueError('test string too long')
    return bytes([len(b)])+b

def connect(attrs, declared_adjust=0):
    s=socket.create_connection((HOST,PORT),timeout=5)
    _,hello=readpkt(s)
    nul=hello.index(b'\0',1); base=nul+1
    caps=int.from_bytes(hello[base+13:base+15],'little') | (int.from_bytes(hello[base+18:base+20],'little')<<16)
    assert caps & CLIENT_CONNECT_ATTRS, hex(caps)
    body=b''.join(le(k)+le(v) for k,v in attrs)
    resp=(struct.pack('<I',FLAGS)+struct.pack('<I',16*1024*1024)+bytes([45])+b'\0'*23+
          b'attr_user\0'+b'\0'+b'nosqlserver\0'+b'mysql_native_password\0'+
          bytes([len(body)+declared_adjust])+body)
    sendpkt(s,1,resp)
    return s, readpkt(s)

s,(seq,p)=connect([('_client_name','msqlshim-v019-probe'),('_program_name','raw-connect-attrs')])
assert p[0]==0, (seq,p.hex())
print('PASS CLIENT_CONNECT_ATTRS handshake accepted named attributes')
sendpkt(s,0,b'\x03SELECT DATABASE()')
_,hdr=readpkt(s); assert hdr[0]==1
readpkt(s) # coldef
readpkt(s) # metadata EOF
_,row=readpkt(s)
assert b'nosqlserver' in row, row
readpkt(s) # final EOF
print('PASS CLIENT_CONNECT_WITH_DB selects handshake database')
s.close()

# A declared attribute block longer than the supplied bytes must be rejected
# during the handshake rather than silently mis-parsed as a valid session.
s,(seq,p)=connect([('_client_name','bad')], declared_adjust=3)
assert p[0]==0xff, (seq,p.hex())
assert b'connection attributes' in p.lower(), p
print('PASS malformed connection-attribute block rejected')
s.close()
print('MYSQL WIRE CONNECT ATTRIBUTES SMOKE PASS')
