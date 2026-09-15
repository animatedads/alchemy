import socket, ssl, sys
from h2.config import H2Configuration
from h2.connection import H2Connection
from h2.events import RequestReceived, DataReceived, StreamEnded
HOST='127.0.0.1'; PORT=18444
ctx=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.load_cert_chain('tests/tls/cert.pem','tests/tls/key.pem')
ctx.set_alpn_protocols(['h2'])
ls=socket.socket(); ls.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1); ls.bind((HOST,PORT)); ls.listen(20)
while True:
    raw,_=ls.accept()
    try:
        s=ctx.wrap_socket(raw,server_side=True)
        if s.selected_alpn_protocol()!='h2': s.close(); continue
        h=H2Connection(H2Configuration(client_side=False,header_encoding='utf-8')); h.initiate_connection(); s.sendall(h.data_to_send())
        reqs={}; bodies={}
        while True:
            data=s.recv(65535)
            if not data: break
            events=h.receive_data(data)
            for ev in events:
                if isinstance(ev,RequestReceived): reqs[ev.stream_id]=dict(ev.headers); bodies[ev.stream_id]=bytearray()
                elif isinstance(ev,DataReceived): bodies[ev.stream_id].extend(ev.data); h.acknowledge_received_data(ev.flow_controlled_length,ev.stream_id)
                elif isinstance(ev,StreamEnded):
                    q=reqs[ev.stream_id]; path=q.get(':path','/'); method=q.get(':method','GET')
                    status='200'; extra=[]
                    if path=='/hello': body=b'{"hello":"h2"}'
                    elif path=='/redirect': status='302'; extra=[('location','/hello')]; body=b''
                    elif path=='/loop': status='302'; extra=[('location','/loop')]; body=b''
                    elif path=='/cross': status='302'; extra=[('location','https://127.0.0.1:18444/hello')]; body=b''
                    elif path=='/echo': body=(method+' '+bytes(bodies[ev.stream_id]).decode('utf-8')).encode()
                    else: status='404'; body=b'not found'
                    headers=[(':status',status),('content-length',str(len(body))),('content-type','application/json')]+extra
                    h.send_headers(ev.stream_id,headers,end_stream=(len(body)==0))
                    if body: h.send_data(ev.stream_id,body,end_stream=True)
            out=h.data_to_send()
            if out: s.sendall(out)
    except Exception as e:
        print(repr(e),file=sys.stderr,flush=True)
    finally:
        try: raw.close()
        except Exception: pass
