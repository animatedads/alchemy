#!/usr/bin/env python3
"""Synthetic-only privacy regression for the existing reference implementation.

No source video, image, frame, private measurements, or derived data are used.
This test never calls decode_video or any image reconstruction method.
"""
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

PROVIDER = Path(__file__).resolve().parents[1] / "providers" / "reference_video_reconstruction.py"
spec = importlib.util.spec_from_file_location("alchemy_reference_video_synthetic_privacy", PROVIDER)
provider = importlib.util.module_from_spec(spec)
spec.loader.exec_module(provider)


class PrivateVideoAdmission(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="alchemy-video-synthetic-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name) / "private"
        self.root.mkdir()
        self.job = self.root / "job.json"
        self.result = self.root / "result.json"
        self.out = self.root / "output"
        self.out.mkdir()
        self.source = self.root / "synthetic-source-dummy.dat"
        self.source.write_bytes(b"SYNTHETIC_NOT_VIDEO")
        self.valid = {
            "schema": provider.SCHEMA_JOB,
            "methodology_id": "VIDEO.RECON.FLOW_WARP_ACCUMULATE",
            "source": {"kind": "VIDEO_FILE", "path": str(self.source)},
            "output_dir": str(self.out),
            "candidate_id": "synthetic_ok_01",
        }

    def admit(self, job=None, path=None):
        with patch.dict(os.environ, {"ALCHEMY_PRIVATE_MEDIA_ROOT": str(self.root)}):
            provider._require_private_material_paths(
                str(self.job), self.valid if job is None else job,
                str(self.result) if path is None else str(path)
            )

    def test_valid_wholly_synthetic_paths(self):
        self.admit()

    def test_candidate_traversal_rejected(self):
        for value in ("../../outside", "../outside", "/tmp/outside", "a/b", "a\\b", "..", ".hidden"):
            with self.subTest(value=value):
                item = {**self.valid, "candidate_id": value}
                with self.assertRaisesRegex(RuntimeError, "UNSAFE_CANDIDATE_ID"):
                    self.admit(item)

    def test_symlink_escape_rejected(self):
        link = self.root / "escape"
        try:
            link.symlink_to(Path(self.tmp.name))
        except OSError:
            self.skipTest("symlink unavailable")
        with self.assertRaisesRegex(RuntimeError, "PRIVATE_MATERIAL_OUTSIDE_ROOT"):
            self.admit({**self.valid, "output_dir": str(link)})

    def test_git_worktree_rejected(self):
        (self.root / ".git").mkdir()
        with self.assertRaisesRegex(RuntimeError, "GIT_WORKTREE_MEDIA_FORBIDDEN"):
            self.admit()

    def test_outside_result_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "PRIVATE_MATERIAL_OUTSIDE_ROOT"):
            self.admit(path=Path(self.tmp.name) / "outside-result.json")

    def test_before_reading_job_path(self):
        with patch.dict(os.environ, {"ALCHEMY_PRIVATE_MEDIA_ROOT": str(self.root)}):
            # File not read: outside boundary is rejected even if JSON is valid.
            outside = Path(self.tmp.name) / "outside-job.json"
            outside.write_text(json.dumps(self.valid), encoding="utf-8")
            with self.assertRaisesRegex(RuntimeError, "PRIVATE_MATERIAL_OUTSIDE_ROOT"):
                provider.run_job_file(str(outside), str(self.result),
                                      "VIDEO.RECON.FLOW_WARP_ACCUMULATE")
            self.assertFalse(self.result.exists())

    def test_filename_safe(self):
        self.assertEqual(provider.safe_candidate_stem(self.valid), "synthetic_ok_01")


if __name__ == "__main__":
    unittest.main()
