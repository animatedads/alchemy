"""Regression checks for the Windows semantic renderer lifecycle.

Run: python -m unittest discover -s tests -p 'test_wire_windows_lifecycle.py'
These tests inspect source and do not constitute a Win64 runtime qualification.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
RENDERER = ROOT / "src" / "wire_windows_renderer.cpp"
BOOTSTRAP = ROOT / "rexx" / "WireWindowsBootstrap.rex"


class WireWindowsLifecycle(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.renderer = RENDERER.read_text(encoding="utf-8")
        cls.bootstrap = BOOTSTRAP.read_text(encoding="utf-8")

    def test_f5_intercepted_at_thread_message_loop(self):
        self.assertIn("msg.message==WM_KEYDOWN&&msg.wParam==VK_F5", self.renderer)

    def test_reprojection_does_not_post_quit(self):
        self.assertIn("reprojecting", self.renderer)
        self.assertIn("if(!p||!p->reprojecting)PostQuitMessage(0)", self.renderer)

    def test_rexx_uses_real_line_delimiters(self):
        self.assertIn('x2c("0A")', self.bootstrap)

    def test_reply_newlines_are_normalized(self):
        self.assertIn('changestr(x2c("0D"), replyText', self.bootstrap)
        self.assertIn('changestr(x2c("0A"), replyText', self.bootstrap)


if __name__ == "__main__":
    unittest.main()
