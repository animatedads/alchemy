import sys
import unittest
from pathlib import Path
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'src'))
from spectral_integrity import (windowed_bucket_views,rfft_views,oracle_template_projection,control_examples,blind_control_codes,bounded_quiet_gain)

class WindowedAndOracle(unittest.TestCase):
    def setUp(self):
        self.fs=8000
        self.t=np.arange(16384)/self.fs
        env1=(0.35+0.65*np.sin(2*np.pi*3*self.t)**2)
        env2=(0.4+0.6*np.sin(2*np.pi*5*self.t +.3)**2)
        self.a=np.column_stack([env1*(np.sin(2*np.pi*235*self.t)+.6*np.sin(2*np.pi*445*self.t)),env1*(np.sin(2*np.pi*235*self.t+.2)+.6*np.sin(2*np.pi*445*self.t+.7))])
        self.b=np.column_stack([env2*(np.sin(2*np.pi*315*self.t+.5)+.8*np.sin(2*np.pi*535*self.t)),env2*(np.sin(2*np.pi*315*self.t+.7)+.8*np.sin(2*np.pi*535*self.t+.4))])

    def test_stft_local_complementarity(self):
        x=self.a+self.b
        odd,even=windowed_bucket_views(x,self.fs,100,3000,25,1024,256)
        self.assertEqual(odd.shape,x.shape)
        self.assertEqual(even.shape,x.shape)
        self.assertTrue(np.isfinite(odd).all())
        self.assertGreater(np.max(np.abs(odd[:,0]-odd[:,1])),.01)
        # Exact Nyquist ceiling covers all bins; WOLA is identity in sum.
        a,b=windowed_bucket_views(x,self.fs,100,4000,25,1024,256)
        self.assertLess(np.max(np.abs(a+b-x)),2e-12)

    def test_stft_different_from_global_fft(self):
        x=np.zeros((8192,2));x[510,0]=1;x[510,1]=.7
        local,_=windowed_bucket_views(x,self.fs,100,3000,0,1024,256)
        global_,_=rfft_views(x,self.fs,100,3000,0)
        self.assertGreater(np.max(np.abs(local-global_)),.001)
        # The impulse's distant samples cannot be influenced by local windows.
        self.assertLess(np.max(np.abs(local[6000:])),1e-12)

    def test_reference_oracle_known_mixtures(self):
        controls=control_examples(self.a,self.b,self.fs,100,3000,0)
        weave=oracle_template_projection(controls['engineered_weave'],self.a,self.b,self.fs,100,3000)
        natural=oracle_template_projection(controls['ordinary_overlay'],self.a,self.b,self.fs,100,3000)
        for row in weave:
            self.assertLess(row['relative_fit_residual'],1e-10)
            self.assertEqual(row['design_rank'],2)
            if row['bucket']=='even':
                self.assertAlmostEqual(row['source_a_coefficient'],1,places=9)
                self.assertAlmostEqual(row['source_b_coefficient'],0,places=9)
            else:
                self.assertAlmostEqual(row['source_a_coefficient'],0,places=9)
                self.assertAlmostEqual(row['source_b_coefficient'],1,places=9)
        for row in natural:
            self.assertAlmostEqual(row['source_a_coefficient'],1,places=9)
            self.assertAlmostEqual(row['source_b_coefficient'],1,places=9)
        only=oracle_template_projection(controls['notched_single_a'],self.a,self.b,self.fs,100,3000)
        self.assertTrue(all(abs(row['source_b_coefficient'])<1e-10 for row in only))

    def test_oracle_rejects_bad_shapes(self):
        with self.assertRaises(ValueError):
            oracle_template_projection(self.a,self.b[:100],self.b,self.fs,100,3000)
        with self.assertRaises(ValueError):
            windowed_bucket_views(self.a,self.fs,100,3000,0,101,40)

    def test_blinded_codes_repeatable(self):
        names=['single_a','notched_single_a','ordinary_overlay','engineered_weave']
        a=blind_control_codes(names,731)
        b=blind_control_codes(names,731)
        self.assertEqual(a,b)
        self.assertEqual(set(a.values()),set(names))
        self.assertEqual(len(set(a)),4)
        with self.assertRaises(ValueError):
            blind_control_codes(['a','a'])

    def test_mono_quiet_gain_stays_mono(self):
        mono=self.a[:,0]
        y,_=bounded_quiet_gain(mono,self.fs)
        self.assertEqual(y.shape,mono.shape)
        self.assertTrue(np.isfinite(y).all())

if __name__=='__main__': unittest.main()
