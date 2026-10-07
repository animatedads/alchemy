# Python Macrospace integration

Speech v0.1-dev2 is qualified with **ooRexx Python Macrospace v0.31.7-rexxfirst2**.

Archive SHA-256: `6ab77de306b9a507804fe3eb868997b3c4a53bdc2654808eeef03a1c50d59c3b`.

The dependency is not bundled. Speech uses only the resident Python class/object projection
surface: `.AlchemyPythonClass~loadCls()`, projected object construction, and normal Rexx
messages to the projected provider object.

The repaired Macrospace boundary is important for speech because ooRexx is the process host:

- no Python bootstrap process or Python launcher is required;
- CPython binary extension modules can resolve the linked `libpython` without `LD_PRELOAD`;
- live Rexx-object projection no longer crashes in Rexx-first mode;
- independent speech lanes may own independent resident Python provider objects.

Speech deliberately does **not** make a single shared Python provider object the default.
The qualification model is one resident provider/proxy per speech lane, preserving independent
TTS/STT progress. Shared model instances are a separate optimization requiring provider-specific
thread/concurrency qualification.
