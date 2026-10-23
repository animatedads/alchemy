import json
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
PACK=ROOT/'sphere'/'packs'/'remote-compute-mu'
class SphereTests(unittest.TestCase):
    def test_usable_sphere(self):
        sphere=json.loads((PACK/'00-sphere-remote-compute-mu.json').read_text())
        policy=json.loads((PACK/'01-access-policy-remote-compute-mu.json').read_text())
        corpus=json.loads((PACK/'20-corpus-remote-compute-mu.json').read_text())
        profile=json.loads((ROOT/'sphere'/'profiles'/'remote-compute-mu.json').read_text())
        self.assertEqual(sphere['id'],'remote-compute-mu')
        self.assertEqual(policy['id'],sphere['access_policy'])
        self.assertEqual(corpus['sphere'],sphere['id'])
        self.assertEqual(profile['id'],sphere['id'])
        self.assertIn('packs/remote-compute-mu',profile['packs'])
        self.assertEqual(len(corpus['records']),10)
        self.assertTrue(all(row['topic'] and row['rule'] and row['plane'] for row in corpus['records']))
        self.assertFalse(any('exec' in rule['actions'] for rule in policy['rules']))
if __name__=='__main__':unittest.main()
