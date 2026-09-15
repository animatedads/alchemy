#!/usr/bin/env python3
"""v0.08 regression: sustained one-row writes must not starve a queued reader.

The shim intentionally keeps one FileDatabaseEngine instance because that is the
backend's current concurrency/isolation boundary.  v0.08 adds a FIFO ticket gate
*in front* of that guarded engine.  This test keeps one client issuing sequential
INSERTs and asks a second client for COUNT(*) while the writer is active.  The
reader must complete before the writer drains the whole workload.
"""
from pathlib import Path
import os, shutil, socket, struct, subprocess, sys, tempfile, threading, time

HOST = "127.0.0.1"
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 3456
REXX = os.environ.get("REXX", "rexx")
WRITES = int(os.environ.get("MSQLSHIM_FAIRNESS_WRITES", "500"))

CLIENT_LONG_PASSWORD = 1
CLIENT_LONG_FLAG = 4
CLIENT_PROTOCOL_41 = 512
CLIENT_TRANSACTIONS = 8192
CLIENT_SECURE_CONNECTION = 32768
CLIENT_MULTI_RESULTS = 131072
CLIENT_PLUGIN_AUTH = 524288
FLAGS = (CLIENT_LONG_PASSWORD | CLIENT_LONG_FLAG | CLIENT_PROTOCOL_41 |
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


def read_packet(sock):
    header = recvn(sock, 4)
    size = int.from_bytes(header[:3], "little")
    return header[3], recvn(sock, size)


def send_packet(sock, seq, payload):
    sock.sendall(len(payload).to_bytes(3, "little") + bytes([seq]) + payload)


def connect_client(timeout=5.0):
    sock = socket.create_connection((HOST, PORT), timeout=timeout)
    sock.settimeout(timeout)
    seq, greeting = read_packet(sock)
    if seq != 0 or not greeting or greeting[0] != 10:
        raise RuntimeError("bad greeting")
    response = (struct.pack("<I", FLAGS) + struct.pack("<I", 16 * 1024 * 1024) +
                bytes([45]) + b"\0" * 23 + b"nosql\0" + b"\0" +
                b"mysql_native_password\0")
    send_packet(sock, 1, response)
    seq, ok = read_packet(sock)
    if seq != 2 or not ok or ok[0] != 0:
        raise RuntimeError("authentication OK not received")
    return sock


def query_ok(sock, sql):
    send_packet(sock, 0, b"\x03" + sql.encode())
    seq, packet = read_packet(sock)
    if not packet:
        raise RuntimeError("empty response")
    if packet[0] == 0xFF:
        raise RuntimeError("server ERR: " + packet[3:].decode(errors="replace"))
    if packet[0] != 0x00:
        raise RuntimeError("expected OK packet")


def read_lenenc(packet, pos=0):
    first = packet[pos]
    if first < 0xFB:
        return first, pos + 1
    if first == 0xFC:
        return int.from_bytes(packet[pos+1:pos+3], "little"), pos + 3
    if first == 0xFD:
        return int.from_bytes(packet[pos+1:pos+4], "little"), pos + 4
    if first == 0xFE:
        return int.from_bytes(packet[pos+1:pos+9], "little"), pos + 9
    raise RuntimeError("unexpected length-encoded marker")


def count_query(sock):
    send_packet(sock, 0, b"\x03SELECT COUNT(*) FROM customer")
    seq, header = read_packet(sock)
    if not header or header[0] == 0xFF:
        raise RuntimeError("COUNT query failed")
    columns, _ = read_lenenc(header)
    for _ in range(columns):
        read_packet(sock)
    read_packet(sock)  # metadata EOF/OK
    seq, row = read_packet(sock)
    value_len, pos = read_lenenc(row)
    value = int(row[pos:pos+value_len])
    read_packet(sock)  # result EOF/OK
    return value


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
with tempfile.TemporaryDirectory(prefix="msqlshim_v008_fair_") as td:
    db = Path(td) / "demo"
    shutil.copytree(project / "example" / "demo", db)
    proc = subprocess.Popen(
        [REXX, "mysql_wire_server.rex", str(db), str(PORT), HOST],
        cwd=project, env=os.environ.copy(), stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, text=True,
    )
    writer = reader = None
    writer_progress = 0
    writer_done = threading.Event()
    stop_writer = threading.Event()
    writer_error = []
    lock = threading.Lock()

    def run_writer():
        nonlocal_writer = None
        try:
            nonlocal_writer = connect_client(timeout=10.0)
            for i in range(WRITES):
                if stop_writer.is_set():
                    break
                sql = ("INSERT INTO customer (customer_id,name,email) VALUES "
                       f"({900000+i},'Fair Writer {i}','fair{i}@example.test')")
                query_ok(nonlocal_writer, sql)
                with lock:
                    progress[0] = i + 1
        except Exception as exc:
            writer_error.append(exc)
        finally:
            if nonlocal_writer is not None:
                try: nonlocal_writer.close()
                except OSError: pass
            writer_done.set()

    progress = [0]
    try:
        wait_for_server(proc)
        thread = threading.Thread(target=run_writer, daemon=True)
        thread.start()

        deadline = time.time() + 10
        while time.time() < deadline:
            with lock:
                p = progress[0]
            if p >= 25:
                break
            if writer_error:
                raise writer_error[0]
            time.sleep(0.01)
        if p < 25:
            raise RuntimeError("writer did not establish sustained workload")
        print(f"PASS writer active at {p} committed inserts")

        reader = connect_client(timeout=10.0)
        started_progress = p
        started = time.monotonic()
        count = count_query(reader)
        elapsed = time.monotonic() - started
        with lock:
            finished_progress = progress[0]

        if writer_done.is_set() and finished_progress >= WRITES:
            raise RuntimeError("reader completed only after writer drained entire workload")
        if elapsed > 5.0:
            raise RuntimeError(f"queued reader exceeded fairness bound: {elapsed:.3f}s")
        print(f"PASS queued COUNT completed in {elapsed:.3f}s while writer advanced {started_progress}->{finished_progress}")
        print(f"PASS reader observed {count} committed rows")
        print("MYSQL WIRE BACKEND FAIRNESS SMOKE PASS")
        stop_writer.set()
    finally:
        stop_writer.set()
        if reader is not None:
            try: reader.close()
            except OSError: pass
        writer_done.wait(timeout=10)
        try:
            proc.terminate(); proc.wait(timeout=3)
        except Exception:
            proc.kill(); proc.wait(timeout=3)
        if proc.stdout:
            output = proc.stdout.read()
            if writer_error:
                print("--- writer/server output ---")
                print(output.rstrip())
        if writer_error:
            raise writer_error[0]
