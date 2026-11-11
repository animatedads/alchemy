#!/usr/bin/env python3
"""Static regression for committed-definition fail-closed seam.
Runtime qualification with ooRexx remains separately required.
"""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[1] / "rexx"
CONTROLLER = (ROOT / "WireApplicationController.cls").read_text()
GATE = (ROOT / "WireDefinitionGate.cls").read_text()
class DefinitionGateContract(unittest.TestCase):
    def test_no_application_dispatch_before_authorization(self):
        self.assertLess(CONTROLLER.index("definitionGate~authorize(event)"), CONTROLLER.index("model~bindingsFor("))
        self.assertIn("WIRE_DEFINITION_GATE_REQUIRED", CONTROLLER)
        self.assertIn("definitionGate~requestResync(event)", CONTROLLER)
        self.assertIn("return .array~new", CONTROLLER)
    def test_exact_identity_and_revision(self):
        for check in ("event~definitionVersion \\== expected[1]", "event~renderedRevision \\== expected[2]"):
            self.assertIn(check, GATE)
    def test_revocation_and_resync(self):
        self.assertIn("identities~remove(definitionId)", GATE)
        self.assertIn("requestResync(event~definitionId, event~workspaceContext)", GATE)
        self.assertIn("if \\identities~hasIndex(id) then return .false", GATE)
if __name__ == "__main__":
    unittest.main()
