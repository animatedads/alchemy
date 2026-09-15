#!/usr/bin/env python3
import socket, struct, sys
HOST='127.0.0.1'; PORT=int(sys.argv[1]) if len(sys.argv)>1 else 3454
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

s=socket.create_connection((HOST,PORT),timeout=5)
readpkt(s)
resp=struct.pack('<I',FLAGS)+struct.pack('<I',16*1024*1024)+bytes([45])+b'\0'*23+b'nosql\0'+b'\0'+b'mysql_native_password\0'
sendpkt(s,1,resp); seq,p=readpkt(s); assert p[0]==0

sendpkt(s,0,b'\x04customer\0%')
cols=[]
while True:
    seq,p=readpkt(s)
    if p and p[0]==0xfe and len(p)<9: break
    cols.append(p)
assert len(cols)==3
print('PASS COM_FIELD_LIST customer returned 3 column definitions')

sendpkt(s,0,b'\x09'); seq,p=readpkt(s); assert b'Uptime:' in p and b'Threads:' in p
print('PASS COM_STATISTICS')

sendpkt(s,0,b'\x1b\x00\x00'); seq,p=readpkt(s); assert p[0]==0
sendpkt(s,0,b'\x1b\x01\x00'); seq,p=readpkt(s); assert p[0]==0
print('PASS COM_SET_OPTION enable/disable multi-statements state')

sendpkt(s,0,b'\x1f'); seq,p=readpkt(s); assert p[0]==0
print('PASS COM_RESET_CONNECTION')

sendpkt(s,0,b'\x0d'); seq,p=readpkt(s); assert p[0]==0
print('PASS COM_DEBUG')
s.close()
print('MYSQL WIRE UTILITY SMOKE PASS')
