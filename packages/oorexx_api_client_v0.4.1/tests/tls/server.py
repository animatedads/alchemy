import http.server, ssl, json, sys, os
class H(http.server.BaseHTTPRequestHandler):
    protocol_version='HTTP/1.1'
    def log_message(self,*a): pass
    def do_GET(self):
        if self.path=='/hello':
            b=b'{"hello":"world"}'
            self.send_response(200); self.send_header('Content-Type','application/json'); self.send_header('Content-Length',str(len(b))); self.send_header('Connection','close'); self.end_headers(); self.wfile.write(b); self.close_connection=True
        elif self.path=='/events/evt1':
            chunks=[b'event: status\ndata: queued\n\n', b'event: complete\ndata: ["done"]\n\n']
            self.send_response(200); self.send_header('Content-Type','text/event-stream'); self.send_header('Transfer-Encoding','chunked'); self.send_header('Connection','close'); self.end_headers()
            for c in chunks:
                self.wfile.write((f'{len(c):X}\r\n').encode()+c+b'\r\n'); self.wfile.flush()
            self.wfile.write(b'0\r\n\r\n'); self.wfile.flush(); self.close_connection=True
        else:
            self.send_error(404); self.close_connection=True
    def do_POST(self):
        n=int(self.headers.get('Content-Length','0')); body=self.rfile.read(n)
        if self.path=='/submit':
            b=b'{"event_id":"evt1"}'
            self.send_response(200); self.send_header('Content-Type','application/json'); self.send_header('Content-Length',str(len(b))); self.send_header('Connection','close'); self.end_headers(); self.wfile.write(b); self.close_connection=True
        else: self.send_error(404); self.close_connection=True
httpd=http.server.HTTPServer(('127.0.0.1', 18443), H)
ctx=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER); here=os.path.dirname(os.path.abspath(__file__)); ctx.load_cert_chain(os.path.join(here,'cert.pem'),os.path.join(here,'key.pem')); httpd.socket=ctx.wrap_socket(httpd.socket,server_side=True)
httpd.serve_forever()
