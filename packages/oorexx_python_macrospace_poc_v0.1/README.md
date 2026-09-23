# ooRexx ↔ Python Macrospace POC v0.1

Intentionally tiny and completely independent of Alchemy.

It proves only three things:

1. A real ooRexx `Animal` object: 3 attributes (`name`, `species`, `sound`), one constant (`KINGDOM`), and two returning methods (`describe`, `speak`).
2. `AnimalCollection`, holding multiple real `Animal` objects.
3. An ooRexx `Alarm` whose `ring` method resolves `PYALARM` through **ooRexx Macrospace**. The macro calls a registered native `PYCALLBACK`, which invokes a method on an actual Python object and returns that method's result all the way back into ooRexx.

The deliberate call chain is:

    Python object
      -> native bridge starts demo.rex
      -> Alarm~ring
      -> PYALARM(...) [Macrospace]
      -> pyalarm.rex
      -> PYCALLBACK(...) [registered native function]
      -> PythonAlarmReceiver.on_alarm(...)
      -> "ACK:1"
      -> ooRexx

No JSON, sockets, subprocess callback, REST, Queue Fabric, Foreign Runtime, or Alchemy component is involved.

## Build

With ooRexx installed at `/usr/local`:

    ./build.sh

Or:

    OOREXX_PREFIX=/some/prefix ./build.sh

## Run

Run from the package root so `::requires "animals.cls"` can be found predictably:

    cd rexx
    python3 ../python/demo.py

`PYALARM` is added before the demo, queried to prove it is in Macrospace, and dropped afterwards. `PYCALLBACK` is likewise registered only for the lifetime of the experiment.

## Deliberate limitations

This is not yet an object bridge. It proves the reversal/callback seam first. There is one process-global Python callback receiver, one callback method name, strings only at the callback boundary, and no threading/lifetime/general object projection machinery. Those are intentionally excluded from v0.1.
