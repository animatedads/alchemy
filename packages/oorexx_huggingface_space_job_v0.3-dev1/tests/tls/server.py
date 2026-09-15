import http.server, ssl, json, os
PORT=18444
TOKEN='Bearer hf_test_token_not_real_1234567890'
class H(http.server.BaseHTTPRequestHandler):
    protocol_version='HTTP/1.1'
    def log_message(self,*a): pass
    def auth(self):
        if self.headers.get('Authorization') != TOKEN:
            b=b'unauthorized'; self.send_response(401); self.send_header('Content-Length',str(len(b))); self.send_header('Connection','close'); self.end_headers(); self.wfile.write(b); self.close_connection=True; return False
        return True
    def reply(self,code,body,ctype='application/json'):
        if isinstance(body,str): body=body.encode()
        self.send_response(code); self.send_header('Content-Type',ctype); self.send_header('Content-Length',str(len(body))); self.send_header('Connection','close'); self.end_headers(); self.wfile.write(body); self.close_connection=True
    def do_POST(self):
        if not self.auth(): return
        n=int(self.headers.get('Content-Length','0')); body=self.rfile.read(n)
        if self.path=='/gradio_api/upload':
            if b'bundle-data-123' not in body: return self.reply(400,'{"error":"file missing"}')
            return self.reply(200,'["/tmp/gradio/input.bundle"]')
        if self.path=='/gradio_api/call/v2/job_cpu':
            return self.reply(405,'{}')
        if self.path=='/gradio_api/call/job_cpu':
            try: doc=json.loads(body.decode())
            except Exception: return self.reply(400,'{"error":"bad json"}')
            data=doc.get('data')
            if not isinstance(data,list) or len(data)!=3:
                return self.reply(400,'{"error":"data shape"}')
            req,fref,ctrl=data
            if req.get('label')!='fallback':
                return self.reply(400,'{"error":"payload"}')
            if fref.get('path')!='/tmp/gradio/input.bundle':
                return self.reply(400,'{"error":"upload ref"}')
            if ctrl.get('cleanup_remote') is not True or ctrl.get('tier')!='CPU' or ctrl.get('operation_id')!='MANAGED_SMOKE_V1':
                return self.reply(400,'{"error":"control"}')
            return self.reply(200,'{"event_id":"evt-cpu"}')
        if self.path=='/gradio_api/call/v2/job_large':
            try: doc=json.loads(body.decode())
            except Exception: return self.reply(400,'{"error":"bad json"}')
            req=doc.get('request',{})
            if req.get('steps')!=100 or req.get('vocab_target')!=65536:
                return self.reply(400,'{"error":"payload"}')
            if doc.get('input_bundle',{}).get('path')!='/tmp/gradio/input.bundle':
                return self.reply(400,'{"error":"upload ref"}')
            ctrl=doc.get('_job',{})
            if ctrl.get('cleanup_remote') is not True or ctrl.get('tier')!='ZEROGPU_LARGE' or ctrl.get('operation_id')!='GEMMA_OOREXX_RECOVERY_V1':
                return self.reply(400,'{"error":"control"}')
            return self.reply(200,'{"event_id":"evt-large"}')
        return self.reply(404,'{}')
    def do_GET(self):
        if not self.auth(): return
        if self.path=='/gradio_api/call/job_cpu/evt-cpu':
            result={"status":"COMPLETED","cleanup":"DONE","operation_id":"MANAGED_SMOKE_V1","artifact_name":"managed-output.zip","artifact_size":26,"artifact_sha256":"e6dc8ce6ba6471200248aa3e2d1cce80b85633db7cc370a5f8e630485b682e87"}
            fdata={"path":"/tmp/gradio/managed-output.zip","url":f"https://localhost:{PORT}/files/managed-output.zip","orig_name":"managed-output.zip","meta":{"_type":"gradio.FileData"}}
            chunks=[b'event: status\ndata: queued\n\n', ('event: complete\ndata: '+json.dumps([result,fdata],separators=(',',':'))+'\n\n').encode()]
            self.send_response(200); self.send_header('Content-Type','text/event-stream'); self.send_header('Transfer-Encoding','chunked'); self.send_header('Connection','close'); self.end_headers()
            for c in chunks:
                self.wfile.write((f'{len(c):X}\r\n').encode()+c+b'\r\n'); self.wfile.flush()
            self.wfile.write(b'0\r\n\r\n'); self.wfile.flush(); self.close_connection=True; return
        if self.path=='/gradio_api/call/job_large/evt-large':
            result={"status":"COMPLETED","cleanup":"DONE","operation_id":"GEMMA_OOREXX_RECOVERY_V1","artifact_name":"managed-output.zip","artifact_size":26,"artifact_sha256":"e6dc8ce6ba6471200248aa3e2d1cce80b85633db7cc370a5f8e630485b682e87"}
            fdata={"path":"/tmp/gradio/managed-output.zip","url":f"https://localhost:{PORT}/files/managed-output.zip","orig_name":"managed-output.zip","meta":{"_type":"gradio.FileData"}}
            chunks=[b'event: status\ndata: queued\n\n', ('event: complete\ndata: '+json.dumps([result,fdata],separators=(',',':'))+'\n\n').encode()]
            self.send_response(200); self.send_header('Content-Type','text/event-stream'); self.send_header('Transfer-Encoding','chunked'); self.send_header('Connection','close'); self.end_headers()
            for c in chunks:
                self.wfile.write((f'{len(c):X}\r\n').encode()+c+b'\r\n'); self.wfile.flush()
            self.wfile.write(b'0\r\n\r\n'); self.wfile.flush(); self.close_connection=True; return
        if self.path=='/files/managed-output.zip': return self.reply(200,b'managed-output-bundle-456\n','application/octet-stream')
        if self.path=='/gradio_api/info':
            info={"named_endpoints":{"/job_cpu":{"parameters":[{"parameter_name":"request"},{"parameter_name":"input_bundle"},{"parameter_name":"_job"}]}}}
            return self.reply(200,json.dumps(info,separators=(',',':')))
        return self.reply(404,'{}')
httpd=http.server.HTTPServer(('127.0.0.1',PORT),H)
ctx=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
here=os.path.dirname(os.path.abspath(__file__)); ctx.load_cert_chain(os.path.join(here,'cert.pem'),os.path.join(here,'key.pem'))
httpd.socket=ctx.wrap_socket(httpd.socket,server_side=True)
httpd.serve_forever()
