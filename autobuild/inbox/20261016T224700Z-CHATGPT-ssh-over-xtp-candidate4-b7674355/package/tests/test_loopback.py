#!/usr/bin/env python3
"""Real XTP-over-UDP process test; fake local SSH endpoint, no root needed."""
import contextlib
import os
import pathlib
import secrets
import socket
import subprocess
import tempfile
import threading
import time

ROOT = pathlib.Path(__file__).resolve().parent.parent
BIN = ROOT / 'bin/ssh-xtp'


def port():
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
        s.bind(('127.0.0.1', 0))
        return s.getsockname()[1]


def tcp_port():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(('127.0.0.1', 0))
        return s.getsockname()[1]


def fake_server(portno, accepted, errors):
    try:
        with socket.socket() as ls:
            ls.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            ls.bind(('127.0.0.1', portno))
            ls.listen(1)
            ls.settimeout(8)
            with ls.accept()[0] as conn:
                accepted.set()
                conn.settimeout(10)
                conn.sendall(b'SSH-2.0-test-server\r\n')
                while True:
                    data = conn.recv(1024)
                    if not data:
                        break
                    conn.sendall(data)
                conn.shutdown(socket.SHUT_WR)
    except Exception as e:
        errors.append(str(e))


def setup(tmp, mode, key=None):
    pserver, pclient, sshport = port(), port(), tcp_port()
    routes = tmp / 'routes.tsv'
    routes.write_text(
        f'server_ingress\t4\tudp\t127.0.0.1:{pserver}\t\t100\t1\t\t0\n'
        f'client_ingress\t4\tudp\t127.0.0.1:{pclient}\t\t100\t1\t\t0\n'
    )
    keyfile = tmp / 'shared.hex'
    keyfile.write_text((key or secrets.token_hex(32)) + '\n')
    keyfile.chmod(0o600)
    policyfile = tmp / 'state'
    policyfile.write_text(mode + '\n')
    policyfile.chmod(0o600)
    service_registry=tmp/'services.tsv'
    service_registry.write_text('ssh.management\tMANAGEMENT.CRITICAL\tserver_ingress\tssh.management\t1\tSSH gateway\n')
    service_registry.chmod(0o600)
    operational_registry=tmp/'operational.tsv'
    operational_registry.write_text('MANAGEMENT.CRITICAL\tallow\tallow\tallow\tallow\n')
    operational_registry.chmod(0o600)
    env = os.environ | {'XTP_ROUTE_FILE': str(routes), 'XTP_HEALTH_FILE': str(tmp/'health.tsv')}
    server = [str(BIN), 'gateway', '--rx-peer', 'server_ingress', '--tx-peer', 'client_ingress',
              '--key-file', str(keyfile), '--policy-file', str(policyfile), '--client-id', 'testnode',
              '--ssh-port', str(sshport), '--idle-seconds', '6',
              '--allow-user-owned-policy-for-test', 'yes',
              '--service-registry', str(service_registry), '--operational-registry', str(operational_registry),
              '--allow-user-owned-registry-for-test', 'yes']
    client = [str(BIN), 'client', '--rx-peer', 'client_ingress', '--tx-peer', 'server_ingress',
              '--key-file', str(keyfile), '--client-id', 'testnode', '--idle-seconds', '6']
    return sshport, policyfile, env, server, client


def run_case(name, mode, *, badkey=False):
    with tempfile.TemporaryDirectory(prefix='xtp-ssh-test-') as d:
        tmp = pathlib.Path(d)
        sshport, policyfile, env, server, client = setup(tmp, mode)
        errs, accepted = [], threading.Event()
        if mode == 'OPEN' and not badkey:
            t = threading.Thread(target=fake_server, args=(sshport, accepted, errs), daemon=True)
            t.start()
        gateway = subprocess.Popen(server, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        try:
            time.sleep(.25)
            if badkey:
                alt = tmp / 'wrong.hex';alt.write_text(secrets.token_hex(32) + '\n');alt.chmod(0o600)
                client[client.index('--key-file') + 1] = str(alt)
            payload = b'SSH-2.0-test-client\r\n' + bytes(range(256))*20
            out = subprocess.run(client, input=payload, env=env, capture_output=True, timeout=12)
            if mode == 'OPEN' and not badkey:
                assert out.returncode == 0, (out.returncode, out.stderr)
                assert out.stdout == b'SSH-2.0-test-server\r\n' + payload, (len(out.stdout), out.stderr)
                assert accepted.is_set() and not errs, errs
            else:
                assert out.returncode != 0, (out.returncode, out.stderr)
                assert not accepted.is_set(), 'policy bypass opened local SSH'
            print(f'PASS {name}: client_rc={out.returncode}', flush=True)
        finally:
            gateway.terminate()
            try:
                _, err = gateway.communicate(timeout=3)
            except subprocess.TimeoutExpired:
                gateway.kill(); _,err = gateway.communicate()
            if mode == 'OPEN' and not badkey and gateway.returncode not in (0,-15):
                print('gateway stderr:', err.decode(errors='replace'))




def read_until(stream, needle, timeout=5):
    import select
    end = time.monotonic() + timeout
    b = b''
    while needle not in b and time.monotonic() < end:
        if select.select([stream], [], [], .1)[0]:
            more = os.read(stream.fileno(), 8192)
            if not more:
                break
            b += more
    return b


def run_active_mode_transition():
    with tempfile.TemporaryDirectory(prefix='xtp-ssh-live-') as d:
        tmp = pathlib.Path(d)
        sshport, policyfile, env, server, client = setup(tmp, 'OPEN')
        errs, accepted = [], threading.Event()
        t = threading.Thread(target=fake_server, args=(sshport, accepted, errs), daemon=True)
        t.start()
        gw = subprocess.Popen(server, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        cp = None
        try:
            time.sleep(.25)
            cp = subprocess.Popen(client, env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                  stderr=subprocess.PIPE)
            assert accepted.wait(5), 'no connection established'
            assert b'SSH-2.0-test-server\r\n' in read_until(cp.stdout, b'SSH-2.0-test-server\r\n')
            policyfile.write_text('LOCKED\n')
            time.sleep(.5)
            cp.stdin.write(b'SSH-2.0-after-lock\r\n');cp.stdin.flush()
            assert b'SSH-2.0-after-lock\r\n' in read_until(cp.stdout, b'SSH-2.0-after-lock\r\n')
            print('PASS LOCKED preserves authenticated active session', flush=True)
            policyfile.write_text('SEALED\n')
            rc=cp.wait(timeout=5)
            assert rc!=0, 'SEALED did not tear down active client'
            assert gw.wait(timeout=5)==0, 'gateway did not terminate on SEALED'
            print('PASS SEALED terminates authenticated active session', flush=True)
        finally:
            if cp is not None and cp.poll() is None:
                cp.kill();cp.communicate(timeout=3)
            if gw.poll() is None:
                gw.terminate();gw.communicate(timeout=3)


if __name__ == '__main__':
    run_case('authorized binary duplex', 'OPEN')
    run_case('LOCKED refuses new session', 'LOCKED')
    run_case('SEALED refuses new session', 'SEALED')
    run_case('bad HMAC key cannot access local sshd', 'OPEN', badkey=True)
    run_active_mode_transition()

