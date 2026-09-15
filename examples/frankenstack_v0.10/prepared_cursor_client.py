#!/usr/bin/env python3
import socket,struct,sys
host='127.0.0.1'; port=int(sys.argv[1]) if len(sys.argv)>1 else 3499
FLAGS=1|4|512|8192|32768|131072|524288
def recvn(s,n):
 out=b''
 while len(out)<n:
  p=s.recv(n-len(out))
  if not p: raise EOFError
  out+=p
 return out
def readpkt(s):
 h=recvn(s,4); return h[3],recvn(s,int.from_bytes(h[:3],'little'))
def sendpkt(s,seq,p): s.sendall(len(p).to_bytes(3,'little')+bytes([seq])+p)
def lenc(p,o=0):
 b=p[o]
 if b<0xfb:return b,o+1
 if b==0xfc:return int.from_bytes(p[o+1:o+3],'little'),o+3
 if b==0xfd:return int.from_bytes(p[o+1:o+4],'little'),o+4
 if b==0xfe:return int.from_bytes(p[o+1:o+9],'little'),o+9
 if b==0xfb:return None,o+1
 raise ValueError(b)
def field(p,o):
 n,o=lenc(p,o)
 if n is None:return None,o
 return p[o:o+n].decode('utf-8','replace'),o+n
def query(s,sql):
 sendpkt(s,0,b'\x03'+sql.encode()); _,p=readpkt(s)
 if p[0]==0xff: raise RuntimeError(p)
 c,_=lenc(p); cols=[]
 for _ in range(c):
  _,q=readpkt(s); o=0; parts=[]
  for __ in range(6): v,o=field(q,o); parts.append(v)
  cols.append(parts[4])
 readpkt(s); rows=[]
 while True:
  _,q=readpkt(s)
  if q and q[0]==0xfe and len(q)<9: break
  o=0; row=[]
  for _ in range(c): v,o=field(q,o); row.append(v)
  rows.append(row)
 return cols,rows
def prepare(s,sql):
 sendpkt(s,0,b'\x16'+sql.encode()); _,p=readpkt(s); assert p[0]==0,p
 stmt=int.from_bytes(p[1:5],'little'); cols=int.from_bytes(p[5:7],'little'); params=int.from_bytes(p[7:9],'little')
 for _ in range(params): readpkt(s)
 if params: readpkt(s)
 for _ in range(cols): readpkt(s)
 if cols: readpkt(s)
 return stmt,cols
def execute_cursor(s,stmt):
 sendpkt(s,0,b'\x17'+struct.pack('<I',stmt)+b'\x01'+struct.pack('<I',1)); _,p=readpkt(s)
 if p[0]==0xff: raise RuntimeError(p)
 cols,_=lenc(p)
 for _ in range(cols): readpkt(s)
 readpkt(s); return cols
def fetch(s,stmt,n):
 sendpkt(s,0,b'\x1c'+struct.pack('<I',stmt)+struct.pack('<I',n)); rows=[]
 while True:
  _,p=readpkt(s)
  if p[0]==0xfe and len(p)<9:return rows
  rows.append(p)
def decode_two(row):
 o=2; a,o=field(row,o); b,o=field(row,o); return [a,b]
s=socket.create_connection((host,port),timeout=5); s.settimeout(10); readpkt(s)
resp=struct.pack('<I',FLAGS)+struct.pack('<I',16*1024*1024)+bytes([45])+b'\0'*23+b'tribunal\0'+b'\0'+b'mysql_native_password\0'; sendpkt(s,1,resp); _,p=readpkt(s); assert p[0]==0,p
_,before=query(s,"SELECT provider_id,invocations FROM algrel_provider_stats ORDER BY provider_id")
assert before==[['TRIBUNAL','1']],before
stmt,cols=prepare(s,"SELECT row_id,disposition FROM retained_authority_decisions ORDER BY row_id"); assert cols==2
_,after_prepare=query(s,"SELECT provider_id,invocations FROM algrel_provider_stats ORDER BY provider_id"); assert after_prepare==before
print('PASS COM_STMT_PREPARE remains observational:',after_prepare)
assert execute_cursor(s,stmt)==2
rows=[decode_two(x) for x in fetch(s,stmt,2)+fetch(s,stmt,99)]
expected=[['ACT_ON_RETAINED_OFFER','PROHIBITED'],['PRESERVE_SOURCE_PROVENANCE','REQUIRED'],['RE_EVALUATE_AT_CONSUMER','REQUIRED'],['SUPPRESS_RETAINED_OFFER','REQUIRED'],['TREAT_QUEUE_DELIVERY_AS_AUTHORITY','PROHIBITED'],['TRUST_PUBLISHER_TIME_APPROVAL','PROHIBITED']]
assert rows==expected,(rows,expected)
_,after=query(s,"SELECT provider_id,invocations FROM algrel_provider_stats ORDER BY provider_id"); assert after==before
print('PASS EXECUTE/FETCH reuse frozen Algorithm Relation:',after)
print('PASS prepared cursor rows:',rows)
s.close(); print('FRANKENSTACK V0.10 PREPARED CURSOR: OK')
