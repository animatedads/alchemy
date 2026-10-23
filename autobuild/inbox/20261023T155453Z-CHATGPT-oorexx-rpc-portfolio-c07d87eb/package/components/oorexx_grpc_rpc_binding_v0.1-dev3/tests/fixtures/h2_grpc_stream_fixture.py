#!/usr/bin/env python3
"""Independent hyper-h2 gRPC server-stream fixture. Test-only."""
import socket,ssl,sys,time,threading,struct
from h2.config import H2Configuration
from h2.connection import H2Connection
from h2.events import RequestReceived, DataReceived, StreamEnded
out_path=sys.argv[1]
tls=(len(sys.argv)>2 and sys.argv[2]=='--tls')
ctx=None
if tls:
    ctx=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain(sys.argv[3],sys.argv[4]);ctx.set_alpn_protocols(['h2'])
sock=socket.socket();sock.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1);sock.bind(('127.0.0.1',0));sock.listen(20)
with open(out_path,'w') as f:f.write(str(sock.getsockname()[1]))

def serve(conn):
    try:
        conn.settimeout(8)
        h=H2Connection(config=H2Configuration(client_side=False,header_encoding='utf-8'))
        h.initiate_connection();conn.sendall(h.data_to_send());headers={};requests={}
        def flush():
            value=h.data_to_send()
            if value:conn.sendall(value)
        while True:
            data=conn.recv(65536)
            if not data:return
            for event in h.receive_data(data):
                if isinstance(event,RequestReceived):
                    headers[event.stream_id]=dict(event.headers);requests[event.stream_id]=b''
                elif isinstance(event,DataReceived):
                    requests[event.stream_id]+=event.data
                    h.acknowledge_received_data(event.flow_controlled_length,event.stream_id)
                elif isinstance(event,StreamEnded):
                    sid=event.stream_id;path=headers[sid].get(':path','')
                    if headers[sid].get(':method')!='POST' or headers[sid].get('content-type')!='application/grpc+proto' or headers[sid].get('te')!='trailers':
                        h.send_headers(sid,[(':status','415')],end_stream=True);continue
                    req=requests[sid]
                    if len(req)<5 or req[0]!=0 or int.from_bytes(req[1:5],'big')!=len(req)-5:
                        h.send_headers(sid,[(':status','200'),('content-type','application/grpc+proto'),('grpc-status','3')],end_stream=True);continue
                    if path=='/demo.Inventory/Hang':time.sleep(0.40)
                    typ='text/plain' if path=='/demo.Inventory/WrongType' else 'application/grpc+proto'
                    h.send_headers(sid,[(':status','200'),('content-type',typ)]);flush()
                    for idx in range(3):
                        frame=b'\0'+struct.pack('>I',2)+b'\x08'+bytes([42+idx])
                        # fragment gRPC header and protobuf body across HTTP/2 DATA events
                        h.send_data(sid,frame[:3]);flush()
                        h.send_data(sid,frame[3:]);flush()
                        if path=='/demo.Inventory/Slow':time.sleep(0.08)
                    if path=='/demo.Inventory/NoStatus':h.end_stream(sid)
                    elif path=='/demo.Inventory/DoubleStatus':h.send_headers(sid,[('grpc-status','0'),('grpc-status','0')],end_stream=True)
                    elif path=='/demo.Inventory/Fault':h.send_headers(sid,[('grpc-status','7')],end_stream=True)
                    else:h.send_headers(sid,[('grpc-status','0')],end_stream=True)
            flush()
    except (OSError,ConnectionError,ValueError,ssl.SSLError):pass
    finally:conn.close()
while True:
    conn,_=sock.accept()
    if tls:
        try:conn=ctx.wrap_socket(conn,server_side=True)
        except ssl.SSLError:conn.close();continue
    threading.Thread(target=serve,args=(conn,),daemon=True).start()
