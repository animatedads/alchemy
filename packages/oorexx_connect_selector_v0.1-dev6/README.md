# ConnectSelector 0.1-dev6 — GitHub admission record

API `oorexx.connect_selector/0.1`. Complete 24-file source release SHA-256 `6ea919552264a8d50db77b2a513990226a869ebbf3ed930e98c055c8175184ae`. Local ooRexx 5.3.0 r13196 complete dependency-backed regression PASS, strict standards 0 errors/0 warnings.

**New in dev6**: typed outbound JMS broker send dispositions (ACCEPTED, REJECTED, UNKNOWN) with ambiguous legacy false treated as UNKNOWN. Only a proven reject allows immediate queue nack. Tests cover the three typed outcomes and legacy false.

This repository subtree currently contains the exact dev5→dev6 JMS patch and the engineering sphere, **not the full standalone source**. Full source admission and live JMS/RTO2 qualification remain open. See `spheres/connect_selector_gopher_sphere_v0.1/CONNECT_SELECTOR_SPHERE.md`.
