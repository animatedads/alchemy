# Upstream adoption

Native source authority: https://github.com/JosepMariaBlasco/oorexxpython

The historical Macrospace v0.31.x native implementation is retired as a production development line. Retain its tests as qualification evidence, not as a competing implementation.

Qualification gates: (1) install upstream and ooRexx 5.3.0 r13265+ for thread tests; (2) run tests/run.sh in a clean Rexx-first and Python-first environment; (3) verify object identity/lifetime, compiled Python extensions, callbacks, worker threads, and four-channel speech concurrency; (4) preserve unqualified boundaries explicitly.

Alchemy owns virtual-class/service projections and ConnectSelector integration. Upstream owns native handles, interpreter lifetime, callbacks, GIL and thread attachment. This package is a thin adapter only.
