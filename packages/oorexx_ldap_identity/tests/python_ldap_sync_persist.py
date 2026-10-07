#!/usr/bin/env python3
import socket, sys

SYNC_REQUEST='1.3.6.1.4.1.4203.1.9.1.1'
SYNC_STATE='1.3.6.1.4.1.4203.1.9.1.2'
SYNC_INFO='1.3.6.1.4.1.4203.1.9.1.4'
CANCEL='1.3.6.1.1.8'

def length(n):
    if n < 128: return bytes([n])
    b=n.to_bytes((n.bit_length()+7)//8,'big'); return bytes([0x80|len(b)])+b

def tlv(tag,v=b''): return bytes([tag])+length(len(v))+v
def integer(n,tag=0x02):
    b=b'\x00' if n==0 else n.to_bytes((n.bit_length()+7)//8,'big')
    if b[0]&0x80: b=b'\x00'+b
    return tlv(tag,b)
def octet(x): return tlv(0x04,x.encode() if isinstance(x,str) else x)
def msg(mid,op,controls=b''): return tlv(0x30,integer(mid)+op+(tlv(0xa0,controls) if controls else b''))
def control(oid,value=None,critical=False):
    b=octet(oid)+(tlv(0x01,b'\xff') if critical else b'')+(octet(value) if value is not None else b'')
    return tlv(0x30,b)
def recv_exact(s,n):
    o=b''
    while len(o)<n:
        p=s.recv(n-len(o))
        if not p: raise EOFError
        o+=p
    return o
def recv_frame(s):
    h=recv_exact(s,2); b=h[1]
    if b<128: n=b; ex=b''
    else: c=b&0x7f; ex=recv_exact(s,c); n=int.from_bytes(ex,'big')
    return h+ex+recv_exact(s,n)
def read_tlv(d,o=0):
    t=d[o]; o+=1; b=d[o]; o+=1
    if b<128: n=b
    else: c=b&0x7f; n=int.from_bytes(d[o:o+c],'big'); o+=c
    return t,d[o:o+n],o+n
def decode(frame):
    t,v,_=read_tlv(frame); assert t==0x30
    t,i,p=read_tlv(v); mid=int.from_bytes(i,'big')
    optag,op,p=read_tlv(v,p); ctrls=[]
    if p<len(v):
        t,cv,p=read_tlv(v,p); assert t==0xa0
        q=0
        while q<len(cv):
            t,c,q=read_tlv(cv,q); assert t==0x30
            t,oid,r=read_tlv(c); crit=False; val=None
            if r<len(c):
                t,x,r2=read_tlv(c,r)
                if t==0x01:
                    crit=x!=b'\x00'; r=r2
                    if r<len(c): t,x,r=read_tlv(c,r)
                    else: t=None
                if t is not None: assert t==0x04; val=x
            ctrls.append((oid.decode(),crit,val))
    return mid,optag,op,ctrls
def result_code(op):
    t,v,_=read_tlv(op); assert t==0x0a; return int.from_bytes(v,'big')
def bind(mid,dn,pw): return msg(mid,tlv(0x60,integer(3)+octet(dn)+tlv(0x80,pw.encode())))
def unbind(mid): return msg(mid,tlv(0x42,b''))
def eq_filter(a,v): return tlv(0xa3,octet(a)+octet(v))
def sync_persist(mid,cookie=None):
    attrs=['uid','cn','entryUUID','oorexxEntityId']; ab=b''.join(octet(a) for a in attrs)
    body=octet('dc=example,dc=org')+integer(2,0x0a)+integer(0,0x0a)+integer(0)+integer(0)+tlv(0x01,b'\x00')+eq_filter('uid','alice')+tlv(0x30,ab)
    sv=tlv(0x30,integer(3,0x0a)+(octet(cookie) if cookie else b''))
    return msg(mid,tlv(0x63,body),control(SYNC_REQUEST,sv,True))
def search(mid):
    ab=octet('uid')+octet('cn')
    body=octet('dc=example,dc=org')+integer(2,0x0a)+integer(0,0x0a)+integer(0)+integer(0)+tlv(0x01,b'\x00')+eq_filter('uid','alice')+tlv(0x30,ab)
    return msg(mid,tlv(0x63,body))
def modify(mid,cn):
    partial=tlv(0x30,octet('cn')+tlv(0x31,octet(cn))); change=tlv(0x30,integer(2,0x0a)+partial)
    return msg(mid,tlv(0x66,octet('uid=alice,ou=people,dc=example,dc=org')+tlv(0x30,change)))
def cancel(mid,target):
    request_value=tlv(0x30,integer(target))
    ext=tlv(0x77,tlv(0x80,CANCEL.encode())+tlv(0x81,request_value))
    return msg(mid,ext)
def find(ctrls,oid):
    for c in ctrls:
        if c[0]==oid:return c
    return None
def state(v):
    t,x,_=read_tlv(v); assert t==0x30
    t,s,p=read_tlv(x); t,u,p=read_tlv(x,p); cookie=None
    if p<len(x): t,cookie,p=read_tlv(x,p)
    return int.from_bytes(s,'big'),u,cookie
def info(v):
    t,x,_=read_tlv(v)
    if t==0x80:return 'NEW_COOKIE',x,True
    assert t in (0xa1,0xa2)
    p=0; cookie=None; done=True
    if p<len(x):
        tt,y,p2=read_tlv(x,p)
        if tt==0x04: cookie=y; p=p2
    if p<len(x):
        tt,y,p=read_tlv(x,p); assert tt==0x01; done=y!=b'\x00'
    return ('REFRESH_DELETE' if t==0xa1 else 'REFRESH_PRESENT'),cookie,done

def bind_ok(s,mid=1):
    s.sendall(bind(mid,'uid=alice,ou=people,dc=example,dc=org','wire-secret'))
    m,t,o,c=decode(recv_frame(s)); assert m==mid and t==0x61 and result_code(o)==0

def recv_for(s,target,pending):
    if target in pending and pending[target]: return pending[target].pop(0)
    while True:
        item=decode(recv_frame(s)); mid=item[0]
        if mid==target:return item
        pending.setdefault(mid,[]).append(item)

port=int(sys.argv[1])
s=socket.create_connection(('127.0.0.1',port),timeout=8); bind_ok(s)
pending={}
s.sendall(sync_persist(2)); refresh=0; cookie=None
while True:
    m,t,o,c=recv_for(s,2,pending)
    if t==0x64:
        sc=find(c,SYNC_STATE); assert sc
        st,u,ck=state(sc[2]); assert st==1; refresh+=1
    elif t==0x79:
        p=0; name=None; val=None
        while p<len(o):
            tt,x,p=read_tlv(o,p)
            if tt==0x80:name=x.decode()
            elif tt==0x81:val=x
        assert name==SYNC_INFO and val
        kind,cookie,done=info(val); assert done; break
    else: raise AssertionError(hex(t))
assert refresh==1 and cookie

# A normal operation is issued while message 2 remains outstanding.  Either
# response may arrive first; message-id demultiplexing preserves both.
s.sendall(modify(3,'Alice Python Persistent'))
m,t,o,c=recv_for(s,3,pending); assert t==0x67 and result_code(o)==0
m,t,o,c=recv_for(s,2,pending); assert t==0x64
sc=find(c,SYNC_STATE); st,u,newcookie=state(sc[2]); assert st==2 and newcookie and newcookie!=cookie

# RFC 3909 Cancel has its own response and requires the target operation to
# terminate with canceled(118).  These two responses may also be interleaved.
s.sendall(cancel(4,2))
m,t,o,c=recv_for(s,4,pending); assert t==0x78 and result_code(o)==0
while True:
    m,t,o,c=recv_for(s,2,pending)
    if t==0x65:
        assert result_code(o)==118
        break
    assert t in (0x64,0x79)

# The server retains enough association-local completion knowledge to report
# tooLate(120), rather than silently treating the completed target as unknown.
s.sendall(cancel(5,2))
m,t,o,c=recv_for(s,5,pending); assert t==0x78 and result_code(o)==120

# Cancel did not tear down the association.
s.sendall(search(6)); entries=0
while True:
    m,t,o,c=recv_for(s,6,pending)
    if t==0x64: entries+=1
    elif t==0x65:
        assert result_code(o)==0; break
    else: raise AssertionError(hex(t))
assert entries==1
s.sendall(unbind(7)); s.close()
print('LDAP SYNC PERSIST + CANCEL PYTHON CLIENT: OK')
