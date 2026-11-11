#!/usr/bin/env python3
"""Source-level contract guard; NOT a substitute for ooRexx/native qualification."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
EVENT = (ROOT / "rexx/WireApplicationEvent.cls").read_text()
PORT = (ROOT / "rexx/WireRendererEventPort.cls").read_text()

class EventContextContract(unittest.TestCase):
    def test_event_exposes_captured_values(self):
        for field in ("renderedRevision", "workspaceContext", "definitionId", "definitionVersion"):
            self.assertIn(f"::attribute {field} get", EVENT)
            self.assertIn(field, PORT)
    def test_port_forwards_original_capture(self):
        self.assertIn("renderedRevision, workspaceContext, definitionId, definitionVersion)", PORT)
        self.assertNotIn("model~renderedRevision", PORT)
        self.assertNotIn("model~workspaceContext", PORT)
    def test_definition_identity_pair(self):
        self.assertIn("WIRE_DEFINITION_ID_VERSION_PAIR_REQUIRED", EVENT)
    def test_semantic_dispatch_retained(self):
        self.assertIn("controller~dispatch(event)", PORT)
        self.assertIn("model~scopedUI(scopes[source])", PORT)

if __name__ == "__main__":
    unittest.main()
