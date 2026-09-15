#!/usr/bin/env python3
import socket, struct, sys
HOST='127.0.0.1'; PORT=int(sys.argv[1]) if len(sys.argv)>1 else 3459
CLIENT_LONG_PASSWORD=1
CLIENT_LONG_FLAG=4
CLIENT_PROTOCOL_41=512
CLIENT_TRANSACTIONS=8192
CLIENT_SECURE_CONNECTION=32768
CLIENT_MULTI_RESULTS=131072
CLIENT_PLUGIN_AUTH=524288
CLIENT_DEPRECATE_EOF=1<<24
CLIENT_OPTIONAL_RESULTSET_METADATA=1<<25
FLAGS=(CLIENT_LONG_PASSWORD|CLIENT_LONG_FLAG|CLIENT_PROTOCOL_41|CLIENT_TRANSACTIONS|
       CLIENT_SECURE_CONNECTION|CLIENT_MULTI_RESULTS|CLIENT_PLUGIN_AUTH|
       CLIENT_DEPRECATE_EOF|CLIENT_OPTIONAL_RESULTSET_METADATA)

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

def lenenc(data,off=0):
    first=data[off]
    if first < 0xfb: return first,off+1
    if first==0xfc: return int.from_bytes(data[off+1:off+3],'little'),off+3
    if first==0xfd: return int.from_bytes(data[off+1:off+4],'little'),off+4
    if first==0xfe: return int.from_bytes(data[off+1:off+9],'little'),off+9
    raise ValueError('bad lenenc')

s=socket.create_connection((HOST,PORT),timeout=5)
_,hello=readpkt(s)
nul=hello.index(b'\0',1)
base=nul+1
server_caps=int.from_bytes(hello[base+4+8+1:base+4+8+1+2],'little') | (int.from_bytes(hello[base+4+8+1+2+1+2:base+4+8+1+2+1+2+2],'little')<<16)
assert server_caps & CLIENT_DEPRECATE_EOF
assert server_caps & CLIENT_OPTIONAL_RESULTSET_METADATA
print('PASS handshake advertises CLIENT_DEPRECATE_EOF and CLIENT_OPTIONAL_RESULTSET_METADATA')
resp=struct.pack('<I',FLAGS)+struct.pack('<I',16*1024*1024)+bytes([45])+b'\0'*23+b'nosql\0'+b'\0'+b'mysql_native_password\0'
sendpkt(s,1,resp); _,p=readpkt(s); assert p[0]==0

sendpkt(s,0,b'\x03SELECT VERSION()')
seq,p=readpkt(s)
assert p[0] == 1, (seq,p.hex())  # RESULTSET_METADATA_FULL
count,off=lenenc(p,1)
assert count == 1
print('PASS optional-metadata result header carries RESULTSET_METADATA_FULL + column_count=1')
seq,col=readpkt(s)
assert b'VERSION()' in col
# With CLIENT_DEPRECATE_EOF there is no metadata EOF; the next packet is row data.
seq,row=readpkt(s)
assert b'NoSQLServer-ooRexx' in row, row
seq,term=readpkt(s)
assert term[0] == 0xfe and len(term) == 7, term.hex()
print('PASS CLIENT_DEPRECATE_EOF omits metadata EOF and terminates rows with OK-style 0xFE packet')

# Prepared SELECT metadata should likewise omit legacy EOF separators.
sendpkt(s,0,b'\x16SELECT * FROM customer WHERE customer_id = ?')
_,prep=readpkt(s)
assert prep[0]==0 and len(prep)>=12
stmt=int.from_bytes(prep[1:5],'little'); cols=int.from_bytes(prep[5:7],'little'); params=int.from_bytes(prep[7:9],'little')
assert cols==3 and params==1
# one parameter definition, then immediately three column definitions (no EOF in between)
_,paramdef=readpkt(s); assert b'?' in paramdef
coldefs=[]
for _ in range(3):
    _,cp=readpkt(s); coldefs.append(cp)
assert any(b'customer_id' in x for x in coldefs)
print('PASS COM_STMT_PREPARE metadata separators honor CLIENT_DEPRECATE_EOF')
# close statement, no response
sendpkt(s,0,b'\x19'+struct.pack('<I',stmt))
s.close()
print('MYSQL WIRE MODERN METADATA SMOKE PASS')
