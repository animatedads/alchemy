#!/usr/bin/env python3
import argparse
import json
import socketserver

WIRE_PROTOCOL = "runtime.reference/0.1"

class Handler(socketserver.StreamRequestHandler):
    def handle(self):
        raw = self.rfile.readline(1_048_577)
        if not raw:
            return
        try:
            req = json.loads(raw)
            op = req.get("operation", "")
            if req.get("protocol") != WIRE_PROTOCOL:
                out = {
                    "protocol": WIRE_PROTOCOL,
                    "operation": op,
                    "status": "rejected_before_execution",
                    "detail": "protocol mismatch",
                }
            elif op == "test.counter.increment.tcp/1":
                state = req["state"]
                args = req["arguments"]
                new_count = int(state["values"]["count"]) + int(args["delta"])
                out = {
                    "protocol": WIRE_PROTOCOL,
                    "operation": op,
                    "status": "completed",
                    "provider": "python.state.reference",
                    "implementation": "python.counter.increment/1",
                    "value": {
                        "state_contract": state["state_contract"],
                        "object_id": state["object_id"],
                        "base_version": state["base_version"],
                        "mutations": {"count": new_count},
                        "return_value": new_count,
                    },
                }
            else:
                out = {
                    "protocol": WIRE_PROTOCOL,
                    "operation": op,
                    "status": "unsupported",
                    "provider": "python.state.reference",
                    "detail": "operation not implemented",
                }
        except Exception as exc:
            out = {
                "protocol": WIRE_PROTOCOL,
                "operation": locals().get("op", ""),
                "status": "fault",
                "provider": "python.state.reference",
                "detail": type(exc).__name__,
            }
        self.wfile.write((json.dumps(out, separators=(",", ":")) + "\n").encode())

class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=0)
    ap.add_argument("--port-file", required=True)
    ns = ap.parse_args()
    with Server((ns.host, ns.port), Handler) as server:
        with open(ns.port_file, "w", encoding="ascii") as f:
            f.write(str(server.server_address[1]))
        server.serve_forever()
