"""Plan42 Alchemy adapter regression probes (local/static scope, no ooRexx runtime required)."""
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
BRIDGE = ROOT / "tools" / "plan42_bridge.py"


def invoke(action, *args):
    run = subprocess.run([sys.executable, str(BRIDGE), action, *args],
                         cwd=ROOT, text=True, capture_output=True, timeout=60)
    try:
        obj = json.loads(run.stdout)
    except ValueError:
        raise AssertionError(f"non-JSON bridge stdout: {run.stdout!r} stderr={run.stderr!r}")
    return run.returncode, obj


class Plan42AlchemyIntegrationTest(unittest.TestCase):
    def test_discover_is_dynamic_and_non_dispatching(self):
        rc, result = invoke("discover")
        self.assertEqual(rc, 0)
        self.assertTrue(result["ok"])
        self.assertEqual(result["schema"], "plan42.integration/0.1")
        self.assertFalse(result["execute_generated"])
        self.assertFalse(result["publish"])
        self.assertFalse(result["dispatch"])
        self.assertIn("rust", result["targets"])
        self.assertIn("plan42.compile", result["intention_ids"])

    def test_inspect_no_executable_call(self):
        rc, result = invoke("inspect", "--spec", "tools/full_nodes.plan42.json")
        self.assertEqual(rc, 0)
        self.assertGreater(result["node_counts"].get("if", 0), 0)
        self.assertFalse(result["executed"])
        self.assertEqual(len(result["source_sha256"]), 64)

    def test_python_runtime_control_flow(self):
        rc, result = invoke("compile", "--spec", "tools/full_nodes.plan42.json", "--target", "python3")
        self.assertEqual(rc, 0, result)
        self.assertEqual(result["compatibility"]["status"], "native")
        self.assertFalse(result["executed"])
        output = ROOT / result["output"]
        subprocess.run([sys.executable, "-m", "py_compile", str(output)], check=True, timeout=15)
        run = subprocess.run([sys.executable, str(output)], text=True, capture_output=True, timeout=15, check=True)
        self.assertIn("logic preserved", run.stdout)
        self.assertIn("matched", run.stdout)

    def test_preferred_runtime_and_cli_types(self):
        rc, result = invoke("compile", "--spec", "tests/preferred_capabilities_smoke.plan42.json", "--target", "python3")
        self.assertEqual(rc, 0, result)
        output = ROOT / result["output"]
        for args, expected in [((), {"name": "Plan42", "count": 1, "langs": ["py", "rexx"]}),
                               (("--name", "Claude", "--count", "2", "--langs", "py,rexx"),
                                {"name": "Claude", "count": 2, "langs": ["py", "rexx"]})]:
            run = subprocess.run([sys.executable, str(output), *args], text=True,
                                 capture_output=True, timeout=15, check=True)
            self.assertEqual(json.loads(run.stdout.strip()), {"count": expected["count"], "langs": expected["langs"], "name": expected["name"]})

    @unittest.skipUnless(shutil.which("cc"), "C compiler unavailable")
    def test_native_c_safe_subset_syntax(self):
        rc, result = invoke("compile", "--spec", "tools/safe_subset.plan42.json", "--target", "c")
        self.assertEqual(rc, 0, result)
        self.assertEqual(result["compatibility"]["status"], "native")
        out = ROOT / result["output"]
        self.assertIn("PLAN42_EMBEDDED_SPEC_GZIP_BASE64_BEGIN", out.read_text())
        subprocess.run(["cc", "-std=c11", "-Wall", "-Wextra", "-Werror", "-fsyntax-only", str(out)],
                       check=True, capture_output=True, timeout=20)

    def test_rust_scaffold_emission_not_live(self):
        rc, result = invoke("compile", "--spec", "tools/rust_scaffold.plan42.json", "--target", "rust")
        self.assertEqual(rc, 0, result)
        self.assertEqual(result["target_maturity"], "scaffold")
        rust = (ROOT / result["output"]).read_text()
        self.assertIn("fn double", rust)
        self.assertIn("PLAN42_EMBEDDED_SPEC_GZIP_BASE64_BEGIN", rust)
        self.assertFalse(result["executed"])

    def test_registered_only_fail_closed(self):
        for target in ("cpp", "java"):
            rc, result = invoke("compile", "--spec", "tools/full_nodes.plan42.json", "--target", target)
            self.assertNotEqual(rc, 0)
            self.assertEqual(result["status"], "unsupported-target")

    def test_native_engine_never_used_for_c(self):
        rc, result = invoke("compile", "--spec", "tools/safe_subset.plan42.json", "--target", "c", "--engine", "native")
        self.assertNotEqual(rc, 0)
        self.assertEqual(result["status"], "invalid-route")

    def test_native_absent_fails_explicitly(self):
        if shutil.which("rexx"):
            self.skipTest("native interpreter available: use live native qualification")
        rc, result = invoke("compile", "--spec", "tools/full_nodes.plan42.json", "--target", "oorexx", "--engine", "native")
        self.assertNotEqual(rc, 0)
        self.assertEqual(result["status"], "runtime-unavailable")
        self.assertTrue(result["no_silent_fallback"])

    def test_input_escape_refused(self):
        rc, result = invoke("inspect", "--spec", "../../etc/passwd")
        self.assertNotEqual(rc, 0)
        self.assertEqual(result["status"], "error")
        self.assertIn("escapes", result["message"])

    def test_output_escape_refused(self):
        rc, result = invoke("compile", "--spec", "tools/full_nodes.plan42.json", "--target", "python3", "--output", "../../tmp/unwanted.py")
        self.assertNotEqual(rc, 0)
        self.assertEqual(result["status"], "error")

    def test_framework_runner_has_actual_service_registration(self):
        text = (ROOT / "runner.rex").read_text()
        self.assertIn("container~register('plan42', .AlchemyPlan42Service~new(container))", text)
        self.assertIn("::requires 'plan42/AlchemyPlan42Service.cls'", text)
        cls = (ROOT / "plan42" / "AlchemyPlan42Service.cls").read_text()
        for method in ("discover", "inspect", "compile", "intentions", "reload"):
            self.assertIn("::method " + method, cls)
        self.assertIn("_container~get('transport.isolated')", cls)


if __name__ == "__main__":
    unittest.main(verbosity=2)
