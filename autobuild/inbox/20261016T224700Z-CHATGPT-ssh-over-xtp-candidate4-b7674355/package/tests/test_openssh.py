#!/usr/bin/env python3
"""Actual OpenSSH-over-XTP qualification on a host with OpenSSH installed.

Creates a disposable, unprivileged sshd on 127.0.0.1:<ephemeral>, temporary
host/client keys, temporary known_hosts, and XTP-UDP loopback routes.
Does not write ~/.ssh, /etc/ssh, change any firewall, or modify existing sshd.
Gateway is launched afresh for each single-session connection (candidate-1 contract).
"""
import getpass
import os
from pathlib import Path
import pwd
import secrets
import shlex
import shutil
import socket
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent
BRIDGE = ROOT / 'bin' / 'ssh-xtp'


def tool(name):
    path = shutil.which(name)
    if not path and name == 'sshd':
        for candidate in ('/usr/sbin/sshd', '/sbin/sshd'):
            if Path(candidate).is_file():
                path = candidate
                break
    return path


def free_port(kind=socket.SOCK_STREAM):
    with socket.socket(socket.AF_INET, kind) as s:
        s.bind(('127.0.0.1', 0))
        return s.getsockname()[1]


def run(cmd, *, timeout=30, env=None, cwd=None):
    proc = subprocess.run(cmd, capture_output=True, timeout=timeout, env=env, cwd=cwd)
    if proc.returncode != 0:
        raise AssertionError(
            f'Command failed rc={proc.returncode}: {cmd!r}\n'
            f'stdout={proc.stdout.decode(errors="replace")[-3000:]}\n'
            f'stderr={proc.stderr.decode(errors="replace")[-3000:]}')
    return proc


def wait_sshd(proc, port):
    deadline = time.monotonic() + 7
    while time.monotonic() < deadline:
        if proc.poll() is not None:
            raise AssertionError('temporary sshd exited during startup')
        try:
            with socket.create_connection(('127.0.0.1', port), timeout=.15):
                return
        except (ConnectionError, TimeoutError, OSError):
            time.sleep(.1)
    raise AssertionError('temporary sshd did not bind loopback')


def stop(proc):
    if proc.poll() is None:
        proc.terminate()
        try:
            proc.wait(timeout=3)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait(timeout=3)


def main():
    needed = ['ssh', 'sshd', 'ssh-keygen', 'scp', 'sftp']
    paths = {name: tool(name) for name in needed}
    missing = [name for name in needed if paths[name] is None]
    if missing:
        print('NOT_RUN real OpenSSH-over-XTP: missing ' + ', '.join(missing), flush=True)
        return 77
    if not BRIDGE.is_file():
        print('ERROR missing bin/ssh-xtp; build with make first', file=sys.stderr)
        return 2
    user = pwd.getpwuid(os.geteuid()).pw_name
    if not user or any(c in user for c in (' ', '\n', '\t')):
        raise AssertionError('unsupported local account name for isolated sshd fixture')

    with tempfile.TemporaryDirectory(prefix='sshxtp-real-openssh-') as td:
        temp = Path(td)
        os.chmod(temp, 0o700)
        hostkey = temp / 'host_ed25519'
        clientkey = temp / 'client_ed25519'
        for key in (hostkey, clientkey):
            run([paths['ssh-keygen'], '-q', '-t', 'ed25519', '-N', '', '-f', str(key)])

        authorized = temp / 'authorized_keys'
        authorized.write_bytes(clientkey.with_suffix('.pub').read_bytes())
        authorized.chmod(0o600)
        known_hosts = temp / 'known_hosts'
        host_type_and_key = hostkey.with_suffix('.pub').read_text().strip().split()[:2]
        known_hosts.write_text('ssh-xtp-qualification ' + ' '.join(host_type_and_key) + '\n')
        known_hosts.chmod(0o600)
        ssh_port = free_port()
        sshd_config = temp / 'sshd_config'
        sshd_config.write_text(f'''# Ephemeral isolated fixture: never a system sshd configuration
Port {ssh_port}
ListenAddress 127.0.0.1
AddressFamily inet
HostKey {hostkey}
PidFile {temp / 'sshd.pid'}
AuthorizedKeysFile {authorized}
StrictModes no
UsePAM no
PubkeyAuthentication yes
AuthenticationMethods publickey
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password
AllowUsers {user}
PermitEmptyPasswords no
DisableForwarding yes
PermitTTY no
PermitUserRC no
PrintMotd no
LogLevel VERBOSE
Subsystem sftp internal-sftp
''')
        os.chmod(sshd_config, 0o600)
        # Some sshd installations insist on /run/sshd even for unprivileged tests;
        # report that requirement without touching system directories.
        validation = subprocess.run([paths['sshd'], '-t', '-f', str(sshd_config)],
                                    capture_output=True, text=True)
        if validation.returncode != 0:
            print('NOT_RUN real OpenSSH-over-XTP: temporary sshd preflight failed:\n' +
                  validation.stderr.strip(), flush=True)
            return 77
        sshd_log = (temp/'sshd.log').open('wb')
        daemon = subprocess.Popen([paths['sshd'], '-D', '-e', '-f', str(sshd_config)],
                                  stdout=sshd_log, stderr=subprocess.STDOUT)
        try:
            try:
                wait_sshd(daemon, ssh_port)
            except AssertionError:
                sshd_log.flush()
                print((temp/'sshd.log').read_text(errors='replace')[-3500:], file=sys.stderr)
                raise
            psk = temp / 'shared.hex'
            psk.write_text(secrets.token_hex(32) + '\n')
            psk.chmod(0o600)
            policy = temp / 'state'
            policy.write_text('OPEN\n')
            policy.chmod(0o600)
            service_registry = temp / 'services.tsv'
            service_registry.write_text('ssh.management\tMANAGEMENT.CRITICAL\tgateway_rx\tssh.management\t1\tSSH gateway\n')
            service_registry.chmod(0o600)
            operational_registry = temp / 'operational.tsv'
            operational_registry.write_text('MANAGEMENT.CRITICAL\tallow\tallow\tallow\tallow\n')
            operational_registry.chmod(0o600)

            def session(subcommand, *, expect_hostkey_fail=False, label=''):
                work = temp / ('xtp_case_%02d' % session.count)
                session.count += 1
                work.mkdir(mode=0o700)
                rx_gw, rx_client = free_port(socket.SOCK_DGRAM), free_port(socket.SOCK_DGRAM)
                while rx_client == rx_gw:
                    rx_client = free_port(socket.SOCK_DGRAM)
                routes = work / 'routes.tsv'
                routes.write_text(
                    f'gateway_rx\t4\tudp\t127.0.0.1:{rx_gw}\t\t100\t1\t\t0\n'
                    f'client_rx\t4\tudp\t127.0.0.1:{rx_client}\t\t100\t1\t\t0\n')
                env = os.environ | {'XTP_ROUTE_FILE': str(routes),
                                    'XTP_HEALTH_FILE': str(work/'health.tsv')}
                client_args = [str(BRIDGE), 'client', '--rx-peer', 'client_rx',
                               '--tx-peer', 'gateway_rx', '--key-file', str(psk),
                               '--client-id', 'qualification', '--idle-seconds', '60']
                proxy = ' '.join(shlex.quote(v) for v in client_args)
                config = work / 'ssh_config'
                config.write_text(f'''Host ssh-xtp-qualification
    HostName ssh-xtp-qualification
    User {user}
    Port {ssh_port}
    IdentityFile {clientkey}
    IdentitiesOnly yes
    PreferredAuthentications publickey
    PasswordAuthentication no
    KbdInteractiveAuthentication no
    BatchMode yes
    ProxyCommand {proxy}
    HostKeyAlias ssh-xtp-qualification
    CheckHostIP no
    StrictHostKeyChecking yes
    UserKnownHostsFile {known_hosts if not expect_hostkey_fail else work/'untrusted_known_hosts'}
    GlobalKnownHostsFile /dev/null
    ControlMaster no
    ConnectTimeout 15
    ServerAliveInterval 15
    RequestTTY no
    LogLevel ERROR
''')
                if expect_hostkey_fail:
                    # Use a second valid, different host key (never a malformed pin).
                    other = work / 'other_host_ed25519'
                    run([paths['ssh-keygen'], '-q', '-t', 'ed25519', '-N', '', '-f', str(other)])
                    other_parts = other.with_suffix('.pub').read_text().split()[:2]
                    work.joinpath('untrusted_known_hosts').write_text(
                        'ssh-xtp-qualification ' + ' '.join(other_parts) + '\n')
                gateway_args = [str(BRIDGE), 'gateway', '--rx-peer', 'gateway_rx',
                                '--tx-peer', 'client_rx', '--key-file', str(psk),
                                '--client-id', 'qualification', '--policy-file', str(policy),
                                '--ssh-port', str(ssh_port), '--idle-seconds', '60',
                                '--allow-user-owned-policy-for-test', 'yes',
                                '--service-registry', str(service_registry),
                                '--operational-registry', str(operational_registry),
                                '--allow-user-owned-registry-for-test', 'yes']
                gateway_log = (work/'gateway.log').open('wb')
                gateway = subprocess.Popen(gateway_args, env=env, stdout=subprocess.DEVNULL,
                                           stderr=gateway_log)
                try:
                    time.sleep(.3)
                    cmd = [arg.replace('{CONFIG}', str(config)) for arg in subcommand]
                    proc = subprocess.run(cmd, capture_output=True, timeout=45, env=env)
                    if expect_hostkey_fail:
                        assert proc.returncode != 0, 'host key mismatch was incorrectly accepted'
                        assert b'Host key verification failed' in proc.stderr or \
                            b'REMOTE HOST IDENTIFICATION HAS CHANGED' in proc.stderr, proc.stderr
                    elif proc.returncode != 0:
                        gateway_log.flush()
                        raise AssertionError(f'{label} rc={proc.returncode}\n'
                                             f'stdout={proc.stdout!r}\n'
                                             f'stderr={proc.stderr.decode(errors="replace")[-4000:]}\n'
                                             f'gateway={(work/"gateway.log").read_text(errors="replace")[-4000:]}')
                    return proc
                finally:
                    stop(gateway)
                    gateway_log.close()
            session.count = 1

            out = session([paths['ssh'], '-F', '{CONFIG}', 'ssh-xtp-qualification',
                           'printf SSH_XTP_REAL_OPENSSH_OK'], label='SSH command')
            assert out.stdout == b'SSH_XTP_REAL_OPENSSH_OK', out.stdout
            print('PASS actual OpenSSH key-authenticated command over XTP', flush=True)

            # SCP defaults to the SFTP protocol with current OpenSSH; test upload
            # and download separately because candidate-1 supports one session.
            payload = bytes(range(256)) * 32 + secrets.token_bytes(17)
            local = temp / 'upload.bin'
            local.write_bytes(payload)
            remote = temp / 'remote_copy.bin'
            downloaded = temp / 'scp_download.bin'
            session([paths['scp'], '-F', '{CONFIG}', str(local),
                     f'ssh-xtp-qualification:{remote}'], label='SCP upload')
            assert remote.read_bytes() == payload, 'SCP upload content mismatch'
            session([paths['scp'], '-F', '{CONFIG}',
                     f'ssh-xtp-qualification:{remote}', str(downloaded)],
                    label='SCP download')
            assert downloaded.read_bytes() == payload, 'SCP download content mismatch'
            print('PASS real SCP upload/download binary round trip', flush=True)

            downloaded_sftp = temp / 'sftp_download.bin'
            batch = temp / 'sftp.batch'
            batch.write_text(f'get {remote} {downloaded_sftp}\n')
            session([paths['sftp'], '-F', '{CONFIG}', '-b', str(batch),
                     'ssh-xtp-qualification'], label='SFTP get')
            assert downloaded_sftp.read_bytes() == payload, 'SFTP content mismatch'
            print('PASS real SFTP binary round trip', flush=True)

            session([paths['ssh'], '-F', '{CONFIG}', 'ssh-xtp-qualification',
                     'printf SHOULD_NOT_RUN'], expect_hostkey_fail=True,
                    label='SSH host-key rejection')
            print('PASS strict OpenSSH host-key mismatch rejection', flush=True)
            print('PASS OpenSSH-over-XTP local qualification; system sshd/firewall unchanged', flush=True)
            return 0
        finally:
            stop(daemon)
            sshd_log.close()


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (AssertionError, OSError, subprocess.TimeoutExpired) as exc:
        print(f'FAIL real OpenSSH-over-XTP: {exc}', file=sys.stderr)
        sys.exit(1)
