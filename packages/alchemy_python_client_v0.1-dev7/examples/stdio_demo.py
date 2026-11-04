"""A real round trip against JSON-RPC Fabric's qualified stdio *example*.

Usage (after install; valid ooRexx 5.3 configured with json.cls):
  REXX_PATH=/path/to/json-rpc/src:/path/to/oorexx/runtime/bin \
      python examples/stdio_demo.py /path/to/json-rpc/examples/stdio_server.rex
"""
import os
import sys
from alchemy_python import JsonRpcClient, SubprocessTransport

server = sys.argv[1]
client = JsonRpcClient(SubprocessTransport(["rexx", server], env=dict(os.environ)))
assert client.request("system.ping") == "pong"
assert client.request("math.sum", [1, 2, 3]) == 6
client.notify("system.ping")  # No reply; NO delivery acknowledgement.
print("ALCHEMY PYTHON / JSON-RPC STDIO PASS")
