#!/usr/bin/env python3
import socket, ssl, sys

STARTTLS_OID='1.3.6.1.4.1.1466.20037'

def length(n):
    if n < 128: return bytes([n])
    b=n.to_bytes((n.bit_length()+7)//8,'big')
    return bytes([0x80|len(b)])+b

def tlv(tag, value=b''):
    return bytes([tag])+length(len(value))+value

def integer(n, tag=0x02):
    if n == 0: b=b'\x00'
    else:
        b=n.to_bytes((n.bit_length()+7)//8,'big')
        if b[0]&0x80: b=b'\x00'+b
    return tlv(tag,b)

def octet(s): return tlv(0x04, s.encode() if isinstance(s,str) else s)
def msg(mid, op): return tlv(0x30, integer(mid)+op)

def recv_exact(s,n):
    out=b''
    while len(out)<n:
        p=s.recv(n-len(out))
        if not p: raise EOFError('connection closed')
        out+=p
    return out

def recv_frame(s):
    h=recv_exact(s,2); b=h[1]
    if b<128: n=b; extra=b''
    else:
        c=b&0x7f; extra=recv_exact(s,c); n=int.from_bytes(extra,'big')
    return h+extra+recv_exact(s,n)

def read_tlv(data, off=0):
    tag=data[off]; off+=1; b=data[off]; off+=1
    if b<128: n=b
    else:
        c=b&0x7f; n=int.from_bytes(data[off:off+c],'big'); off+=c
    v=data[off:off+n]
    return tag,v,off+n

def decode_message(frame):
    t,v,_=read_tlv(frame); assert t==0x30
    t,i,p=read_tlv(v); assert t==0x02
    mid=int.from_bytes(i,'big')
    t,op,_=read_tlv(v,p)
    return mid,t,op

def result_code(op):
    t,v,_=read_tlv(op); assert t==0x0a
    return int.from_bytes(v,'big')

def starttls(mid):
    return msg(mid,tlv(0x77,tlv(0x80,STARTTLS_OID.encode())))

def sasl_plain_bind(mid, authcid, pw, authzid=''):
    creds=authzid.encode()+b'\x00'+authcid.encode()+b'\x00'+pw.encode()
    sasl=octet('PLAIN')+octet(creds)
    return msg(mid,tlv(0x60,integer(3)+octet('')+tlv(0xa3,sasl)))

def eq_filter(attr,val): return tlv(0xa3,octet(attr)+octet(val))
def search(mid,base,attr,val,attrs):
    ab=b''.join(octet(a) for a in attrs)
    body=octet(base)+integer(2,0x0a)+integer(0,0x0a)+integer(0)+integer(0)+tlv(0x01,b'\x00')+eq_filter(attr,val)+tlv(0x30,ab)
    return msg(mid,tlv(0x63,body))
def unbind(mid): return msg(mid,tlv(0x42,b''))

def decode_entry(op):
    t,dn,p=read_tlv(op); assert t==0x04
    t,attrs,_=read_tlv(op,p); assert t==0x30
    pos=0; out={}
    while pos<len(attrs):
        t,pa,pos=read_tlv(attrs,pos); assert t==0x30
        t,n,q=read_tlv(pa); assert t==0x04
        t,vals,_=read_tlv(pa,q); assert t==0x31
        vp=0; arr=[]
        while vp<len(vals):
            t,x,vp=read_tlv(vals,vp); assert t==0x04; arr.append(x.decode())
        out[n.decode().lower()]=arr
    return dn.decode(),out

port=int(sys.argv[1]); cafile=sys.argv[2]
raw=socket.create_connection(('127.0.0.1',port),timeout=8)
raw.sendall(starttls(1))
mid,tag,op=decode_message(recv_frame(raw))
assert (mid,tag,result_code(op))==(1,0x78,0), (mid,hex(tag),result_code(op))
ctx=ssl.create_default_context(cafile=cafile)
s=ctx.wrap_socket(raw,server_hostname='localhost')
assert s.version() in ('TLSv1.2','TLSv1.3'), s.version()
s.sendall(sasl_plain_bind(2,'uid=alice,ou=people,dc=example,dc=org','wire-secret'))
mid,tag,op=decode_message(recv_frame(s))
assert (mid,tag,result_code(op))==(2,0x61,0), (mid,hex(tag),result_code(op))
s.sendall(search(3,'dc=example,dc=org','uid','alice',['uid','cn','entryUUID','oorexxEntityId']))
entries=[]
while True:
    mid,tag,op=decode_message(recv_frame(s)); assert mid==3
    if tag==0x64: entries.append(decode_entry(op))
    elif tag==0x65:
        assert result_code(op)==0; break
    else: raise AssertionError(hex(tag))
assert len(entries)==1
assert entries[0][1]['uid']==['alice']
assert entries[0][1]['cn']==['Alice TLS']
assert entries[0][1]['oorexxentityid']==['principal:alice']
assert len(entries[0][1]['entryuuid'][0])==36
s.sendall(unbind(4)); s.close()
print('LDAP STARTTLS + SASL PLAIN PYTHON CLIENT: OK')
