#!/usr/bin/env python3
import argparse, json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

class Handler(BaseHTTPRequestHandler):
    model = "qwen2.5-1.5b-npu"
    request_log = None
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
        content=((req.get("messages") or [{}])[0].get("content") or "")
        if "REQUIRED_REASONING_OBLIGATIONS:" not in content or "CLAIMED_REASONING_SUMMARY:" not in content:
            return self._send(400,{"error":"missing reasoning comparison sections"})
        if self.request_log:
            open(self.request_log,"w").write(json.dumps(req))
        answer=json.dumps({"score":0.92,"gaps":[]},separators=(",",":"))
        self._send(200,{"id":"qwen-management-1","object":"chat.completion","model":req.get("model",self.model),"choices":[{"index":0,"message":{"role":"assistant","content":answer},"finish_reason":"stop"}],"usage":{"prompt_tokens":73,"completion_tokens":12}})

p=argparse.ArgumentParser(); p.add_argument("--port",type=int,default=0); p.add_argument("--port-file",required=True); p.add_argument("--request-log",required=True); a=p.parse_args()
Handler.request_log=a.request_log
server=ThreadingHTTPServer(("127.0.0.1",a.port),Handler)
with open(a.port_file,"w") as f: f.write(str(server.server_address[1]))
server.serve_forever()
