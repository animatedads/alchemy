import json
import pathlib
import re
import unittest

ROOT=pathlib.Path(__file__).resolve().parents[1]
PACK=ROOT/'packs'/'single-time-service'
class SphereContract(unittest.TestCase):
    def test_all_articles_and_sources(self):
        manifest=json.loads((PACK/'00-sphere.json').read_text())
        self.assertEqual(manifest['kind'], 'sphere')
        self.assertEqual(manifest['id'], 'single-time-service')
        sections={v['id'] for v in manifest['sections']}
        articles=list((PACK/'articles').glob('*.json'))
        self.assertEqual(len(articles),12)
        ids=set()
        for path in articles:
            item=json.loads(path.read_text())
            self.assertEqual(item['kind'],'article')
            self.assertEqual(item['sphere'],'single-time-service')
            self.assertIn(item['section'],sections)
            self.assertNotIn(item['id'],ids)
            ids.add(item['id'])
            self.assertTrue(item['provenance'])
            for p in item['provenance']:
                self.assertIn(p['artifact'], ('single_time_service_v0.9.zip','single_time_service_v0.10.zip'))
                self.assertRegex(p['sha256'],r'^[0-9a-f]{64}$')
                self.assertIn(p['artifact'].replace('.zip','/') ,p['member'])
        self.assertTrue(set(manifest['start_here']).issubset(ids))

    def test_pack_links(self):
        profile=json.loads((ROOT/'profiles'/'single-time-service.json').read_text())
        self.assertIn('packs/single-time-service',profile['packs'])
        policy=json.loads((PACK/'01-access-policy.json').read_text())
        self.assertEqual(policy['id'],'single-time-service-access')
        corpus=json.loads((PACK/'corpora'/'single-time-service.continuity.json').read_text())
        self.assertEqual(corpus['kind'],'corpus')
        self.assertGreaterEqual(len(corpus['records']),8)

    def test_claims_and_provenance(self):
        text=(ROOT/'README.md').read_text().lower()
        self.assertIn('not qualified',text)
        self.assertIn('issue',text)
        for f in [ROOT/'README.md',ROOT/'CHANGELOG.md']:
            self.assertTrue(f.is_file())

if __name__=='__main__': unittest.main()
