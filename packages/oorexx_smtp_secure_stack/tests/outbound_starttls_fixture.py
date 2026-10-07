import socket, ssl, sys

ready, cert, key, capture = sys.argv[1:5]

def recvline(conn):
    b=b''
    while not b.endswith(b'\n'):
        c=conn.recv(1)
        if not c: return None
        b+=c
    return b.rstrip(b'\r\n')

def send(conn, line):
    conn.sendall(line.encode()+b'\r\n')

ls=socket.socket(); ls.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
ls.bind(('127.0.0.1',25254)); ls.listen(1)
open(ready,'w').write('READY\n')
conn,_=ls.accept()
send(conn,'220 mx.outside.test ESMTP fixture')
line=recvline(conn); assert line and line.upper().startswith(b'EHLO '), line
send(conn,'250-mx.outside.test'); send(conn,'250-STARTTLS'); send(conn,'250 SIZE 26214400')
line=recvline(conn); assert line==b'STARTTLS', line
send(conn,'220 2.0.0 Ready to start TLS')
ctx=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER); ctx.load_cert_chain(cert,key)
conn=ctx.wrap_socket(conn,server_side=True)
line=recvline(conn); assert line and line.upper().startswith(b'EHLO '), line
send(conn,'250-mx.outside.test'); send(conn,'250 SIZE 26214400')
line=recvline(conn); assert line and line.upper().startswith(b'MAIL FROM:'), line
send(conn,'250 2.1.0 sender ok')
recipients=[]
while True:
    line=recvline(conn); assert line is not None
    if line.upper().startswith(b'RCPT TO:'):
        recipients.append(line.decode()); send(conn,'250 2.1.5 recipient ok'); continue
    assert line==b'DATA', line
    break
send(conn,'354 send it')
body=[]
while True:
    line=recvline(conn); assert line is not None
    if line==b'.': break
    if line.startswith(b'..'): line=line[1:]
    body.append(line)
open(capture,'wb').write(b'\r\n'.join(body)+b'\r\n')
send(conn,'250 2.0.0 queued as fixture-1')
line=recvline(conn)
if line==b'QUIT': send(conn,'221 2.0.0 bye')
conn.close(); ls.close()
print('outbound STARTTLS fixture PASS')
