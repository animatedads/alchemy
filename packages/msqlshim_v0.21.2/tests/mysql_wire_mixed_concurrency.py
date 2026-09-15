#!/usr/bin/env python3
"""v0.07 regression: a blocked compressed result stream must not serialize other clients.

Creates a large temporary customer table, starts the ooRexx listener, then:
  1. connects client A with CLIENT_COMPRESS;
  2. sends SELECT * FROM customer and deliberately does not read the result,
     so the server eventually blocks writing A's large response;
  3. connects client B without compression and sends SELECT @@version;
  4. requires B to receive a result promptly while A is still blocked.

v0.06 serialized COM_QUERY/result encoding on the MySQLWireServer object guard.
"""
from pathlib import Path
import os, shutil, socket, struct, subprocess, sys, tempfile, time, zlib

HOST = "127.0.0.1"
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 3454
ROWS = int(os.environ.get("MSQLSHIM_CONCURRENCY_ROWS", "120000"))
REXX = os.environ.get("REXX", "rexx")

CLIENT_LONG_PASSWORD = 1
CLIENT_LONG_FLAG = 4
CLIENT_COMPRESS = 32
CLIENT_PROTOCOL_41 = 512
CLIENT_TRANSACTIONS = 8192
CLIENT_SECURE_CONNECTION = 32768
CLIENT_MULTI_RESULTS = 131072
CLIENT_PLUGIN_AUTH = 524288
BASE_FLAGS = (CLIENT_LONG_PASSWORD | CLIENT_LONG_FLAG | CLIENT_PROTOCOL_41 |
              CLIENT_TRANSACTIONS | CLIENT_SECURE_CONNECTION |
              CLIENT_MULTI_RESULTS | CLIENT_PLUGIN_AUTH)


def recvn(sock, n):
    out = b""
    while len(out) < n:
        part = sock.recv(n - len(out))
        if not part:
            raise EOFError("socket closed")
        out += part
    return out


def basic_read(sock):
    header = recvn(sock, 4)
    size = int.from_bytes(header[:3], "little")
    return header[3], recvn(sock, size)


def basic_send(sock, seq, payload):
    sock.sendall(len(payload).to_bytes(3, "little") + bytes([seq]) + payload)


def compressed_send(sock, cseq, seq, payload):
    inner = len(payload).to_bytes(3, "little") + bytes([seq]) + payload
    compressed = zlib.compress(inner)
    if len(compressed) < len(inner):
        body, ulen = compressed, len(inner)
    else:
        body, ulen = inner, 0
    sock.sendall(len(body).to_bytes(3, "little") + bytes([cseq]) + ulen.to_bytes(3, "little") + body)


def authenticate(compressed=False, timeout=5.0):
    sock = socket.create_connection((HOST, PORT), timeout=timeout)
    sock.settimeout(timeout)
    seq, greeting = basic_read(sock)
    if seq != 0 or not greeting or greeting[0] != 10:
        raise RuntimeError("bad greeting")
    flags = BASE_FLAGS | (CLIENT_COMPRESS if compressed else 0)
    response = (struct.pack("<I", flags) + struct.pack("<I", 16 * 1024 * 1024) +
                bytes([45]) + b"\0" * 23 + b"nosql\0" + b"\0" +
                b"mysql_native_password\0")
    basic_send(sock, 1, response)
    seq, ok = basic_read(sock)
    if seq != 2 or not ok or ok[0] != 0:
        raise RuntimeError("authentication OK not received")
    return sock


def wait_for_server(proc, deadline=8.0):
    end = time.time() + deadline
    while time.time() < end:
        if proc.poll() is not None:
            raise RuntimeError("server exited before accepting connections")
        try:
            s = socket.create_connection((HOST, PORT), timeout=0.2)
            s.close()
            return
        except OSError:
            time.sleep(0.05)
    raise RuntimeError("server did not start")


project = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="msqlshim_v007_") as td:
    db = Path(td) / "demo"
    shutil.copytree(project / "example" / "demo", db)
    data = db / "tables" / "customer" / "data"
    with data.open("w", encoding="utf-8", newline="\n") as f:
        f.write('"customer_id","name","email"\n')
        for i in range(1, ROWS + 1):
            f.write(f'{700000+i},"Concurrent Row {i:06d}","row{i:06d}@example.test"\n')

    env = os.environ.copy()
    proc = subprocess.Popen(
        [REXX, "mysql_wire_server.rex", str(db), str(PORT), HOST],
        cwd=project, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True,
    )
    first = second = None
    passed = False
    try:
        wait_for_server(proc)

        first = authenticate(compressed=True)
        # Make the client receive buffer deliberately tiny so the server reaches
        # blocking send() quickly while returning the large resultset.
        first.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 4096)
        first.settimeout(10)
        compressed_send(first, 0, 0, b"\x03SELECT * FROM customer")
        time.sleep(1.0)
        print("PASS compressed client started large unread result stream")

        started = time.monotonic()
        second = authenticate(compressed=False, timeout=4.0)
        basic_send(second, 0, b"\x03SELECT @@version")
        second.settimeout(4.0)
        seq, packet = basic_read(second)
        elapsed = time.monotonic() - started
        if seq != 1 or not packet or packet[0] == 0xFF:
            raise RuntimeError("second client query did not receive a result header")
        if elapsed > 4.0:
            raise RuntimeError(f"second client was serialized for {elapsed:.3f}s")
        print(f"PASS uncompressed second client queried while compressed stream blocked ({elapsed:.3f}s)")
        print("MYSQL WIRE MIXED CONCURRENCY SMOKE PASS")
        passed = True
    finally:
        if second is not None:
            try: second.close()
            except OSError: pass
        if first is not None:
            try: first.close()
            except OSError: pass
        try:
            proc.terminate()
            proc.wait(timeout=3)
        except Exception:
            proc.kill()
            proc.wait(timeout=3)
        if proc.stdout:
            output = proc.stdout.read()
            if (not passed) and output.strip():
                print("--- server output ---")
                print(output.rstrip())
