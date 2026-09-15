import json, sys
from http.server import BaseHTTPRequestHandler, HTTPServer

port=int(sys.argv[1])
class H(BaseHTTPRequestHandler):
    requests_left=2
    def log_message(self, fmt, *args):
        pass
    def do_POST(self):
        n=int(self.headers.get('Content-Length','0'))
        _=self.rfile.read(n)
        if self.path == '/xai':
            body={"choices":[{"message":{"content":"ACTION=CALL\nAMOUNT=0\nTALK=CALL_OUT\nTALK_TARGET=Hugo\nSOCIAL_EVIDENCE=E2"}}]}
        else:
            body={"candidates":[{"content":{"parts":[{"text":"ACTION=RAISE\nAMOUNT=17\nTALK=NICE_HAND\nTALK_TARGET=Ada\nSOCIAL_EVIDENCE=E1"}]}}]}
        raw=json.dumps(body).encode()
        self.send_response(200)
        self.send_header('Content-Type','application/json')
        self.send_header('Content-Length',str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)
        H.requests_left-=1
        if H.requests_left <= 0:
            self.server._BaseServer__shutdown_request = True
            import threading
            threading.Thread(target=self.server.shutdown,daemon=True).start()

HTTPServer(('127.0.0.1',port),H).serve_forever()
