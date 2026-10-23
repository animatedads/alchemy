# Changelog

## 0.22-dev8
- Added AudioManagementInstaller as the canonical composition seam into
  Management Intention Discovery.
- Registers the Audio self-assessing intention source through
  ManagementSelfAssessingIntentionSurfaceSource.
- Registers Audio-owned relationships through
  ManagementRelationshipProviderSource.
- Builds ManagementRelatedSurfaceDiscovery and ManagementIntentionExplorer for
  bounded cross-domain traversal.
- Preserves exact Audio and related authority objects throughout discovery and
  evidence.
- Added regression for live graph mutation after installation and explicit
  Storage authority separation.
- Bumped core intention contract to audio.intentions/0.8 and Management bridge
  to audio.intentions.management/0.2.
- Static/package qualification passes; fresh dev8 r13196 runtime execution is
  pending and is not claimed.
