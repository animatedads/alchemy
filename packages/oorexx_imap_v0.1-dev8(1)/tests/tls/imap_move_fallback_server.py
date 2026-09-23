#!/usr/bin/env python3
import argparse,socket,ssl
p=argparse.ArgumentParser(); p.add_argument('--port',type=int,required=True); p.add_argument('--cert',required=True); p.add_argument('--key',required=True); a=p.parse_args()
ctx=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER); ctx.load_cert_chain(a.cert,a.key)
ls=socket.socket(); ls.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1); ls.bind(('127.0.0.1',a.port)); ls.listen(1)
conn,_=ls.accept()
with ctx.wrap_socket(conn,server_side=True) as s:
    f=s.makefile('rwb',buffering=0)
    f.write(b'* OK [CAPABILITY IMAP4rev1 UIDPLUS] fallback-test ready\r\n')
    while True:
        line=f.readline()
        if not line: break
        text=line.decode('utf-8','replace').rstrip('\r\n'); parts=text.split(' ',1); tag=parts[0]; cmd=parts[1] if len(parts)>1 else ''
        u=cmd.upper()
        if u=='CAPABILITY': f.write(b'* CAPABILITY IMAP4rev1 UIDPLUS\r\n'+tag.encode()+b' OK capability\r\n')
        elif u.startswith('LOGIN '): f.write(tag.encode()+b' OK login\r\n')
        elif u.startswith('SELECT '): f.write(b'* 1 EXISTS\r\n* OK [UIDVALIDITY 11] valid\r\n'+tag.encode()+b' OK [READ-WRITE] selected\r\n')
        elif u.startswith('UID COPY 8 '): f.write(tag.encode()+b' OK [COPYUID 21 8 80] copied\r\n')
        elif u=='UID STORE 8 +FLAGS.SILENT (\\DELETED)': f.write(tag.encode()+b' OK marked\r\n')
        elif u=='UID EXPUNGE 8': f.write(b'* 1 EXPUNGE\r\n'+tag.encode()+b' OK expunged\r\n')
        elif u=='LOGOUT': f.write(b'* BYE bye\r\n'+tag.encode()+b' OK logout\r\n'); break
        else: f.write(tag.encode()+b' BAD unsupported\r\n')
ls.close()
