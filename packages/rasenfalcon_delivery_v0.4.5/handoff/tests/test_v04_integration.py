import json, hashlib, pathlib, unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class NewRequirements(unittest.TestCase):
    def test_private_instances(self):
        c=json.loads((ROOT/'contracts/PRIVATE_HTTPS_POLICY.json').read_text())
        self.assertEqual(set(c['instances']),{'noc.rasenfalcon.com','office.rasenfalcon.com'})
        self.assertEqual(len({v['service'] for v in c['instances'].values()}),2)
        for s in c['instances'].values():
            self.assertTrue(s['dedicated_process'])
            self.assertEqual('required',s['mTLS_client_cert'])
            self.assertEqual('owner_private_CA',s['issuer'])
    def test_no_client_certificate_is_denied(self):
        c=json.loads((ROOT/'contracts/PRIVATE_HTTPS_POLICY.json').read_text())
        self.assertIn('missing_client_cert',c['tls_reject'])
        self.assertIn('public_CA',c['fallback_forbidden'])
        self.assertIn('HTTP_plaintext',c['fallback_forbidden'])
    def test_public_is_not_privately_gated(self):
        c=json.loads((ROOT/'contracts/PRIVATE_HTTPS_POLICY.json').read_text())
        self.assertTrue(c['public_site']['public_TLS_allowed'])
        self.assertTrue(c['public_site']['NOC_Office_mTLS_not_applied_to_public_site'])
    def test_bashqueues_not_crond(self):
        c=json.loads((ROOT/'contracts/PRIVATE_HTTPS_POLICY.json').read_text())
        self.assertEqual(c['scheduling']['schedule_authority'],'bashqueues_cron_bridge')
        self.assertFalse(c['scheduling']['system_crond_dependency'])
    def test_exact_website_source_lock(self):
        manifest=json.loads((ROOT/'public_site/github_source.lock.json').read_text())
        original=json.loads((ROOT/'public_site/builder.lock.json').read_text())
        website=ROOT.parent/'website'
        self.assertEqual(manifest['source_archive_sha256'],original['sha256'])
        self.assertEqual(manifest['published_source'],'website/')
        self.assertTrue(manifest['source_archive_is_not_embedded'])
        files=manifest['files_sha256']
        self.assertGreaterEqual(len(files),20)
        for relative,expected in files.items():
            f=website/relative
            self.assertTrue(f.is_file(),str(f))
            self.assertEqual(hashlib.sha256(f.read_bytes()).hexdigest(),expected,relative)
        pages=list((website/'content/pages').glob('*.json'))
        self.assertEqual(len(pages),original['pages'])
        self.assertTrue((website/'server/serve.rex').is_file())
        self.assertTrue((website/'tests/test_site.py').is_file())
    def test_host_contracts(self):
        hosts=json.loads((ROOT/'deployment/HOSTS.json').read_text())
        self.assertEqual(hosts['private_https_contract'],'contracts/PRIVATE_HTTPS_POLICY.json')
        self.assertEqual(hosts['public_source_contract'],'public_site/builder.lock.json')
    def test_no_unsupported_operational_claim(self):
        m=json.loads((ROOT/'public_site/builder.lock.json').read_text())
        self.assertEqual(m['native_public_https_live'],'NOT_RUN')
        self.assertEqual(m['CMS_Brand_Wire_runtime'],'NOT_QUALIFIED')
