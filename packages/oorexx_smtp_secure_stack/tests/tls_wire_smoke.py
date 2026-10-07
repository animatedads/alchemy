import socket, ssl, sys, time

def recvline(s):
    b=b''
    while not b.endswith(b'\n'):
        c=s.recv(1)
        if not c: raise RuntimeError('EOF')
        b+=c
    return b.decode(errors='replace').rstrip('\r\n')

s=socket.create_connection(('127.0.0.1',25253), timeout=5)
assert recvline(s).startswith('220 ')
s.sendall(b'EHLO client.test\r\n')
lines=[]
while True:
    line=recvline(s); lines.append(line)
    if line.startswith('250 '): break
assert any('STARTTLS' in x for x in lines), lines
s.sendall(b'STARTTLS\r\n')
line=recvline(s)
assert line.startswith('220 '), line
ctx=ssl.create_default_context()
ctx.check_hostname=False
ctx.verify_mode=ssl.CERT_NONE
t=ctx.wrap_socket(s, server_hostname='localhost')
t.sendall(b'EHLO tls-client.test\r\n')
lines=[]
while True:
    line=recvline(t); lines.append(line)
    if line.startswith('250 '): break
assert any('AUTH ' in x for x in lines), lines
t.sendall(b'QUIT\r\n')
assert recvline(t).startswith('221 ')
t.close()
print('tls wire smoke PASS')
