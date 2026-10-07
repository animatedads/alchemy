import socket,sys,os
host='127.0.0.1'; port=int(sys.argv[1]); ready=sys.argv[2] if len(sys.argv)>2 else ''
s=socket.socket(); s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1); s.bind((host,port)); s.listen(1)
if ready:
    with open(ready,'w') as f: f.write('ready\n')
c,_=s.accept(); f=c.makefile('rwb', buffering=0)
def send(x): f.write(x.encode())
def line():
    b=f.readline()
    return b.decode(errors='replace').rstrip('\r\n') if b else None
send('220 review.test ESMTP\r\n')
assert (line() or '').startswith('EHLO '); send('250 review.test\r\n')
assert (line() or '').startswith('MAIL FROM:'); send('250 sender ok\r\n')
assert (line() or '').startswith('RCPT TO:'); send('250 rcpt ok\r\n')
assert line()=='DATA'; send('354 end data\r\n')
while True:
    x=line()
    if x is None: raise SystemExit('client disconnected before terminator')
    if x=='.': break
send('250 queued\r\n')
# Transaction is accepted. Deliberately close before a QUIT response.
c.shutdown(socket.SHUT_RDWR); c.close(); s.close()
