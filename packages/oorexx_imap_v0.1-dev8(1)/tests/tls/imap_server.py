#!/usr/bin/env python3
import argparse, socket, ssl
p=argparse.ArgumentParser(); p.add_argument('--port',type=int,required=True); p.add_argument('--cert',required=True); p.add_argument('--key',required=True)
a=p.parse_args()
ctx=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER); ctx.load_cert_chain(a.cert,a.key)
with socket.socket() as ls:
    ls.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1); ls.bind(('127.0.0.1',a.port)); ls.listen(1)
    conn,_=ls.accept()
    with ctx.wrap_socket(conn,server_side=True) as s:
        f=s.makefile('rwb', buffering=0)
        f.write(b'* OK [CAPABILITY IMAP4rev1 UIDPLUS MOVE CONDSTORE ESEARCH LITERAL+] local test ready\r\n')
        while True:
            line=f.readline()
            if not line: break
            text=line.decode('utf-8','replace').rstrip('\r\n')
            parts=text.split(' ',2); tag=parts[0]; cmd=parts[1].upper() if len(parts)>1 else ''
            if cmd=='CAPABILITY':
                f.write(b'* CAPABILITY IMAP4rev1 UIDPLUS MOVE CONDSTORE ESEARCH LITERAL+\r\n'+tag.encode()+b' OK capability\r\n')
            elif cmd=='LOGIN':
                f.write(tag.encode()+b' OK logged in\r\n')
            elif cmd=='EXAMINE':
                f.write(b'* FLAGS (\\Seen \\Answered)\r\n* 100 EXISTS\r\n* OK [UIDVALIDITY 99] valid\r\n* OK [UIDNEXT 101] next\r\n* OK [HIGHESTMODSEQ 500] modseq\r\n'+tag.encode()+b' OK [READ-ONLY] examine\r\n')
            elif cmd=='STATUS':
                f.write(b'* STATUS "INBOX" (MESSAGES 100 UNSEEN 42 UIDNEXT 101 UIDVALIDITY 99 HIGHESTMODSEQ 500)\r\n'+tag.encode()+b' OK status\r\n')
            elif cmd=='LOGOUT':
                f.write(b'* BYE bye\r\n'+tag.encode()+b' OK logout\r\n'); break
            else:
                f.write(tag.encode()+b' BAD unsupported\r\n')
