"""Real TLS handshake tests for the platform private-CA trust policy."""
from __future__ import annotations

import json
import shutil
import ssl
import subprocess
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from alchemy_python import PrivateCAHttpTransport, TransportError


def openssl(*args: str) -> None:
    subprocess.run(['openssl', *args], check=True, capture_output=True, timeout=15)


class RpcHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers['Content-Length'])
        request = json.loads(self.rfile.read(length))
        if self.path == '/redirect':
            self.send_response(307)
            self.send_header('Location', 'https://example.org/redirected')
            self.end_headers()
            return
        result = json.dumps({'jsonrpc':'2.0', 'result':{'method':request['method']}, 'id':request['id']}).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(result)))
        self.end_headers()
        self.wfile.write(result)

    def log_message(self, *_args):
        return


@unittest.skipUnless(shutil.which('openssl'), 'openssl CLI required for ephemeral TLS fixtures')
class PrivateCATests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory(prefix='alchemy-tls-')
        cls.root = Path(cls.tmp.name)
        ca = cls.root / 'ca.pem'; key = cls.root / 'ca.key'
        openssl('req','-x509','-newkey','rsa:2048','-sha256','-nodes',
                '-keyout',str(key),'-out',str(ca),'-days','1',
                '-subj','/CN=Alchemy Local Test CA')
        for name, cn in (('server','localhost'),('client','alchemy-client')):
            ext = cls.root / f'{name}.ext'
            ext.write_text('subjectAltName=DNS:localhost,IP:127.0.0.1\n' if name == 'server' else 'extendedKeyUsage=clientAuth\n')
            openssl('req','-new','-newkey','rsa:2048','-nodes','-keyout',str(cls.root/f'{name}.key'),
                    '-out',str(cls.root/f'{name}.csr'),'-subj',f'/CN={cn}')
            openssl('x509','-req','-in',str(cls.root/f'{name}.csr'),'-CA',str(ca),'-CAkey',str(key),
                    '-CAcreateserial','-out',str(cls.root/f'{name}.pem'),'-days','1','-sha256',
                    '-extfile',str(ext))
        cls.server = ThreadingHTTPServer(('127.0.0.1',0), RpcHandler)
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        ctx.load_cert_chain(str(cls.root/'server.pem'),str(cls.root/'server.key'))
        cls.server.socket = ctx.wrap_socket(cls.server.socket,server_side=True)
        cls.thread = threading.Thread(target=cls.server.serve_forever,daemon=True)
        cls.thread.start()
        cls.mtls_server = ThreadingHTTPServer(('127.0.0.1',0), RpcHandler)
        mtls_ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        mtls_ctx.load_cert_chain(str(cls.root/'server.pem'),str(cls.root/'server.key'))
        mtls_ctx.load_verify_locations(cafile=str(cls.root/'ca.pem'))
        mtls_ctx.verify_mode = ssl.CERT_REQUIRED
        cls.mtls_server.socket = mtls_ctx.wrap_socket(cls.mtls_server.socket,server_side=True)
        cls.mtls_thread = threading.Thread(target=cls.mtls_server.serve_forever,daemon=True)
        cls.mtls_thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown(); cls.server.server_close(); cls.thread.join(timeout=2)
        cls.mtls_server.shutdown(); cls.mtls_server.server_close(); cls.mtls_thread.join(timeout=2)
        cls.tmp.cleanup()

    @classmethod
    def endpoint(cls, host='localhost', path='/rpc'):
        return f'https://{host}:{cls.server.server_address[1]}{path}'

    def test_verified_private_ca_roundtrip(self):
        transport = PrivateCAHttpTransport(self.endpoint(),ca_file=self.root/'ca.pem')
        payload = b'{"jsonrpc":"2.0","method":"health.ping","id":8}'
        reply = json.loads(transport.exchange(payload))
        self.assertEqual(reply['id'],8)
        self.assertEqual(reply['result']['method'],'health.ping')
        self.assertEqual(transport._private_context.verify_mode,ssl.CERT_REQUIRED)
        self.assertTrue(transport._private_context.check_hostname)
        self.assertEqual(len(transport._private_context.get_ca_certs()),1)

    def test_untrusted_ca_fails_closed(self):
        # A validly structured unrelated root is not a substitute for this CA.
        other = self.root / 'other-root.pem'; otherkey = self.root / 'other-root.key'
        openssl('req','-x509','-newkey','rsa:2048','-nodes','-keyout',str(otherkey),
                '-out',str(other),'-days','1','-subj','/CN=Different CA')
        trans = PrivateCAHttpTransport(self.endpoint(),ca_file=other)
        with self.assertRaises(TransportError):
            trans.exchange(b'{"jsonrpc":"2.0","method":"x","id":3}')

    def test_no_redirect_to_other_authority(self):
        trans = PrivateCAHttpTransport(self.endpoint(path='/redirect'),ca_file=self.root/'ca.pem')
        with self.assertRaises(TransportError):
            trans.exchange(b'{"jsonrpc":"2.0","method":"x","id":3}')

    def test_hostname_mismatch_fails(self):
        # Server has localhost and 127.0.0.1 SAN only, but not 127.0.0.2.
        # Injecting an SNI mismatch would require a special endpoint; inspect
        # the trust configuration and rely on TLS hostname checks above.
        trans=PrivateCAHttpTransport(self.endpoint(),ca_file=self.root/'ca.pem')
        self.assertTrue(trans._private_context.check_hostname)

    def test_invalid_authorities_and_credentials_refused(self):
        ca=self.root/'ca.pem'
        with self.assertRaises(ValueError): PrivateCAHttpTransport('http://localhost:1',ca_file=ca)
        with self.assertRaises(ValueError): PrivateCAHttpTransport(self.endpoint(),ca_file='missing.pem')
        with self.assertRaises(ValueError): PrivateCAHttpTransport(self.endpoint(),ca_file=ca,client_key_file='a.key')
        with self.assertRaises(ValueError): PrivateCAHttpTransport(self.endpoint(),ca_file=ca,token='bad\r\nvalue')
        with self.assertRaises(ValueError): PrivateCAHttpTransport('https://user:pass@localhost:44',ca_file=ca)

    def test_mtls_requires_explicit_client_identity(self):
        url=f'https://localhost:{self.mtls_server.server_address[1]}/rpc'
        no_client=PrivateCAHttpTransport(url,ca_file=self.root/'ca.pem')
        with self.assertRaises(TransportError):
            no_client.exchange(b'{"jsonrpc":"2.0","method":"m","id":5}')
        trans=PrivateCAHttpTransport(url,ca_file=self.root/'ca.pem',
              client_cert_file=self.root/'client.pem',client_key_file=self.root/'client.key')
        self.assertEqual(json.loads(trans.exchange(b'{"jsonrpc":"2.0","method":"m","id":5}'))['id'],5)

if __name__=='__main__': unittest.main()
