#!/usr/bin/env python3
import socket, struct, sys, time
HOST='127.0.0.1'; PORT=int(sys.argv[1]) if len(sys.argv)>1 else 3469
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
def handshake(user):
    s=socket.create_connection((HOST,PORT),timeout=5)
    _,g=readpkt(s)
    conn_id=int.from_bytes(g[g.find(b'\0',1)+1:g.find(b'\0',1)+5],'little')
    resp=struct.pack('<I',FLAGS)+struct.pack('<I',16*1024*1024)+bytes([45])+b'\0'*23+user.encode()+b'\0'+b'\0'+b'mysql_native_password\0'
    sendpkt(s,1,resp); _,p=readpkt(s); assert p[0]==0
    return s,conn_id

def lenenc(p,off=0):
    b=p[off]
    if b<0xfb:return b,off+1
    if b==0xfc:return int.from_bytes(p[off+1:off+3],'little'),off+3
    if b==0xfd:return int.from_bytes(p[off+1:off+4],'little'),off+4
    if b==0xfe:return int.from_bytes(p[off+1:off+9],'little'),off+9
    raise ValueError

def result_rows(s):
    _,p=readpkt(s); ncols,_=lenenc(p)
    for _ in range(ncols): readpkt(s)
    _,p=readpkt(s)
    rows=[]
    while True:
        _,p=readpkt(s)
        if p and p[0]==0xfe and len(p)<9: break
        vals=[]; off=0
        for _ in range(ncols):
            if p[off]==0xfb: vals.append(None); off+=1
            else:
                n,off=lenenc(p,off); vals.append(p[off:off+n].decode(errors='replace')); off+=n
        rows.append(vals)
    return rows

a,id_a=handshake('alpha')
b,id_b=handshake('beta')

sendpkt(a,0,b'\x03SHOW PROCESSLIST')
rows=result_rows(a)
ids={int(r[0]) for r in rows}
assert id_a in ids and id_b in ids, (id_a,id_b,rows)
users={r[1] for r in rows}
assert {'alpha','beta'} <= users
assert all(r[7]=='' for r in rows), rows
print('PASS SHOW PROCESSLIST exposes both active sessions without SQL text')

sendpkt(b,0,b'\x0a')
rows2=result_rows(b)
ids2={int(r[0]) for r in rows2}
assert id_a in ids2 and id_b in ids2
print('PASS COM_PROCESS_INFO uses same active-session snapshot')

a.shutdown(socket.SHUT_RDWR)
a.close()
time.sleep(0.1)
# allow server to process EOF before b asks again
sendpkt(b,0,b'\x0e'); _,p=readpkt(b); assert p[0]==0
sendpkt(b,0,b'\x03SHOW PROCESSLIST')
rows3=result_rows(b)
ids3={int(r[0]) for r in rows3}
assert id_a not in ids3 and id_b in ids3, (id_a,id_b,rows3)
print('PASS disconnected session removed from process list')
b.close()
print('MYSQL WIRE PROCESSLIST SMOKE PASS')
