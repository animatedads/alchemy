#!/usr/bin/env python3
"""Independent classic-protocol prepared-statement smoke for msqlshim v0.13."""
import os,socket, struct, sys, time
HOST='127.0.0.1'; PORT=int(sys.argv[1]) if len(sys.argv)>1 else 3456
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

def lenenc(buf, off=0):
    b=buf[off]
    if b<0xfb: return b, off+1
    if b==0xfc: return int.from_bytes(buf[off+1:off+3],'little'),off+3
    if b==0xfd: return int.from_bytes(buf[off+1:off+4],'little'),off+4
    if b==0xfe: return int.from_bytes(buf[off+1:off+9],'little'),off+9
    raise ValueError('NULL/invalid lenenc')

def lstr(buf, off):
    n,off=lenenc(buf,off); return buf[off:off+n],off+n

def auth(s):
    readpkt(s)
    resp=struct.pack('<I',FLAGS)+struct.pack('<I',16*1024*1024)+bytes([45])+b'\0'*23+b'nosql\0'+b'\0'+b'mysql_native_password\0'
    sendpkt(s,1,resp); _,p=readpkt(s); assert p[0]==0, p

def prepare(s, sql):
    sendpkt(s,0,b'\x16'+sql.encode())
    _,p=readpkt(s)
    assert p[0]==0, p
    stmt=int.from_bytes(p[1:5],'little'); cols=int.from_bytes(p[5:7],'little'); params=int.from_bytes(p[7:9],'little')
    if params:
        for _ in range(params): readpkt(s)
        _,eof=readpkt(s); assert eof[0]==0xfe
    if cols:
        for _ in range(cols): readpkt(s)
        _,eof=readpkt(s); assert eof[0]==0xfe
    return stmt,cols,params

def execute(s, stmt, types, values, null_bitmap=b'\x00', cursor_flags=0):
    payload=b'\x17'+struct.pack('<I',stmt)+bytes([cursor_flags])+struct.pack('<I',1)
    if types:
        payload+=null_bitmap+b'\x01'+b''.join(bytes((t,0)) for t in types)+b''.join(values)
    sendpkt(s,0,payload)

def read_binary_result(s):
    _,p=readpkt(s)
    if p[0]==0xff: raise AssertionError(p)
    cols,_=lenenc(p)
    for _ in range(cols): readpkt(s)
    _,eof=readpkt(s); assert eof[0]==0xfe
    rows=[]
    while True:
        _,p=readpkt(s)
        if p[0]==0xfe and len(p)<9: break
        rows.append(p)
    return cols,rows

s=socket.create_connection((HOST,PORT),timeout=5)
fixture_base = 200000000 + ((os.getpid() * 1000 + int(time.time())) % 50000000); s.settimeout(10); auth(s)
stmt,cols,params=prepare(s,'SELECT * FROM customer WHERE customer_id = ?')
assert (cols,params)==(3,1),(cols,params)
print('PASS COM_STMT_PREPARE SELECT metadata columns=3 params=1')
execute(s,stmt,[3],[struct.pack('<I',901)])
cols,rows=read_binary_result(s); assert cols==3 and rows
row=rows[0]; assert row[0]==0
# one NULL-bitmap byte follows the binary-row header
cid=int.from_bytes(row[2:6],'little',signed=True); off=6
name,off=lstr(row,off); email,off=lstr(row,off)
assert cid==901 and name==b'Wire User' and email==b'wire@example.test',(cid,name,email)
print('PASS COM_STMT_EXECUTE binary SELECT row: 901 Wire User')


# Server-side read-only cursor: execute sends metadata only with CURSOR_EXISTS,
# then COM_STMT_FETCH returns binary rows in requested batches.
stmtc,colsc,paramsc=prepare(s,'SELECT * FROM customer ORDER BY customer_id LIMIT 5')
assert (colsc,paramsc)==(3,0),(colsc,paramsc)
execute(s,stmtc,[],[],cursor_flags=1)
_,p=readpkt(s); ccols,_=lenenc(p); assert ccols==3
for _ in range(ccols): readpkt(s)
_,eof=readpkt(s); assert eof[0]==0xfe
status=int.from_bytes(eof[3:5],'little'); assert status & 64,status
print('PASS COM_STMT_EXECUTE CURSOR_TYPE_READ_ONLY opened server cursor')

def fetch_cursor(s, stmt, n):
    sendpkt(s,0,b'\x1c'+struct.pack('<I',stmt)+struct.pack('<I',n))
    rows=[]
    while True:
        _,p=readpkt(s)
        if p[0]==0xfe and len(p)<9:
            return rows,int.from_bytes(p[3:5],'little')
        rows.append(p)

rows1,status1=fetch_cursor(s,stmtc,2)
assert len(rows1)==2 and status1 & 64 and not(status1 & 128),(len(rows1),status1)
rows2,status2=fetch_cursor(s,stmtc,8)
assert len(rows2)==3 and status2 & 128,(len(rows2),status2)
print('PASS COM_STMT_FETCH batches 2+3 rows and SERVER_STATUS_LAST_ROW_SENT')
# Fetch after exhaustion is correctly rejected because the cursor has closed.
sendpkt(s,0,b'\x1c'+struct.pack('<I',stmtc)+struct.pack('<I',1)); _,p=readpkt(s); assert p[0]==0xff,p
print('PASS exhausted prepared cursor closes')
sendpkt(s,0,b'\x19'+struct.pack('<I',stmtc))

# Reset retains the prepared statement but clears long-data state.
sendpkt(s,0,b'\x1a'+struct.pack('<I',stmt)); _,p=readpkt(s); assert p[0]==0
print('PASS COM_STMT_RESET')

stmt2,cols2,params2=prepare(s,'INSERT INTO customer (customer_id, name, email) VALUES (?, ?, ?)')
assert (cols2,params2)==(0,3),(cols2,params2)
print('PASS COM_STMT_PREPARE INSERT params=3')
newid=fixture_base + 1; name=b'Prepared User'; email=b'prepared@example.test'
execute(s,stmt2,[3,253,253],[struct.pack('<I',newid),bytes([len(name)])+name,bytes([len(email)])+email])
_,p=readpkt(s); assert p[0]==0,p
affected,_=lenenc(p,1); assert affected==1,affected
print('PASS COM_STMT_EXECUTE prepared INSERT affected_rows=1')

# v0.13: exercise the remaining common classic binary parameter families.
# FLOAT/DOUBLE are decoded from IEEE-754 little-endian wire values and enter
# NoSQLServer through DatabaseValue DECIMAL.  Temporal values use the MySQL
# length-prefixed binary DATE/DATETIME/TIME forms.
stmtf,colsf,paramsf=prepare(s,'INSERT INTO telemetry (sensor_id, reading) VALUES (?, ?)')
assert (colsf,paramsf)==(0,2),(colsf,paramsf)
execute(s,stmtf,[3,4],[struct.pack('<I',(fixture_base + 2)),struct.pack('<f',12.5)])
_,p=readpkt(s); assert p[0]==0,p
execute(s,stmtf,[3,5],[struct.pack('<I',(fixture_base + 3)),struct.pack('<d',-1234.125)])
_,p=readpkt(s); assert p[0]==0,p
print('PASS COM_STMT_EXECUTE FLOAT and DOUBLE parameters')

stmtfr,colsfr,paramsfr=prepare(s,'SELECT * FROM telemetry WHERE sensor_id = ?')
assert (colsfr,paramsfr)==(2,1),(colsfr,paramsfr)
execute(s,stmtfr,[3],[struct.pack('<I',(fixture_base + 2))])
cols,rows=read_binary_result(s); assert cols==2 and len(rows)==1,(cols,len(rows))
row=rows[0]; reading,_=lstr(row,6); assert reading.startswith(b'12.5'),reading
execute(s,stmtfr,[3],[struct.pack('<I',(fixture_base + 3))])
cols,rows=read_binary_result(s); assert cols==2 and len(rows)==1,(cols,len(rows))
row=rows[0]; reading,_=lstr(row,6); assert reading.startswith(b'-1234.125'),reading
print('PASS FLOAT/DOUBLE round-trip through DECIMAL column')
execute(s,stmtf,[3,4],[struct.pack('<I',(fixture_base + 4)),struct.pack('<f',float('nan'))])
_,p=readpkt(s); assert p[0]==0xff,p
print('PASS NaN FLOAT parameter rejected explicitly')

def mysql_date(y,m,d):
    return b'\x04'+struct.pack('<HBB',y,m,d)
def mysql_datetime(y,m,d,hh,mm,ss,micros=0):
    if micros:
        return b'\x0b'+struct.pack('<HBBBBB',y,m,d,hh,mm,ss)+struct.pack('<I',micros)
    return b'\x07'+struct.pack('<HBBBBB',y,m,d,hh,mm,ss)
def mysql_time(negative,days,hh,mm,ss,micros=0):
    if micros:
        return b'\x0c'+bytes([1 if negative else 0])+struct.pack('<I',days)+bytes([hh,mm,ss])+struct.pack('<I',micros)
    return b'\x08'+bytes([1 if negative else 0])+struct.pack('<I',days)+bytes([hh,mm,ss])

stmtt,colst,paramst=prepare(s,'INSERT INTO customer (customer_id, name, email) VALUES (?, ?, ?)')
execute(s,stmtt,[3,10,12],[struct.pack('<I',(fixture_base + 5)),mysql_date(2026,8,22),mysql_datetime(2026,8,22,2,3,4,123456)])
_,p=readpkt(s); assert p[0]==0,p
execute(s,stmtt,[3,11,253],[struct.pack('<I',(fixture_base + 6)),mysql_time(False,1,3,4,5,6000),bytes([17])+b'time@example.test'])
_,p=readpkt(s); assert p[0]==0,p
print('PASS DATE, DATETIME and TIME parameters')

stmttread,colstread,paramstread=prepare(s,'SELECT * FROM customer WHERE customer_id = ?')
execute(s,stmttread,[3],[struct.pack('<I',(fixture_base + 5))])
cols,rows=read_binary_result(s); assert len(rows)==1
row=rows[0]; off=6; date_text,off=lstr(row,off); datetime_text,off=lstr(row,off)
assert date_text==b'2026-08-22',date_text
assert datetime_text==b'2026-08-22 02:03:04.123456',datetime_text
execute(s,stmttread,[3],[struct.pack('<I',(fixture_base + 6))])
cols,rows=read_binary_result(s); assert len(rows)==1
row=rows[0]; off=6; time_text,off=lstr(row,off)
assert time_text==b'27:04:05.006000',time_text
print('PASS temporal parameter canonical text round-trip')

# COM_STMT_CLOSE has no response. Close statements and prove connection remains usable.
for close_stmt in (stmt,stmt2,stmtf,stmtfr,stmtt,stmttread):
    sendpkt(s,0,b'\x19'+struct.pack('<I',close_stmt))
sendpkt(s,0,b'\x0e'); _,p=readpkt(s); assert p[0]==0
print('PASS COM_STMT_CLOSE no-response semantics and subsequent COM_PING')
s.close()
print('MYSQL WIRE PREPARED STATEMENT SMOKE PASS')
