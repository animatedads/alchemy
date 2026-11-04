import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
AUTH = (ROOT / "grid" / "RexxOSGridIdentityAuthorization.cls").read_text()
WRAP = (ROOT / "grid" / "RexxOSGridAuthorizedServiceEndpoint.cls").read_text()

class IdentityContract(unittest.TestCase):
    def test_identity_directory_is_authority(self):
        self.assertIn("aclDecision", AUTH)
        self.assertIn('authorization_authority"] = "IDENTITY_DIRECTORY_ACL"', AUTH)
        self.assertIn('authentication_authority"] = "EXTERNAL_ATTRIBUTION_REQUIRED"', AUTH)

    def test_no_authentication_implementation(self):
        lowered = AUTH.lower() + WRAP.lower()
        self.assertNotIn("password", lowered)
        self.assertNotIn("simplebind", lowered)
        self.assertNotIn("bindsas", lowered)

    def test_service_is_fail_closed(self):
        self.assertIn('RpcServiceFault~new("UNAUTHENTICATED"', WRAP)
        self.assertIn('RpcServiceFault~new("PERMISSION_DENIED"', WRAP)
        self.assertIn('"GRID.ESTATE.READ"', WRAP)
        self.assertIn('"GRID.MANAGEMENT.READ"', WRAP)

    def test_no_placement_authority(self):
        joined = AUTH + WRAP
        for forbidden in ("allocateNode", "placementLease", "promoteStandby", "routeSelect"):
            self.assertNotIn(forbidden, joined)

    def test_no_private_methods(self):
        for text in (AUTH, WRAP):
            self.assertIsNone(re.search(r"::method\s+\S+\s+private", text, re.I))

if __name__ == "__main__":
    unittest.main()
