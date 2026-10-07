#!/usr/bin/env python3
import argparse, json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

class Handler(BaseHTTPRequestHandler):
    count = 0
    model = "tiny-fixture-model"
    def log_message(self, fmt, *args):
        pass
    def _send(self, status, obj):
        body=json.dumps(obj).encode()
        self.send_response(status)
        self.send_header("Content-Type","application/json")
        self.send_header("Content-Length",str(len(body)))
        self.end_headers(); self.wfile.write(body)
    def do_GET(self):
        if self.path == "/v1/models":
            return self._send(200,{"object":"list","data":[{"id":self.model,"object":"model"}]})
        self._send(404,{"error":"not found"})
    def do_POST(self):
        if self.path != "/v1/chat/completions":
            return self._send(404,{"error":"not found"})
        n=int(self.headers.get("Content-Length","0")); raw=self.rfile.read(n)
        try: req=json.loads(raw)
        except Exception: return self._send(400,{"error":"bad json"})
        Handler.count += 1
        if Handler.count == 1:
            content=json.dumps({"source":"say \"HELLO WROLD\""})
            usage={"prompt_tokens":20,"completion_tokens":10}
        else:
            content=json.dumps({"action":"REPLACE","source":"say \"HELLO WORLD\""})
            usage={"prompt_tokens":30,"completion_tokens":15}
        self._send(200,{"id":f"fixture-{Handler.count}","object":"chat.completion","model":req.get("model",self.model),"choices":[{"index":0,"message":{"role":"assistant","content":content},"finish_reason":"stop"}],"usage":usage})

p=argparse.ArgumentParser(); p.add_argument("--port",type=int,default=0); p.add_argument("--port-file",required=True); a=p.parse_args()
server=ThreadingHTTPServer(("127.0.0.1",a.port),Handler)
with open(a.port_file,"w") as f: f.write(str(server.server_address[1]))
server.serve_forever()
