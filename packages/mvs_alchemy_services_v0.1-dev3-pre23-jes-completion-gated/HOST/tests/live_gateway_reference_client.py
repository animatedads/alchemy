#!/usr/bin/env python3
import socket,struct,sys
HOST=sys.argv[1] if len(sys.argv)>1 else '127.0.0.1'
PORT=int(sys.argv[2]) if len(sys.argv)>2 else 37075

def tv(t,tag,b):
    tag=tag.encode('ascii'); return bytes([t,0,len(tag),0])+struct.pack('>I',len(b))+tag+b
def ch(tag,s): return tv(2,tag,struct.pack('>H',819)+s.encode('ascii'))
def by(tag,b): return tv(1,tag,b)
def u32(tag,n): return tv(3,tag,struct.pack('>I',n))
def hnd(tag,n): return tv(6,tag,struct.pack('>I',n))
def frame(sess,req,op,p=b''):
    return b'ALCH'+bytes([1,0])+struct.pack('>H',48)+struct.pack('>I',48+len(p))+struct.pack('>Q',sess)+struct.pack('>Q',req)+struct.pack('>I',0)+struct.pack('>H',op)+struct.pack('>H',0)+struct.pack('>I',0)+struct.pack('>I',0)+struct.pack('>I',len(p))+p
def rx(s,n):
    out=b''
    while len(out)<n:
        b=s.recv(n-len(out))
        if not b: raise EOFError('socket closed')
        out+=b
    return out
def values(p):
    out={}; i=0
    while i<len(p):
        t,flags,tl,res=p[i:i+4]; n=struct.unpack('>I',p[i+4:i+8])[0];i+=8
        tag=p[i:i+tl].decode('ascii');i+=tl;v=p[i:i+n];i+=n;out[tag]=(t,v)
    return out
def req(s,reqid,op,p=b''):
    s.sendall(frame(1,reqid,op,p)); h=rx(s,48); status=struct.unpack('>I',h[36:40])[0]; reason=struct.unpack('>I',h[40:44])[0]; n=struct.unpack('>I',h[44:48])[0]; body=rx(s,n) if n else b''
    if status: raise AssertionError(f'op {op} status={status} reason={reason} body={body!r}')
    return values(body)
def as_u32(v): return struct.unpack('>I',v)[0]
def as_char(v): return v[2:].decode('ascii')

s=socket.create_connection((HOST,PORT),timeout=10); rid=1
v=req(s,rid,1,u32('CCSID',37));rid+=1; assert as_u32(v['MAX_FRAME'][1])==32768
v=req(s,rid,3,by('ECHO',b'\x00\xffMAS'));rid+=1; assert v['ECHO'][1]==b'\x00\xffMAS'; print('PASS PING_BINARY')

v=req(s,rid,4096,ch('NAME','LIVE.Q'));rid+=1; q=as_u32(v['HANDLE'][1])
req(s,rid,4097,hnd('HANDLE',q)+by('DATA',b'queue-A'));rid+=1
req(s,rid,4097,hnd('HANDLE',q)+by('DATA',b'queue-B'));rid+=1
v=req(s,rid,4099,hnd('HANDLE',q));rid+=1; assert as_u32(v['DEPTH'][1])==2
v=req(s,rid,4098,hnd('HANDLE',q));rid+=1; assert v['DATA'][1]==b'queue-A'
v=req(s,rid,4098,hnd('HANDLE',q));rid+=1; assert v['DATA'][1]==b'queue-B'; print('PASS QUEUE')

v=req(s,rid,4352,ch('NAME','LIVE.DB'));rid+=1; db=as_u32(v['HANDLE'][1])
req(s,rid,4354,hnd('HANDLE',db)+by('KEY',b'k1')+by('VALUE',b'v\x00\xff'));rid+=1
v=req(s,rid,4353,hnd('HANDLE',db)+by('KEY',b'k1'));rid+=1; assert v['VALUE'][1]==b'v\x00\xff'; print('PASS DATABASE')

v=req(s,rid,5120,b'');rid+=1; im=as_u32(v['HANDLE'][1])
v=req(s,rid,5122,hnd('HANDLE',im));rid+=1; assert b'INBOX' in v['MAILBOXES'][1]
v=req(s,rid,5123,hnd('HANDLE',im)+ch('MAILBOX','INBOX')+u32('UIDVALIDITY',71)+u32('UID',1001));rid+=1; msg=as_u32(v['MESSAGE'][1])
v=req(s,rid,5125,hnd('MESSAGE',msg));rid+=1; assert b'alice@example.test' in v['HEADERS'][1]
v=req(s,rid,5126,hnd('MESSAGE',msg));rid+=1; assert v['BODY'][1]==b'hello\r\n'; print('PASS IMAP')

v=req(s,rid,5152,b'');rid+=1; sm=as_u32(v['HANDLE'][1])
req(s,rid,5153,hnd('HANDLE',sm)+ch('ADDRESS','sender@example.test'));rid+=1
req(s,rid,5154,hnd('HANDLE',sm)+ch('ADDRESS','rcpt@example.test'));rid+=1
req(s,rid,5155,hnd('HANDLE',sm)+by('DATA',b'live smtp body'));rid+=1
req(s,rid,5156,hnd('HANDLE',sm)+u32('VERIFIED',1));rid+=1
v=req(s,rid,5157,hnd('HANDLE',sm)+u32('AUTHORIZED',1)+u32('EGRESS',1));rid+=1
assert as_char(v['STATUS'][1])=='RELAY_ELIGIBLE'; print('PASS SMTP_POLICY')

v=req(s,rid,5376,ch('PATH','/u/USER/live.txt')+ch('OPTS','OWRONLY OCREAT OTRUNC')+ch('FILEDATA','BINARY'));rid+=1; ph=as_u32(v['HANDLE'][1])
v=req(s,rid,5378,hnd('HANDLE',ph)+by('DATA',b'guest-path-\x00\xff'));rid+=1; assert as_u32(v['COUNT'][1])==13
v=req(s,rid,5380,hnd('HANDLE',ph));rid+=1; assert as_char(v['REF'][1]).startswith('live-')
v=req(s,rid,5376,ch('PATH','/u/USER/live.txt')+ch('OPTS','ORDONLY')+ch('FILEDATA','BINARY'));rid+=1; ph=as_u32(v['HANDLE'][1])
v=req(s,rid,5377,hnd('HANDLE',ph));rid+=1; assert v['DATA'][1]==b'guest-path-\x00\xff'; print('PASS PATH')

req(s,rid,19,b''); s.close(); print('PASS LIVE_GATEWAY_REFERENCE_ALL')
