#!/usr/bin/env python3
"""No-network, no-journal tests for the MCP composite catalogue safety gate."""
import copy
import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from reconcile_catalog import CatalogueRefused, reconcile

SHA_R = hashlib.sha256(b"runtime source fixture").hexdigest()
SHA_S = hashlib.sha256(b"sphere source fixture").hexdigest()


def fixture():
    live = {"schema": "oorexx.mcp.component.list/1", "components": [
        {"componentId": f"service-{i:03d}", "componentKind": "runtime",
         "aliases": [f"legacy-{i:03d}"], "ownership": None, "requestCount": 0}
        for i in range(137)
    ]}
    runtime = {"schema": "oorexx.mcp.component.catalog.runtime/1",
               "sourceArtifact": "accepted-live-137-runtime-rollup.zip", "sourceSha256": SHA_R,
               "components": [
                   {"componentId": f"service-{i:03d}", "componentKind": "runtime",
                    "aliases": [f"legacy-{i:03d}"], "artifact": f"service-{i:03d}.zip"}
                   for i in range(137)]}
    spheres = {"schema": "oorexx.mcp.component.catalog.spheres/1",
               "sourceArtifact": "accepted-sphere-rollup.zip", "sourceSha256": SHA_S,
               "components": [
                   {"componentId": f"sphere:knowledge-{i:03d}",
                    "componentKind": "sphere", "sphereId": f"knowledge-{i:03d}",
                    "aliases": [f"knowledge_{i:03d}"], "sha256": hashlib.sha256(str(i).encode()).hexdigest()}
                   for i in range(53)]}
    return live, runtime, spheres


def run_reconcile(live, runtime, spheres, expected=137):
    return reconcile(live, runtime, spheres, expected, "a"*64, "b"*64, "c"*64)


class SafetyTests(unittest.TestCase):
    def test_full_137_plus_53_preserves_input(self):
        live, runtime, spheres = fixture()
        originals = copy.deepcopy((live, runtime, spheres))
        candidate, report = run_reconcile(live, runtime, spheres)
        self.assertEqual(len(candidate["components"]), 190)
        self.assertEqual(report["preservedRuntimeUniqueIds"], 137)
        self.assertEqual(report["admittedSphereEntries"], 53)
        self.assertEqual(report["combinedUniqueIds"], 190)
        self.assertEqual(report["status"], "CANDIDATE_UNINSTALLED")
        self.assertEqual((live, runtime, spheres), originals)

    def test_reject_old_82_snapshot(self):
        live, runtime, spheres = fixture()
        runtime["components"] = runtime["components"][:82]
        with self.assertRaisesRegex(CatalogueRefused, "runtime ID set differs"):
            run_reconcile(live, runtime, spheres)

    def test_reject_partial_live_export(self):
        live, runtime, spheres = fixture()
        live["components"].pop()
        with self.assertRaisesRegex(CatalogueRefused, "live count drift"):
            run_reconcile(live, runtime, spheres)

    def test_reject_missing_or_extra_id(self):
        live, runtime, spheres = fixture()
        runtime["components"][-1]["componentId"] = "unknown-new"
        with self.assertRaisesRegex(CatalogueRefused, "runtime ID set differs"):
            run_reconcile(live, runtime, spheres)

    def test_reject_lost_alias(self):
        live, runtime, spheres = fixture()
        runtime["components"][0]["aliases"] = []
        with self.assertRaisesRegex(CatalogueRefused, "runtime aliases lost"):
            run_reconcile(live, runtime, spheres)

    def test_reject_missing_source_provenance(self):
        live, runtime, spheres = fixture()
        runtime["sourceSha256"] = ""
        with self.assertRaisesRegex(CatalogueRefused, "sourceSha256"):
            run_reconcile(live, runtime, spheres)

    def test_reject_missing_sphere_provenance(self):
        live, runtime, spheres = fixture()
        spheres["components"][0]["sha256"] = ""
        with self.assertRaisesRegex(CatalogueRefused, "archive SHA-256"):
            run_reconcile(live, runtime, spheres)

    def test_reject_empty_spheres(self):
        live, runtime, spheres = fixture()
        spheres["components"] = []
        with self.assertRaisesRegex(CatalogueRefused, "empty sphere"):
            run_reconcile(live, runtime, spheres)

    def test_reject_canonical_sphere_mismatch(self):
        live, runtime, spheres = fixture()
        spheres["components"][0]["sphereId"] = "another"
        with self.assertRaisesRegex(CatalogueRefused, "mismatched canonical"):
            run_reconcile(live, runtime, spheres)

    def test_reject_duplicate_sphere(self):
        live, runtime, spheres = fixture()
        spheres["components"].append(copy.deepcopy(spheres["components"][0]))
        with self.assertRaisesRegex(CatalogueRefused, "duplicate canonical"):
            run_reconcile(live, runtime, spheres)

    def test_reject_runtime_volatile_authority(self):
        live, runtime, spheres = fixture()
        runtime["components"][0]["ownership"] = {"ownerId": "a"}
        with self.assertRaisesRegex(CatalogueRefused, "volatile"):
            run_reconcile(live, runtime, spheres)

    def test_reject_non_runtime_live(self):
        live, runtime, spheres = fixture()
        live["components"][0]["componentKind"] = "sphere"
        with self.assertRaisesRegex(CatalogueRefused, "non-runtime"):
            run_reconcile(live, runtime, spheres)

    def test_identical_ids_on_distinct_artifacts_supported(self):
        live, runtime, spheres = fixture()
        # MCP v0.2-dev8 catalogue has repeated runtime component IDs for distinct artifacts.
        extra = copy.deepcopy(runtime["components"][0]); extra["artifact"] = "alternate.zip"
        runtime["components"].append(extra)
        candidate, report = run_reconcile(live, runtime, spheres)
        self.assertEqual(report["preservedRuntimeEntries"], 138)
        self.assertEqual(report["preservedRuntimeUniqueIds"], 137)
        self.assertEqual(len(candidate["components"]), 191)

    def test_cli_output_and_no_overwrite(self):
        live, runtime, spheres = fixture()
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            for name, body in (("live.json", live), ("runtime.json", runtime), ("spheres.json", spheres)):
                (folder/name).write_text(json.dumps(body), encoding="utf-8")
            cmd = [sys.executable, str(Path(__file__).resolve().parents[1]/"reconcile_catalog.py"),
                   "--live-export", str(folder/"live.json"), "--runtime-source", str(folder/"runtime.json"),
                   "--spheres", str(folder/"spheres.json"), "--expected-live-runtime-entries", "137",
                   "--output", str(folder/"candidate.json"), "--report", str(folder/"report.json")]
            first = subprocess.run(cmd, capture_output=True, text=True)
            self.assertEqual(first.returncode, 0, first.stderr)
            self.assertEqual(json.loads((folder/"report.json").read_text())["status"], "CANDIDATE_UNINSTALLED")
            second = subprocess.run(cmd, capture_output=True, text=True)
            self.assertNotEqual(second.returncode, 0)
            self.assertIn("refusing to overwrite", second.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
