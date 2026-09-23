# ooRexx ↔ Python Macrospace/Object Reversal POC v0.3

Deliberately tiny, standalone proof of concept. No Alchemy, Queue Fabric, REST, JSON, sockets, or subprocess protocol.

v0.3 extends v0.2 with the reverse direction: a live Python object is retained in a native Python registry, represented inside ooRexx by a real `.PythonObjectProxy`, and that proxy can be stored in an ordinary ooRexx collection beside genuine ooRexx objects.

The decisive test is `python/mixed_collection_demo.py`:

* create genuine ooRexx `.Animal` `Mog`;
* create ordinary Python `PythonAnimal` `Monty`;
* create an ooRexx `.PythonObjectProxy` holding only Monty's foreign handle;
* put both Rexx objects into the same genuine `.AnimalCollection`;
* ask **ooRexx** `AnimalCollection~descriptionText` to iterate the collection and send `~describe` to each member;
* the first dispatch stays in ooRexx; the second reaches `.PythonObjectProxy~describe`, calls registered native `PYCALL`, reacquires the Python GIL, resolves the retained Python object and invokes its `describe()` method.

Thus the Python object itself is not converted into a Rexx Directory. ooRexx stores a Rexx proxy object preserving foreign identity.

Build:

    OOREXX_PREFIX=/path/to/usr/local ./build.sh

Run:

    LD_LIBRARY_PATH=$OOREXX_PREFIX/lib PYTHONPATH=python python3 python/mixed_collection_demo.py

Expected key result:

    mixed-oorexx-collection: Mog is a cat | Monty is a Python parrot
    python-describe-call-count: 1
    MIXED OBJECT COLLECTION POC PASS

The earlier v0.1 Macrospace Alarm callback and v0.2 Python→live-ooRexx object proxies are retained and regression-tested.

This is intentionally not yet a general bridge: callback arguments/results are strings, Python object lifetime is explicitly retained/released, method exposure is hard-coded (`describe`, `speak`, plus `call`), and no attempt is made at shared cross-runtime garbage collection.
