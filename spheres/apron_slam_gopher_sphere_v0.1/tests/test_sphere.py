"""Static Gopher pack checks: never load private video, fonts or plate data."""
from pathlib import Path
import json
import unittest

ROOT=Path(__file__).resolve().parents[1]
PACK=ROOT/'packs'/'apron-slam'
class SphereContract(unittest.TestCase):
    def load(self,p):
        return json.loads(p.read_text(encoding='utf-8'))
    def test_profile_references_pack(self):
        p=self.load(ROOT/'profiles/apron-slam.json')
        self.assertIn('packs/apron-slam',p['packs'])
    def test_article_ids_resolve(self):
        sphere=self.load(PACK/'00-sphere.json')
        ids={self.load(p)['id'] for p in (PACK/'articles').glob('*.json')}
        self.assertEqual(set(sphere['start_here']),ids)
        self.assertEqual(sphere['access_policy'],self.load(PACK/'01-access-policy.json')['id'])
    def test_articles_are_same_sphere(self):
        for path in (PACK/'articles').glob('*.json'):
            self.assertEqual(self.load(path)['sphere'],'apron-slam')
    def test_policy_read_only(self):
        policies=self.load(PACK/'01-access-policy.json')['rules']
        for rule in policies:
            self.assertEqual(rule['actions'],['read'])
    def test_no_media_assets(self):
        names=[p.name.lower() for p in ROOT.rglob('*') if p.is_file()]
        self.assertFalse(any(n.endswith(('.mp4','.mov','.mkv','.jpg','.jpeg','.png','.ttf','.woff')) for n in names))
    def test_documentation_package(self):
        m=self.load(ROOT/'integration.json')
        self.assertEqual(m['package']['kind'],'documentation')
if __name__=='__main__':unittest.main()
