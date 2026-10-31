# BundySlam v0.2.1 source candidate

The original v0.2 ZIP is referenced by its existing Git blob SHA (not rewritten). Its sealed source SHA-256 is 30e1d483ea62c8805efc6c926cc07f0c5f3d29252de4d97dff7a4ff2be613ad2. An independent, byte-for-byte validated unified patch changes the physical-card continuation precedence and adds 10 ooRexx regression assertions. The package reconstruction script verifies the original ZIP, applies the patch, adds DEV3 evidence, updates the source manifest and runs qualification before any release tree can be accepted.

Local ooRexx 5.3.0 r13196 qualification: 176/176 parser assertions, 9/9 store spy adapter, 7/7 acquisition audit PASS. This does NOT qualify actual Rexx/SQL SQLite backend integration, JES, MVS execution, or large upstream corpus acquisition.

Architecture: Tom Dyer. Candidate implementation: CHATGPT. No automatic JES/volume action. Submission is NOT acceptance into main.
