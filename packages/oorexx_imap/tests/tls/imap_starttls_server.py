#!/usr/bin/env python3
import argparse, socket, ssl
p=argparse.ArgumentParser(); p.add_argument('--port',type=int,required=True); p.add_argument('--cert',required=True); p.add_argument('--key',required=True)
a=p.parse_args()
ctx=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER); ctx.load_cert_chain(a.cert,a.key)
with socket.socket() as ls:
    ls.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1); ls.bind(('127.0.0.1',a.port)); ls.listen(1)
    conn,_=ls.accept()
    f=conn.makefile('rwb', buffering=0)
    f.write(b'* OK [CAPABILITY IMAP4rev1 STARTTLS LOGINDISABLED] local starttls ready\r\n')
    line=f.readline().decode('utf-8','replace').rstrip('\r\n')
    parts=line.split(' ',2); tag=parts[0]; cmd=parts[1].upper() if len(parts)>1 else ''
    if cmd!='STARTTLS':
        f.write(tag.encode()+b' BAD STARTTLS required\r\n'); conn.close(); raise SystemExit(1)
    f.write(tag.encode()+b' OK begin TLS\r\n')
    # Drop the plaintext file wrapper before wrapping the same connected socket.
    f.close()
    with ctx.wrap_socket(conn,server_side=True) as s:
        f=s.makefile('rwb', buffering=0)
        while True:
            line=f.readline()
            if not line: break
            text=line.decode('utf-8','replace').rstrip('\r\n')
            parts=text.split(' ',2); tag=parts[0]; cmd=parts[1].upper() if len(parts)>1 else ''
            if cmd=='CAPABILITY':
                f.write(b'* CAPABILITY IMAP4rev1 UIDPLUS MOVE CONDSTORE ESEARCH LITERAL+\r\n'+tag.encode()+b' OK capability\r\n')
            elif cmd=='LOGIN':
                f.write(tag.encode()+b' OK logged in\r\n')
            elif cmd=='LOGOUT':
                f.write(b'* BYE bye\r\n'+tag.encode()+b' OK logout\r\n'); break
            else:
                f.write(tag.encode()+b' BAD unsupported\r\n')
