#!/usr/bin/env python3
"""MAS BASE-0.5 executable reference checks. Python is qualification tooling only."""
from dataclasses import dataclass
import struct, hashlib
EYE=b'ALCH'; MAJOR=1; MINOR=0; HLEN=48; MAX_FRAME=32768
FMT='>4sBBHIQQIHHIII'; assert struct.calcsize(FMT)==HLEN
T_NULL=0; T_BYTES=1; T_CHAR=2; T_UINT32=3; T_SINT32=4; T_UINT64=5; T_HANDLE=6
@dataclass(frozen=True)
class Frame:
    session:int=0; request:int=0; obj:int=0; op:int=0; flags:int=0
    status:int=0; reason:int=0; payload:bytes=b''
def encode(f):
    total=HLEN+len(f.payload)
    if total>MAX_FRAME: raise ValueError('frame too large')
    return struct.pack(FMT,EYE,MAJOR,MINOR,HLEN,total,f.session,f.request,f.obj,f.op,f.flags,f.status,f.reason,len(f.payload))+f.payload
def decode(b):
    if len(b)<HLEN: raise ValueError('truncated header')
    eye,maj,minr,hlen,total,ses,req,obj,op,flags,status,reason,plen=struct.unpack(FMT,b[:HLEN])
    if eye!=EYE: raise ValueError('bad eye')
    if maj!=MAJOR: raise ValueError('unsupported major')
    if hlen<HLEN: raise ValueError('short header length')
    if total<hlen or total>MAX_FRAME: raise ValueError('bad total')
    if plen!=total-hlen: raise ValueError('bad payload length')
    if len(b)!=total: raise ValueError('incomplete/excess frame')
    return Frame(ses,req,obj,op,flags,status,reason,b[hlen:])
def tv(t, tag, value=b'', flags=0):
    tag=tag.encode('ascii') if isinstance(tag,str) else tag
    if len(tag)>255: raise ValueError('tag too long')
    return struct.pack('>BBBBI',t,flags,len(tag),0,len(value))+tag+value
def tv_decode(b):
    if len(b)<8: raise ValueError('short typed value')
    t,flags,nlen,res,vlen=struct.unpack('>BBBBI',b[:8])
    if res: raise ValueError('typed reserved nonzero')
    end=8+nlen+vlen
    if end!=len(b): raise ValueError('typed length mismatch')
    return t,flags,b[8:8+nlen],b[8+nlen:end]
def fingerprint(f):
    h=hashlib.sha256(); h.update(struct.pack('>HI',f.op,f.obj)); h.update(f.payload); return h.digest()
def must_fail(fn,*a):
    try: fn(*a)
    except ValueError: return
    raise AssertionError('malformed value accepted')
def main():
    for payload in (b'',b'hello',bytes([0,255,0xC1,0])):
        f=Frame(0x0102030405060708,0x1112131415161718,7,17,payload=payload); assert decode(encode(f))==f
    assert len(encode(Frame(op=17,payload=b'x'*(MAX_FRAME-HLEN))))==MAX_FRAME
    must_fail(decode,b'ALCH')
    good=bytearray(encode(Frame(op=3))); good[44:48]=(1).to_bytes(4,'big'); must_fail(decode,bytes(good))
    good=bytearray(encode(Frame(op=3))); good[4]=2; must_fail(decode,bytes(good))
    # EBCDIC 037 HELLO is C8 C5 D3 D3 D6; CHAR metadata is explicit in value bytes.
    c=tv(T_CHAR,'TEXT',struct.pack('>H',37)+bytes.fromhex('C8C5D3D3D6')); assert tv_decode(c)[3][2:]==bytes.fromhex('C8C5D3D3D6')
    raw=tv(T_BYTES,'DATA',bytes([0,255,0xC1,0])); assert tv_decode(raw)[3]==bytes([0,255,0xC1,0])
    for n in (0,1,0xffffffff): assert int.from_bytes(tv_decode(tv(T_UINT32,'N',n.to_bytes(4,'big')))[3],'big')==n
    for n in (-2147483648,-1,0,2147483647): assert int.from_bytes(tv_decode(tv(T_SINT32,'N',n.to_bytes(4,'big',signed=True)))[3],'big',signed=True)==n
    a=Frame(request=9,obj=7,op=17,payload=b'A'); b=Frame(request=9,obj=7,op=17,payload=b'A'); c2=Frame(request=9,obj=7,op=17,payload=b'B')
    assert fingerprint(a)==fingerprint(b) and fingerprint(a)!=fingerprint(c2)
    print('MAS BASE-0.5 wire/typed/replay reference: PASS')
if __name__=='__main__': main()
