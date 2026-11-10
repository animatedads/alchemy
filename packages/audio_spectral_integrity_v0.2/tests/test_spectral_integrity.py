import unittest
import sys
from pathlib import Path
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'src'))
from spectral_integrity import (
    rfft_views, preference, safe_peak_scale, rms_envelope,
    bounded_quiet_gain, sweep_bands, harmonic_observations)


class SpectralIntegrityTest(unittest.TestCase):
    def setUp(self):
        self.rate = 8000
        self.t = np.arange(16000) / self.rate
        self.stereo = np.column_stack([
            np.sin(2*np.pi*250*self.t) + 0.5*np.sin(2*np.pi*350*self.t),
            np.sin(2*np.pi*250*self.t + 0.7) + 0.5*np.sin(2*np.pi*350*self.t + 0.5)])

    def test_bucket_assignment_and_recombination(self):
        odd, even = rfft_views(self.stereo, self.rate, 100, 1000)
        self.assertLess(np.max(np.abs((odd+even) - self.stereo)), 1e-10)
        # 250 Hz is even zero-indexed bucket; 350 Hz odd.
        self.assertGreater(np.sqrt(np.mean(even**2)), np.sqrt(np.mean(odd**2)))
        self.assertGreater(np.sqrt(np.mean(even**2)), 0.6)
        self.assertGreater(np.sqrt(np.mean(odd**2)), 0.3)
        self.assertGreater(np.max(np.abs(even[:, 0]-even[:, 1])), 0.1)

    def test_preference_does_not_clip_or_invent_components(self):
        odd, even = rfft_views(self.stereo, self.rate, 100, 1000)
        o, scale_o = preference(odd, even, 'odd', 24)
        e, scale_e = preference(odd, even, 'even', 24)
        self.assertLessEqual(np.max(np.abs(o)), 10**(-3/20)+1e-10)
        self.assertLessEqual(np.max(np.abs(e)), 10**(-3/20)+1e-10)
        self.assertFalse(np.allclose(o, e))
        self.assertGreater(scale_o, 0)
        self.assertGreater(scale_e, 0)

    def test_envelope_sweep_quiet_pass(self):
        rows = list(sweep_bands(self.stereo, self.rate, 200, 2000))
        self.assertEqual(len(rows), 10)
        self.assertTrue(all(row['envelope_variance'] >= 0 for row,_,_ in rows))
        quiet, sc = bounded_quiet_gain(self.stereo*0.02, self.rate)
        self.assertTrue(np.isfinite(quiet).all())
        self.assertLessEqual(np.max(np.abs(quiet)), 10**(-3/20)+1e-10)

    def test_harmonic_peak_no_attribution(self):
        # One synthetic harmonic source, and one notched source: absence is possible
        # without any second speaker/recording.
        pure = np.sin(2*np.pi*200*self.t) + 0.7*np.sin(2*np.pi*400*self.t)
        no_second_harm = np.sin(2*np.pi*200*self.t)
        present = harmonic_observations(pure, self.rate, 200, 200, 800)
        missing = harmonic_observations(no_second_harm, self.rate, 200, 200, 800)
        at_400 = lambda rs: np.median([r['local_peak_to_median'] for r in rs if r['harmonic']==2])
        self.assertGreater(at_400(present), at_400(missing))
        self.assertTrue(all(set(r)=={'time_s','harmonic','expected_hz','local_peak_to_median'} for r in present))

    def test_reject_invalid(self):
        with self.assertRaises(ValueError):
            rfft_views(self.stereo, self.rate, 100, 6000)
        with self.assertRaises(ValueError):
            preference(self.stereo, self.stereo, 'other')


if __name__ == '__main__':
    unittest.main()

class PhaseSensitivityTest(unittest.TestCase):
    def setUp(self):
        self.rate = 8000
        t = np.arange(16000) / self.rate
        self.a = np.column_stack([np.sin(2*np.pi*250*t),np.sin(2*np.pi*250*t + .2)])
        self.b = np.column_stack([np.sin(2*np.pi*350*t),np.sin(2*np.pi*350*t + .4)])

    def test_phase_shift_changes_energy_but_not_origin(self):
        from spectral_integrity import bucket_phase_sweep
        mix = self.a + .35*self.b
        rows = bucket_phase_sweep(mix,self.rate,100,1000,(0,25,50,75))
        self.assertEqual(len(rows),4)
        self.assertTrue(all(abs(r['odd_power_fraction']+r['even_power_fraction']-1)<1e-10 for r in rows))
        self.assertTrue(all(r['reconstruction_max_abs_error']<1e-10 for r in rows))
        # Two boundary placements yield materially different allocations
        self.assertGreater(max(r['odd_power_fraction'] for r in rows)-min(r['odd_power_fraction'] for r in rows),.3)

    def test_known_two_source_synthesis_exact_components(self):
        from spectral_integrity import synthesize_interleaved,rfft_views
        composite = synthesize_interleaved(self.a,self.b,self.rate,100,1000,0)
        odd,even = rfft_views(composite,self.rate,100,1000,0)
        aodd,aeven = rfft_views(self.a,self.rate,100,1000,0)
        bodd,beven = rfft_views(self.b,self.rate,100,1000,0)
        self.assertLess(np.max(np.abs(even-aeven)),1e-10)
        self.assertLess(np.max(np.abs(odd-bodd)),1e-10)
        self.assertGreater(np.max(np.abs(even[:,0]-even[:,1])),.1)

    def test_phase_and_geometry_errors(self):
        from spectral_integrity import synthesize_interleaved,rfft_views,bucket_phase_sweep
        with self.assertRaises(ValueError):
            rfft_views(self.a,self.rate,100,1000,100)
        with self.assertRaises(ValueError):
            rfft_views(self.a,self.rate,100,1000,-1)
        with self.assertRaises(ValueError):
            synthesize_interleaved(self.a,self.b[:8],self.rate)
        with self.assertRaises(ValueError):
            bucket_phase_sweep(self.a,self.rate,100,1000,(0,100))
