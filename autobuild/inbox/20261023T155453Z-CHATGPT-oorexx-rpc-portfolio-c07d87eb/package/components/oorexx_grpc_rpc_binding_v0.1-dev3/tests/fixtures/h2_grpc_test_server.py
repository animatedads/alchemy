#!/usr/bin/env python3
"""Independent HTTP/2 gRPC wire fixture. NOT a product server implementation.
Uses hyper-h2 to verify correct actual binary HTTP/2 exchange and trailers.
"""
import socket,threading,sys,struct,time,ssl
from h2.connection import H2Connection
from h2.config import H2Configuration
from h2.events import RequestReceived,DataReceived,StreamEnded
port_path=sys.argv[1]
tls = len(sys.argv)>3 and sys.argv[2]=='--tls'
sslctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER) if tls else None
if tls:
    sslctx.load_cert_chain(sys.argv[3],sys.argv[4]); sslctx.set_alpn_protocols(['h2'])
srv=socket.socket();srv.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1);srv.bind(('127.0.0.1',0));srv.listen(30)
with open(port_path,'w') as out:out.write(str(srv.getsockname()[1]))

def serve(client):
    try:
        client.settimeout(15)
        h=H2Connection(config=H2Configuration(client_side=False,header_encoding='utf-8'))
        h.initiate_connection();client.sendall(h.data_to_send())
        bodies={};headers={}
        while True:
            data=client.recv(65535)
            if not data:return
            for e in h.receive_data(data):
                if isinstance(e,RequestReceived):
                    headers[e.stream_id]=dict(e.headers);bodies[e.stream_id]=b''
                if isinstance(e,DataReceived):
                    bodies[e.stream_id]+=e.data
                    h.acknowledge_received_data(e.flow_controlled_length,e.stream_id)
                if isinstance(e,StreamEnded):
                    stream=e.stream_id
                    attrs=headers[stream];path=attrs.get(':path','')
                    if attrs.get(':method')!='POST' or attrs.get('te')!='trailers' or attrs.get('content-type')!='application/grpc+proto':
                        h.send_headers(stream,[(':status','415')],end_stream=True);continue
                    if path=='/demo.Inventory/Deadline':time.sleep(0.25)
                    if path=='/demo.Inventory/TimeoutHeader' and attrs.get('grpc-timeout') != '500m':
                        h.send_headers(stream,[(':status','400')],end_stream=True);continue
                    if path=='/demo.Inventory/HTTPError':
                        h.send_headers(stream,[(':status','503')],end_stream=True);continue
                    ct='text/plain' if path=='/demo.Inventory/BadContent' else 'application/grpc+json' if path=='/demo.Inventory/BadCodec' else 'application/grpc+proto'
                    h.send_headers(stream,[(':status','200'),('content-type',ct)])
                    if path=='/demo.Inventory/RemoteFault':
                        h.send_headers(stream,[('grpc-status','7'),('grpc-message','no')],end_stream=True)
                    elif path=='/demo.Inventory/DuplicateStatus':
                        h.send_headers(stream,[('grpc-status','0'),('grpc-status','0')],end_stream=True)
                    elif path=='/demo.Inventory/HeadersStatus':
                        pass
                    elif path=='/demo.Inventory/NoStatus':
                        h.send_data(stream,b'',end_stream=True)
                    elif path=='/demo.Inventory/Oversize':
                        h.send_data(stream,b'Z'*120000,end_stream=False)
                        h.send_headers(stream,[('grpc-status','0')],end_stream=True)
                    else:
                        frame=bodies[stream]
                        if len(frame)<5 or frame[0]!=0 or int.from_bytes(frame[1:5],'big')!=len(frame)-5:
                            h.send_headers(stream,[('grpc-status','3')],end_stream=True)
                        elif path=='/demo.Inventory/Metadata' and attrs.get('x-trace')!='token123':
                            h.send_headers(stream,[('grpc-status','7')],end_stream=True)
                        else:
                            # Simple protobuf field #1 uint32=42, independent of ooRexx provider
                            payload=b'\x08\x2a'
                            h.send_data(stream,b'\0'+struct.pack('>I',len(payload))+payload)
                            h.send_headers(stream,[('grpc-status','0')],end_stream=True)
            outgoing=h.data_to_send()
            if outgoing:client.sendall(outgoing)
    except (OSError,ConnectionError,ValueError):pass
    finally:client.close()

while True:
    client,addr=srv.accept()
    if tls:
        try:client=sslctx.wrap_socket(client,server_side=True)
        except ssl.SSLError:
            client.close();continue
    threading.Thread(target=serve,args=(client,),daemon=True).start()
