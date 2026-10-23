#!/usr/bin/env python3
"""Hardware-free native playout regression for dev3.

Covers file-backed 720p/24fps output, reject missing or corrupted assets before
queue admission, WAIT/RELEASE and a mid-scene HOLD without consuming content.
"""
import ctypes
import json
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FB = 1280*720*3//2
AB = 2000*4


def api():
    a = ctypes.CDLL(str(ROOT/'native/libservice_playout.so'))
    a.svc_open.argtypes = [ctypes.c_char_p,ctypes.c_char_p,ctypes.c_int]
    a.svc_set_idle.argtypes = [ctypes.c_char_p]
    a.svc_enqueue_clip.argtypes = [ctypes.c_char_p,ctypes.c_char_p,ctypes.c_int]
    a.svc_enqueue_card.argtypes = [ctypes.c_char_p,ctypes.c_char_p,ctypes.c_int]
    a.svc_run_frames.argtypes = [ctypes.c_int]
    a.svc_set_hold.argtypes = [ctypes.c_int]
    a.svc_stats.restype = ctypes.c_char_p
    for name in ('svc_reset','svc_open','svc_set_idle','svc_enqueue_clip','svc_enqueue_card','svc_run_frames','svc_set_hold','svc_start','svc_stop'):
        getattr(a,name).restype = ctypes.c_int
    return a


def b(path):
    return str(path).encode()


class NativeHoldTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='service-dev3-')
        self.d = Path(self.tmp.name)
        self.a = api()
        self.vout = self.d/'out.yuv'
        self.aout = self.d/'out.s16le'
        self.assertEqual(self.a.svc_open(b('file:'+str(self.vout)),b('file:'+str(self.aout)),0),1)
        self.idle = self.d/'idle.yuv'
        self.idle.write_bytes(bytes([63])*FB)
        self.assertEqual(self.a.svc_set_idle(b(self.idle)),1)
        self.clip = self.d/'clip.yuv'
        self.pcm = self.d/'clip.s16le'
        self.clip.write_bytes(bytes([125])*FB*4)
        self.pcm.write_bytes(bytes([1])*AB*4)

    def tearDown(self):
        self.a.svc_stop()
        self.a.svc_reset()
        self.tmp.cleanup()

    def stats(self):
        return json.loads(self.a.svc_stats().decode())

    def test_preflight(self):
        self.assertEqual(self.a.svc_enqueue_clip(b(self.d/'missing.yuv'),b(self.pcm),4),0)
        self.assertEqual(self.a.svc_enqueue_clip(b(self.clip),b(self.pcm),3),0)
        self.assertEqual(self.a.svc_enqueue_clip(b(self.clip),b(self.d/'missing.s16le'),4),0)
        self.assertEqual(self.a.svc_enqueue_card(b(self.idle),b(self.pcm),4),1)
        self.assertEqual(self.a.svc_enqueue_clip(b(self.clip),b(self.pcm),4),1)
        self.assertEqual(self.stats()['queued'],2)

    def test_hold_preserves_sequence(self):
        self.assertEqual(self.a.svc_enqueue_clip(b(self.clip),b(self.pcm),4),1)
        self.assertEqual(self.a.svc_set_hold(1),1)
        self.assertEqual(self.a.svc_start(),1)
        time.sleep(0.19)
        s = self.stats()
        self.assertEqual(s['held'],1)
        self.assertGreaterEqual(s['held_frames'],3)
        self.assertEqual(s['finished'],0)
        self.assertEqual(s['queued'],1)
        self.assertEqual(self.a.svc_set_hold(0),1)
        time.sleep(0.24)
        self.assertEqual(self.a.svc_stop(),1)
        s = self.stats()
        self.assertEqual(s['held'],0)
        self.assertEqual(s['error'],0)
        self.assertEqual(s['finished'],1)
        self.assertEqual(s['queued'],0)
        frames = self.vout.read_bytes()
        audio = self.aout.read_bytes()
        self.assertEqual(len(frames)%FB,0)
        self.assertEqual(len(audio)%AB,0)
        self.assertEqual(len(frames)//FB,len(audio)//AB)
        self.assertEqual(frames.count(125),4*FB)
        self.assertEqual(audio.count(1),4*AB)

    def test_second_preflight_on_dequeued_file(self):
        self.assertEqual(self.a.svc_enqueue_clip(b(self.clip),b(self.pcm),4),1)
        self.clip.unlink()
        self.assertEqual(self.a.svc_run_frames(1),0)
        s=self.stats()
        self.assertEqual(s['error'],1)
        self.assertIn('queued media absent or changed',s['why'])

    def test_mid_scene_hold_and_resume(self):
        self.assertEqual(self.a.svc_enqueue_clip(b(self.clip),b(self.pcm),4),1)
        self.assertEqual(self.a.svc_start(),1)
        time.sleep(0.095)
        self.assertEqual(self.a.svc_set_hold(1),1)
        prior = self.stats()
        time.sleep(0.15)
        paused = self.stats()
        self.assertEqual(paused['held'],1)
        self.assertEqual(paused['finished'],prior['finished'])
        self.assertGreater(paused['held_frames'],0)
        self.assertEqual(self.a.svc_set_hold(0),1)
        time.sleep(0.23)
        self.assertEqual(self.a.svc_stop(),1)
        self.assertEqual(self.stats()['finished'],1)
        self.assertEqual(self.vout.read_bytes().count(125),4*FB)


if __name__=='__main__':
    unittest.main(verbosity=2)
