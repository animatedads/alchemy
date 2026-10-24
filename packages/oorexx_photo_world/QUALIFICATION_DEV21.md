# Photo Survey World v0.1-dev21 qualification

## Scope

dev21 makes raw structural image geometry first-class across the real
Macrospace boundary.  OpenCV LSD supplies only primitive line detections.  The
accepted line endpoints are deposited into live ooRexx objects; vanishing-point
consensus/refinement and Manhattan lens checks are performed by Photo Survey
World using ooRexx Maths v0.14.

The actual room topology remains the dev20 central chimney breast with an alcove
on both sides.  dev21 does not claim the breast or alcove dimensions are solved.

## Runtime

Open Object Rexx 5.3.0 r13196 Internal Test Version, 64-bit, build 3 Aug 2026.
Qualification package SHA-256:
`8add57fd2463403c9e91f3f49856e3f61b34753938abab3a617fc8063d2df4ae`.

Python bridge: Macrospace v0.31.6, rebuilt in this environment from the bundled
source against that ooRexx runtime.  Exact Alchemy Objects v0.8.2,
Alchemy Foreign Object v0.2 and ooRexx Crypto v0.8.3 are in the qualification
closure.

## Executed results

- 15 direct non-Macrospace Photo World regressions: PASS, including the new
  synthetic three-family vanishing-point regression.
- Macrospace v0.31.6 arbitrary-arity/live-Maths provider regression: PASS.
- Legacy structural summary crossing on a real room photo: PASS.
- New structured segment crossing on a real room photo: PASS.
- Six supplied room photographs through Python detector -> live Rexx segment
  objects -> ooRexx/Maths vanishing solver: PASS.
- Bundled Maths v0.14 `test_math3d.rex`: PASS, 74 assertions.

At the conservative 120-pixel minimum segment length the six real-photo segment
counts are 27 / 40 / 20 / 26 / 33 / 9.  Vanishing-family counts are
3 / 3 / 2 / 2 / 3 / 1.  Only view 1 passes the <=0.20 Manhattan
orthogonality-RMS gate and supports the 80-degree diagonal main-lens prior;
views 2-6 remain unresolved rather than being forced.

The final ZIP is scanned by `oorexx_standards_enforcer.py`; final hash/manifest
and exact standards output are recorded after archive assembly.
