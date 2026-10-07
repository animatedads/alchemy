#!/usr/bin/env python3
import socket,ssl,sys

def length(n):
    if n<128:return bytes([n])
    b=n.to_bytes((n.bit_length()+7)//8,'big');return bytes([0x80|len(b)])+b
def tlv(t,v=b''):return bytes([t])+length(len(v))+v
def integer(n,t=2):
    b=b'\x00' if n==0 else n.to_bytes((n.bit_length()+7)//8,'big')
    if b[0]&0x80:b=b'\x00'+b
    return tlv(t,b)
def octet(x):return tlv(4,x.encode() if isinstance(x,str) else x)
def msg(mid,op):return tlv(0x30,integer(mid)+op)
def recv_exact(s,n):
    o=b''
    while len(o)<n:
        p=s.recv(n-len(o))
        if not p:raise EOFError
        o+=p
    return o
def recv_frame(s):
    h=recv_exact(s,2);b=h[1]
    if b<128:n=b;ex=b''
    else:c=b&0x7f;ex=recv_exact(s,c);n=int.from_bytes(ex,'big')
    return h+ex+recv_exact(s,n)
def read_tlv(d,o=0):
    t=d[o];o+=1;b=d[o];o+=1
    if b<128:n=b
    else:c=b&0x7f;n=int.from_bytes(d[o:o+c],'big');o+=c
    return t,d[o:o+n],o+n
def decode(f):
    t,v,_=read_tlv(f);t,i,p=read_tlv(v);mid=int.from_bytes(i,'big');t,op,p=read_tlv(v,p);return mid,t,op
def rc(op):t,v,_=read_tlv(op);return int.from_bytes(v,'big')
def bind(mid):
    c=b'\x00'+b'uid=alice,ou=people,dc=example,dc=org'+b'\x00'+b'wire-secret'
    return msg(mid,tlv(0x60,integer(3)+octet('')+tlv(0xa3,octet('PLAIN')+octet(c))))
def search(mid):
    attrs=b''.join(octet(a) for a in ['uid','cn','entryUUID','oorexxEntityId'])
    filt=tlv(0xa3,octet('uid')+octet('alice'))
    body=octet('dc=example,dc=org')+integer(2,0x0a)+integer(0,0x0a)+integer(0)+integer(0)+tlv(1,b'\x00')+filt+tlv(0x30,attrs)
    return msg(mid,tlv(0x63,body))
def unbind(mid):return msg(mid,tlv(0x42,b''))
port=int(sys.argv[1]);cafile=sys.argv[2]
ctx=ssl.create_default_context(cafile=cafile)
raw=socket.create_connection(('127.0.0.1',port),timeout=8)
s=ctx.wrap_socket(raw,server_hostname='localhost')
assert s.version() in ('TLSv1.2','TLSv1.3')
s.sendall(bind(1));m,t,o=decode(recv_frame(s));assert (m,t,rc(o))==(1,0x61,0)
s.sendall(search(2));n=0
while True:
    m,t,o=decode(recv_frame(s));assert m==2
    if t==0x64:n+=1
    elif t==0x65:assert rc(o)==0;break
    else:raise AssertionError(hex(t))
assert n==1
s.sendall(unbind(3));s.close()
print('LDAP LDAPS PYTHON CLIENT: OK')
