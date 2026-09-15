#!/usr/bin/env python3
"""Classic-protocol CLIENT_QUERY_ATTRIBUTES smoke for msqlshim v0.15."""
import socket, struct, sys
HOST='127.0.0.1'; PORT=int(sys.argv[1]) if len(sys.argv)>1 else 3460
CLIENT_LONG_PASSWORD=1; CLIENT_LONG_FLAG=4; CLIENT_PROTOCOL_41=512
CLIENT_TRANSACTIONS=8192; CLIENT_SECURE_CONNECTION=32768
CLIENT_MULTI_RESULTS=131072; CLIENT_PLUGIN_AUTH=524288
CLIENT_QUERY_ATTRIBUTES=1<<27
FLAGS=(CLIENT_LONG_PASSWORD|CLIENT_LONG_FLAG|CLIENT_PROTOCOL_41|CLIENT_TRANSACTIONS|
       CLIENT_SECURE_CONNECTION|CLIENT_MULTI_RESULTS|CLIENT_PLUGIN_AUTH|CLIENT_QUERY_ATTRIBUTES)

def recvn(s,n):
    out=b''
    while len(out)<n:
        p=s.recv(n-len(out))
        if not p: raise EOFError('socket closed')
        out+=p
    return out

def readpkt(s):
    h=recvn(s,4); n=int.from_bytes(h[:3],'little'); return h[3],recvn(s,n)

def sendpkt(s,seq,p): s.sendall(len(p).to_bytes(3,'little')+bytes([seq])+p)

def le(s):
    b=s if isinstance(s,bytes) else s.encode()
    assert len(b)<251
    return bytes([len(b)])+b

def lenenc_int(n):
    assert n<251
    return bytes([n])

def auth(s):
    _,hello=readpkt(s)
    nul=hello.index(b'\0',1); base=nul+1
    caps=int.from_bytes(hello[base+13:base+15],'little') | (int.from_bytes(hello[base+18:base+20],'little')<<16)
    assert caps & CLIENT_QUERY_ATTRIBUTES, hex(caps)
    resp=struct.pack('<I',FLAGS)+struct.pack('<I',16*1024*1024)+bytes([45])+b'\0'*23+b'nosql\0'+b'\0'+b'mysql_native_password\0'
    sendpkt(s,1,resp); _,p=readpkt(s); assert p[0]==0,p
    print('PASS handshake advertises CLIENT_QUERY_ATTRIBUTES')

def read_text_result(s):
    _,p=readpkt(s)
    if p[0]==0xff: raise AssertionError(p)
    cols=p[0]
    for _ in range(cols): readpkt(s)
    _,eof=readpkt(s); assert eof[0]==0xfe
    rows=[]
    while True:
        _,p=readpkt(s)
        if p[0]==0xfe and len(p)<9: return rows
        rows.append(p)

def prepare(s,sql):
    sendpkt(s,0,b'\x16'+sql.encode()); _,p=readpkt(s); assert p[0]==0,p
    stmt=int.from_bytes(p[1:5],'little'); cols=int.from_bytes(p[5:7],'little'); params=int.from_bytes(p[7:9],'little')
    if params:
        for _ in range(params): readpkt(s)
        readpkt(s)
    if cols:
        for _ in range(cols): readpkt(s)
        readpkt(s)
    return stmt,cols,params

s=socket.create_connection((HOST,PORT),timeout=5); s.settimeout(10); auth(s)

# COM_QUERY: two binary parameters precede SQL.  First satisfies '?'; second is
# a named trace attribute that must not alter SQL semantics.
attrs=(lenenc_int(2)+lenenc_int(1)+b'\x00'+b'\x01'+
       bytes([3,0])+le(b'')+bytes([253,0])+le(b'traceparent')+
       struct.pack('<I',901)+le(b'00-test-trace-01'))
sendpkt(s,0,b'\x03'+attrs+b'SELECT * FROM customer WHERE customer_id = ?')
rows=read_text_result(s)
assert rows and b'Wire User' in rows[0],rows
print('PASS COM_QUERY positional parameter + named query attribute')

# Zero-attribute framing still carries parameter_count=0,set_count=1 before SQL.
sendpkt(s,0,b'\x03'+lenenc_int(0)+lenenc_int(1)+b'SELECT VERSION()')
rows=read_text_result(s); assert rows and b'NoSQLServer-ooRexx' in rows[0]
print('PASS COM_QUERY zero-attribute framing')

# Prepared execution: one prepared placeholder + one extra named attribute.
stmt,cols,params=prepare(s,'SELECT * FROM customer WHERE customer_id = ?')
assert (cols,params)==(3,1),(cols,params)
payload=(b'\x17'+struct.pack('<I',stmt)+bytes([8])+struct.pack('<I',1)+lenenc_int(2)+
         b'\x00'+b'\x01'+bytes([3,0])+le(b'')+bytes([253,0])+le(b'traceparent')+
         struct.pack('<I',901)+le(b'00-prepared-trace-01'))
sendpkt(s,0,payload)
rows=read_text_result(s)  # binary rows, but just ensure result sequence completes
assert rows
print('PASS COM_STMT_EXECUTE prepared parameter + extra named query attribute')
sendpkt(s,0,b'\x19'+struct.pack('<I',stmt))
s.close()
print('MYSQL WIRE QUERY ATTRIBUTES SMOKE PASS')
