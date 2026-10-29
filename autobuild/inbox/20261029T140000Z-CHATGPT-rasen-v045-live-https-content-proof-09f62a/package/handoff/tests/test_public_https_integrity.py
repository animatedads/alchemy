"""Live localhost TLS fixture: content probe, no remote production contact."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import ssl
import subprocess
import tempfile
import threading
import unittest
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler

ROOT=Path(__file__).resolve().parents[2]
FILE=ROOT/'website/deploy/public_https_integrity_probe.py'
spec=importlib.util.spec_from_file_location('rf_probe',FILE)
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class Silence(SimpleHTTPRequestHandler):
    def log_message(self,*_): pass
    def translate_path(self,path):
        return str(self.server.site_dir.joinpath(path.lstrip('/'))) if path!='/' else str(self.server.site_dir/'index.html')

class IntegrityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp=tempfile.TemporaryDirectory(prefix='rf-tls-test-')
        cls.base=Path(cls.temp.name);cls.cert=cls.base/'server.pem';cls.key=cls.base/'key.pem'
        cmd=['openssl','req','-x509','-newkey','rsa:2048','-nodes','-days','1',
            '-keyout',str(cls.key),'-out',str(cls.cert),'-subj','/CN=localhost',
            '-addext','subjectAltName=DNS:localhost']
        p=subprocess.run(cmd,capture_output=True,text=True)
        if p.returncode: raise RuntimeError('openssl ephemeral test cert failed: '+p.stderr)
        cls.root=ROOT/'website/site'
        cls.srv=ThreadingHTTPServer(('127.0.0.1',0),Silence)
        cls.srv.site_dir=cls.root
        ctx=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        ctx.load_cert_chain(cls.cert,cls.key)
        cls.srv.socket=ctx.wrap_socket(cls.srv.socket,server_side=True)
        cls.thread=threading.Thread(target=cls.srv.serve_forever,daemon=True)
        cls.thread.start()
    @classmethod
    def tearDownClass(cls):
        cls.srv.shutdown();cls.srv.server_close();cls.thread.join(timeout=2);cls.temp.cleanup()
    def test_probed_all_pages_and_assets_with_tls(self):
        r=m.probe('localhost',self.srv.server_port,self.root,self.cert,timeout=2)
        self.assertEqual(r['checks_passed'],13)
        self.assertTrue(r['tls_server_verified'])
        self.assertEqual(r['cms_release_authorized'],'NOT_TESTED')
    def test_missing_ca_fails_no_fallback(self):
        with self.assertRaises(m.ProbeError):
            m.probe('localhost',self.srv.server_port,self.root,timeout=2)
    def test_wrong_host_fails_tls(self):
        with self.assertRaises(m.ProbeError):
            m.probe('127.0.0.1',self.srv.server_port,self.root,self.cert,timeout=2)
    def test_wrong_fingerprint_fails(self):
        with self.assertRaisesRegex(m.ProbeError,'fingerprint'):
            m.probe('localhost',self.srv.server_port,self.root,self.cert,'0'*64,timeout=2)
    def test_tampered_content_refused_before_network(self):
        with tempfile.TemporaryDirectory(prefix='rf-digest-') as td:
            out=Path(td)
            shutil.copytree(self.root,out/'site')
            (out/'site/index.html').write_text('forged',encoding='utf-8')
            with self.assertRaisesRegex(m.ProbeError,'digest mismatch'):
                m.probe('localhost',self.srv.server_port,out/'site',self.cert,timeout=2)
    def test_traversal_manifest_rejected(self):
        with tempfile.TemporaryDirectory(prefix='rf-path-') as td:
            out=Path(td);shutil.copytree(self.root,out/'site')
            manifest=json.loads((out/'site/build-manifest.json').read_text())
            manifest['pages'][0]['file']='../secret.html'
            (out/'site/build-manifest.json').write_text(json.dumps(manifest))
            with self.assertRaises(m.ProbeError):m.inventory(out/'site')
    def test_remote_content_drift_refused(self):
        with tempfile.TemporaryDirectory(prefix='rf-remote-') as td:
            source=Path(td)/'site'
            shutil.copytree(self.root,source)
            (source/'index.html').write_text('not the source build')
            old=self.srv.site_dir
            self.srv.site_dir=source
            try:
                with self.assertRaisesRegex(m.ProbeError,'content SHA-256 mismatch'):
                    m.probe('localhost',self.srv.server_port,self.root,self.cert,timeout=2)
            finally:
                self.srv.site_dir=old
    def test_cli_refuses_nonpublic_host(self):
        p=subprocess.run(['python3',str(FILE),'--site-root',str(self.root),'--host','localhost'],capture_output=True,text=True)
        self.assertEqual(p.returncode,2)
        self.assertIn('only the declared public',p.stderr)
    def test_redirect_is_not_success(self):
        class Redirect(Silence):
            def do_GET(self):
                self.send_response(302);self.send_header('Location','https://elsewhere.example/');self.end_headers()
        srv=ThreadingHTTPServer(('127.0.0.1',0),Redirect);srv.site_dir=self.root
        ctx=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);ctx.load_cert_chain(self.cert,self.key)
        srv.socket=ctx.wrap_socket(srv.socket,server_side=True)
        t=threading.Thread(target=srv.serve_forever,daemon=True);t.start()
        try:
            with self.assertRaisesRegex(m.ProbeError,'redirects prohibited'):
                m.probe('localhost',srv.server_port,self.root,self.cert,timeout=2)
        finally:
            srv.shutdown();srv.server_close();t.join(timeout=2)
if __name__=='__main__':unittest.main()
