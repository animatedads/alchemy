import json
import tempfile
import unittest
import sys
from pathlib import Path
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'src'))
from blind_trial import create_trial

class Trial(unittest.TestCase):
    def setUp(self):
        self.fs=8000
        t=np.arange(8000)/self.fs
        self.a=np.column_stack([np.sin(2*np.pi*231*t),np.sin(2*np.pi*421*t)])
        self.b=np.column_stack([np.sin(2*np.pi*323*t),np.sin(2*np.pi*513*t)])
    def test_blinded_export_and_key_is_private(self):
        with tempfile.TemporaryDirectory() as d:
            x=create_trial(self.a,self.b,self.fs,d,ceiling_hz=3000)
            self.assertEqual(len(x['codes']),4)
            self.assertFalse('condition' in json.dumps(x))
            y=json.loads((Path(d)/'PRIVATE_KEY.json').read_text())
            self.assertEqual(set(z['condition'] for z in y['rows']),{'single_a','notched_single_a','ordinary_overlay','engineered_weave'})
            self.assertEqual(len(list(Path(d).glob('T*.flac'))),4)
            self.assertEqual((Path(d)/'RESPONSES_TEMPLATE.csv').read_text().splitlines()[0].split(',')[0],'listener_code')
            self.assertEqual((Path(d)/'PRIVATE_KEY.json').stat().st_mode&0o777,0o600)
    def test_no_overwrite_of_unblinding_key(self):
        with tempfile.TemporaryDirectory() as d:
            create_trial(self.a,self.b,self.fs,d,ceiling_hz=3000)
            with self.assertRaises(FileExistsError):create_trial(self.a,self.b,self.fs,d,ceiling_hz=3000)
    def test_zero_and_bad_rms_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaises(ValueError):create_trial(self.a,self.b,self.fs,d,reference_rms=0)
            with self.assertRaises(ValueError):create_trial(self.a,np.zeros_like(self.b),self.fs,d,ceiling_hz=3000)
if __name__=='__main__': unittest.main()
