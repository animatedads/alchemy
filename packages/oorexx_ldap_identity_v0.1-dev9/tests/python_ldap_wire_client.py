#!/usr/bin/env python3
import socket, sys

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
def msg(mid, op, controls=b''):
    return tlv(0x30, integer(mid)+op+(tlv(0xa0,controls) if controls else b''))

def control(oid, value=None, critical=False):
    body=octet(oid)
    if critical: body+=tlv(0x01,b'\xff')
    if value is not None: body+=octet(value)
    return tlv(0x30,body)

def recv_exact(s,n):
    out=b''
    while len(out)<n:
        p=s.recv(n-len(out))
        if not p: raise EOFError
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

def decode_message_full(frame):
    t,v,_=read_tlv(frame); assert t==0x30
    t,i,p=read_tlv(v); assert t==0x02
    mid=int.from_bytes(i,'big')
    t,op,p=read_tlv(v,p)
    controls=[]
    if p < len(v):
        ct,cv,p2=read_tlv(v,p); assert ct==0xa0 and p2==len(v)
        q=0
        while q < len(cv):
            st,sv,q=read_tlv(cv,q); assert st==0x30
            ot,ov,r=read_tlv(sv); assert ot==0x04
            critical=False; value=None
            if r < len(sv):
                et,ev,r2=read_tlv(sv,r)
                if et==0x01:
                    critical=ev != b'\x00'; r=r2
                    if r < len(sv): et,ev,r=read_tlv(sv,r)
                    else: et=None
                if et is not None:
                    assert et==0x04; value=ev
            controls.append((ov.decode(),critical,value))
    return mid,t,op,controls

def decode_message(frame):
    mid,t,op,_=decode_message_full(frame)
    return mid,t,op

def result_code(op):
    t,v,_=read_tlv(op)
    assert t==0x0a
    return int.from_bytes(v,'big')

def sasl_plain_bind(mid, authcid, pw, authzid=''):
    creds=authzid.encode()+b'\x00'+authcid.encode()+b'\x00'+pw.encode()
    sasl=octet('PLAIN')+octet(creds)
    return msg(mid, tlv(0x60, integer(3)+octet('')+tlv(0xa3,sasl)))

def bind(mid,dn,pw):
    return msg(mid, tlv(0x60, integer(3)+octet(dn)+tlv(0x80,pw.encode())))

def eq_filter(attr,val): return tlv(0xa3,octet(attr)+octet(val))
def presence_filter(attr): return tlv(0x87,attr.encode())
def search_raw(mid,base,scope,flt,attrs):
    ab=b''.join(octet(a) for a in attrs)
    body=octet(base)+integer(scope,0x0a)+integer(0,0x0a)+integer(0)+integer(0)+tlv(0x01,b'\x00')+flt+tlv(0x30,ab)
    return msg(mid,tlv(0x63,body))

def search(mid,base,attr,val,attrs):
    return search_raw(mid,base,2,eq_filter(attr,val),attrs)

def substring_filter(attr, initial=None, any_parts=(), final=None):
    parts=b''
    if initial is not None: parts += tlv(0x80, initial.encode())
    for value in any_parts: parts += tlv(0x81, value.encode())
    if final is not None: parts += tlv(0x82, final.encode())
    return tlv(0xa4, octet(attr)+tlv(0x30,parts))

SYNC_REQUEST_OID='1.3.6.1.4.1.4203.1.9.1.1'
SYNC_STATE_OID='1.3.6.1.4.1.4203.1.9.1.2'
SYNC_DONE_OID='1.3.6.1.4.1.4203.1.9.1.3'
PAGED_RESULTS_OID='1.2.840.113556.1.4.319'

def paged_search(mid,base,attr,val,attrs,page_size,cookie=b''):
    ab=b''.join(octet(a) for a in attrs)
    flt=presence_filter(attr) if val=='*' else eq_filter(attr,val)
    body=octet(base)+integer(2,0x0a)+integer(0,0x0a)+integer(0)+integer(0)+tlv(0x01,b'\x00')+flt+tlv(0x30,ab)
    page_value=tlv(0x30, integer(page_size)+octet(cookie))
    return msg(mid,tlv(0x63,body),control(PAGED_RESULTS_OID,page_value,False))

def decode_paged_results(value):
    t,v,_=read_tlv(value); assert t==0x30
    t,size,p=read_tlv(v); assert t==0x02
    t,cookie,p=read_tlv(v,p); assert t==0x04 and p==len(v)
    return int.from_bytes(size,'big'),cookie

def sync_search(mid,base,attr,val,attrs,cookie=None):
    ab=b''.join(octet(a) for a in attrs)
    body=octet(base)+integer(2,0x0a)+integer(0,0x0a)+integer(0)+integer(0)+tlv(0x01,b'\x00')+eq_filter(attr,val)+tlv(0x30,ab)
    sync_value=tlv(0x30,integer(1,0x0a)+(octet(cookie) if cookie else b''))
    return msg(mid,tlv(0x63,body),control(SYNC_REQUEST_OID,sync_value,True))

def decode_sync_state(value):
    t,v,_=read_tlv(value); assert t==0x30
    t,state,p=read_tlv(v); assert t==0x0a
    t,uuid,p=read_tlv(v,p); assert t==0x04 and len(uuid)==16
    cookie=None
    if p < len(v):
        t,cookie,p=read_tlv(v,p); assert t==0x04
    return int.from_bytes(state,'big'),uuid,cookie

def decode_sync_done(value):
    t,v,_=read_tlv(value); assert t==0x30
    p=0; cookie=None; refresh_deletes=False
    if p < len(v):
        t,x,p2=read_tlv(v,p)
        if t==0x04: cookie=x; p=p2
    if p < len(v):
        t,x,p=read_tlv(v,p); assert t==0x01; refresh_deletes=x!=b'\x00'
    return cookie,refresh_deletes

def find_control(controls,oid):
    for c in controls:
        if c[0]==oid: return c
    return None

def unbind(mid): return msg(mid,tlv(0x42,b''))

def modify_replace(mid,dn,attr,value):
    partial=tlv(0x30, octet(attr)+tlv(0x31, octet(value)))
    change=tlv(0x30, integer(2,0x0a)+partial)
    return msg(mid, tlv(0x66, octet(dn)+tlv(0x30, change)))

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

port=int(sys.argv[1])
s=socket.create_connection(('127.0.0.1',port),timeout=5)
s.sendall(sasl_plain_bind(1,'uid=alice,ou=people,dc=example,dc=org','wire-secret'))
mid,tag,op=decode_message(recv_frame(s))
assert (mid,tag,result_code(op))==(1,0x61,13), (mid,tag,result_code(op))
s.sendall(bind(2,'uid=alice,ou=people,dc=example,dc=org','wire-secret'))
mid,tag,op=decode_message(recv_frame(s))
assert (mid,tag,result_code(op))==(2,0x61,0)
# Read-only subschema discovery is a real LDAP BASE search, not local metadata.
s.sendall(search_raw(20,'cn=subschema',0,eq_filter('objectClass','subschema'),['cn','objectClasses','attributeTypes']))
schema_entries=[]
while True:
    mid,tag,op=decode_message(recv_frame(s)); assert mid==20
    if tag==0x64: schema_entries.append(decode_entry(op))
    elif tag==0x65:
        assert result_code(op)==0; break
    else: raise AssertionError(hex(tag))
assert len(schema_entries)==1
assert len(schema_entries[0][1].get('objectclasses',[])) >= 8
s.sendall(sync_search(3,'dc=example,dc=org','uid','alice',['uid','cn','entryUUID','oorexxEntityId']))
sync_entries=[]; sync_cookie=None; sync_uuid=None
while True:
    mid,tag,op,controls=decode_message_full(recv_frame(s)); assert mid==3
    if tag==0x64:
        sc=find_control(controls,SYNC_STATE_OID); assert sc and sc[2] is not None
        state,uuid,cookie=decode_sync_state(sc[2]); assert state==1
        sync_uuid=uuid; sync_entries.append(decode_entry(op))
    elif tag==0x65:
        assert result_code(op)==0
        dc=find_control(controls,SYNC_DONE_OID); assert dc and dc[2] is not None
        sync_cookie,_=decode_sync_done(dc[2]); break
    else: raise AssertionError(hex(tag))
assert len(sync_entries)==1 and sync_cookie and sync_uuid
s.sendall(modify_replace(4,'uid=alice,ou=people,dc=example,dc=org','cn','Alice Via Python'))
mid,tag,op=decode_message(recv_frame(s))
assert (mid,tag,result_code(op))==(4,0x67,0)
s.sendall(sync_search(5,'dc=example,dc=org','uid','alice',['uid','cn','entryUUID','oorexxEntityId'],sync_cookie))
inc=[]; next_cookie=None
while True:
    mid,tag,op,controls=decode_message_full(recv_frame(s)); assert mid==5
    if tag==0x64:
        sc=find_control(controls,SYNC_STATE_OID); assert sc and sc[2] is not None
        state,uuid,cookie=decode_sync_state(sc[2]); assert state==2 and uuid==sync_uuid
        inc.append(decode_entry(op))
    elif tag==0x65:
        assert result_code(op)==0
        dc=find_control(controls,SYNC_DONE_OID); assert dc and dc[2] is not None
        next_cookie,_=decode_sync_done(dc[2]); break
    else: raise AssertionError(hex(tag))
assert len(inc)==1 and next_cookie and next_cookie!=sync_cookie
s.sendall(search(6,'dc=example,dc=org','uid','alice',['uid','cn','entryUUID','oorexxEntityId']))
entries=[]
while True:
    mid,tag,op=decode_message(recv_frame(s)); assert mid==6
    if tag==0x64: entries.append(decode_entry(op))
    elif tag==0x65:
        assert result_code(op)==0; break
    else: raise AssertionError(hex(tag))
assert len(entries)==1, entries
assert entries[0][1]['uid']==['alice']
assert entries[0][1]['cn']==['Alice Via Python']
assert len(entries[0][1]['entryuuid'][0])==36
assert entries[0][1]['oorexxentityid']==['principal:alice']
# Exercise BER AND/OR/NOT + substring choices independently of the ooRexx DUA.
complex_filter=tlv(0xa0,
    eq_filter('objectClass','oorexxPrincipal') +
    tlv(0xa1,eq_filter('uid','alice')+eq_filter('uid','nobody')) +
    tlv(0xa2,eq_filter('cn','Nobody')) +
    substring_filter('cn',initial='Alice'))
s.sendall(search_raw(21,'dc=example,dc=org',2,complex_filter,['uid','cn']))
complex_entries=[]
while True:
    mid,tag,op=decode_message(recv_frame(s)); assert mid==21
    if tag==0x64: complex_entries.append(decode_entry(op))
    elif tag==0x65:
        assert result_code(op)==0; break
    else: raise AssertionError(hex(tag))
assert len(complex_entries)==1 and complex_entries[0][1]['uid']==['alice']
# RFC 2696 paging is a separate standard LDAP conversation control.  Enumerate
# the same authoritative directory through opaque continuation cookies.
page_cookie=b''; paged_ids=[]; mid_counter=7; pages=0
while True:
    requested_size=3 if pages==0 else 2
    s.sendall(paged_search(mid_counter,'dc=example,dc=org','objectClass','*',['oorexxEntityId'],requested_size,page_cookie))
    current=[]; response_cookie=None; estimate=None
    while True:
        mid,tag,op,controls=decode_message_full(recv_frame(s)); assert mid==mid_counter
        if tag==0x64:
            _,attrs=decode_entry(op)
            current.extend(attrs.get('oorexxentityid',[]))
        elif tag==0x65:
            assert result_code(op)==0
            pc=find_control(controls,PAGED_RESULTS_OID); assert pc and pc[2] is not None
            estimate,response_cookie=decode_paged_results(pc[2]); break
        else: raise AssertionError(hex(tag))
    assert len(current)<=requested_size
    paged_ids.extend(current); pages+=1; mid_counter+=1
    page_cookie=response_cookie
    if not page_cookie: break
assert estimate==11, estimate
assert len(paged_ids)==11 and len(set(paged_ids))==11, paged_ids
s.sendall(unbind(mid_counter)); s.close()
print('LDAP WIRE PYTHON CLIENT: OK')
