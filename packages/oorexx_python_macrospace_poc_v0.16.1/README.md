# ooRexx ↔ Python Macrospace/Object Reversal POC v0.8

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

## v0.5 — UNKNOWN forwarding

`PythonObjectProxy` no longer declares `describe` or `speak`. Its only foreign dispatch seam is ooRexx `UNKNOWN`:

```rexx
::method unknown
  expose foreignHandle
  use strict arg messageName, arguments
  if arguments~items <> 0 then
    raise syntax 93.900 array ("v0.5 UNKNOWN POC only forwards zero-argument messages")
  return PYCALL(foreignHandle, messageName)
```

This proves both ordinary polymorphism (`AnimalCollection~descriptionText` sends `DESCRIBE`) and a made-up `MIDNIGHT_SNACK` message are caught by UNKNOWN and reflected to methods on the retained Python object. v0.5 intentionally limits UNKNOWN forwarding to zero-argument messages; argument marshalling is a later experiment.

## v0.5: optional exact Python method casing

`wrap_python_object()` now accepts an optional third argument: a dictionary mapping the ooRexx UNKNOWN message name to the exact Python attribute/method spelling. Keys are canonicalized to uppercase because ooRexx UNKNOWN supplies the message name that way. Unmapped methods retain the v0.4 default of lowercase lookup.

```python
proxy, handle = native.wrap_python_object(
    py_animal, FOREIGN_FACTORY,
    {"MIDNIGHT_SNACK": "midnightSnack"}
)
```

Thus `pythonAnimal~midnight_snack` can reach Python `midnightSnack()` without imposing one casing convention on every Python object.

## v0.6 — native ooRexx `~~` semantics across Python UNKNOWN

The bridge does **not** implement or emulate `~~`.  `AnimalCollection~doubleTildeProbe`
asks ooRexx itself to evaluate:

    returned = object~~midnight_snack

`MIDNIGHT_SNACK` is absent from `PythonObjectProxy`, so it crosses `UNKNOWN` and invokes
Python `midnightSnack()`.  That Python method deliberately returns a string.  ooRexx's
`~~` semantics must discard that method result and make the expression evaluate to the
original Rexx proxy receiver.  The probe checks object identity and then sends
`~describe` to the returned receiver, causing a second UNKNOWN/Python dispatch.

Expected v0.6 result includes:

    double-tilde-returned-receiver: 1|Monty is a Python parrot
    UNKNOWN + DOUBLE-TILDE POC PASS

This establishes that foreign dispatch through UNKNOWN does not need any special bridge
support for `~~`; receiver-return/chaining remains an ooRexx language semantic.


## v0.8 — Android/Termux build qualification

The build is now self-contained for the Termux source/build layout used by the POC.
It discovers `$HOME/src/ooRexx/api`, includes `api/platform/unix` for Android, uses
`$HOME/build/oorexx-xcover-safe/lib` by default, and consumes both Python compile
and linker flags from `python3-config`. On Android the build fails closed if the
resulting extension has no `DT_NEEDED` dependency on libpython.

Overrides: `PYTHON`, `CXX`, `CPPFLAGS`, `CXXFLAGS`, `LDFLAGS`, `OOREXX_SRC`,
`OOREXX_BUILD`, `OOREXX_API`, `OOREXX_PLATFORM_API`, `OOREXX_LIB`, and the older
`OOREXX_PREFIX` fallback.

Termux quick path:

    ./build.sh
    ./run-tests.sh

`run-tests.sh` runs the object proxy, reversal, mixed collection, UNKNOWN/casing/~~,
and Macrospace callback demos in a defined order.


## v0.8 experiment

Adds deliberately bounded UNKNOWN argument marshalling (0-2 scalar arguments), with integer and string tags, plus Python-object return reversal. A non-scalar Python return is retained by identity and represented back in ooRexx as another `PythonObjectProxy`. `python/arguments_return_object_demo.py` proves `animal~feed("biscuit", 2)` reaches Python with an actual Python `int`, and that a Python object returned by `makeFriend()` can immediately receive a subsequent ordinary ooRexx message.

This remains a POC: it is not a general marshaller, and it is intentionally independent of Alchemy / Queue Fabric.

## v0.10 method-profile experiment

`python/projection.py` adds a deliberately small projection layer above the native
bridge.  Object identity and capability identity are separate.  A discovered
profile is fingerprinted from its Rexx-visible method shape; two instances with
the same shape share the fingerprint without sharing a foreign-object handle.

Three modes are exercised by `python/profile_demo.py`:

* `discover` — inspect public Python callables and their signatures.
* `override` — discover first, then explicitly replace spelling/casing or declared
  argument/return metadata for selected Rexx messages.
* `forced` — expose only the manually supplied method profile.

Annotations are descriptive hints in this POC, not runtime type authority.  v0.10
does not yet enforce the declared profile at every PYCALL boundary.


## v0.10 — Python access to a guarded Rexx method while Rexx START runs

`GuardedAnimal~init` starts `GATELOOP` using ooRexx `START`.  The loop remains
entirely on the Rexx side, sleeps four short ticks, and then changes the object
variable used by `GUARDEDVALUE`'s `GUARD ON WHEN gate` condition.

Python synchronously invokes `guarded_value()` through the same retained Rexx
object bridge used by the earlier object proxy experiment.  The intended proof
is that the Python call waits in the guarded Rexx method and is released by the
independent START'ed Rexx activity.  This is intentionally not a generalized
threading API and does not involve Alchemy or Queue Fabric.

Run:

    ./build.sh
    python python/guarded_start_demo.py

Expected final marker:

    PYTHON -> GUARDED REXX METHOD + START LOOP POC PASS

## v0.11 — real ooRexx Stem

Adds a deliberately small Python view over a retained **real ooRexx `.Stem`**.
The factory constructs `.stem~new('ANIMAL.')`; Python accesses compound tails
through the Stem object's `[]` / `[]=` messages.  It is not converted to a
Python dict, so reads and writes operate on the retained Rexx object.

Run:

    ./build.sh
    python python/stem_demo.py
    ./run-tests.sh

Expected final marker:

    PYTHON <-> REAL OOREXX STEM POC PASS

## v0.12 — numeric torture chamber

This revision intentionally observes before generalising the native marshaller.

It exercises:
* Rexx `NUMERIC DIGITS 50`, `NUMERIC FUZZ`, and `NUMERIC FORM`;
* very large integers, decimal fractions, tiny/huge exponents;
* lexical numeric strings such as `"00123.4500"`;
* Python arbitrary precision `int` and `decimal.Decimal`;
* Python binary `float`, including its exact `hex()` representation;
* the `bool`-is-an-`int` Python trap;
* NaN, infinities and negative zero as explicit policy questions.

`python/numeric_codec.py` is a conservative candidate policy: `int` and
`Decimal` have exact decimal transfer forms; strings remain strings; bool,
float and nil are distinct categories.  It is deliberately not yet wired
through every native call path.  We first want evidence from the real runtimes.

## v0.13 — numeric activity context + argument baseline

Adds two deliberately pre-marshalling probes.

`numeric_context_demo.py` establishes that arithmetic is performed under the
`NUMERIC DIGITS/FUZZ/FORM` selected by Rexx code rather than treating those
settings as properties of transported values.

`argument_semantics_demo.py` establishes the next bridge invariant before
native argument marshalling is expanded:

    omitted argument != .nil != ""

The bridge must preserve all three states rather than collapsing them into
Python `None` or an empty string.

## v0.14 — cross-boundary omitted / nil / empty

Adds an explicit Python `OMITTED` sentinel.  It is intentionally distinct from
`None`: omission is represented at the native boundary by sending the Rexx
message with **zero arguments**; Python `None` sends the Rexx `.nil` object;
`""` sends a real empty Rexx String.

The Rexx method itself uses `arg(1, "E")`, so the test checks Rexx's own
argument-presence semantics after crossing the native bridge.

Also carries forward the v0.13 numeric-context test with its whitespace
assertions repaired.

## v0.15 — Rexx -> Python omitted / nil / empty

Reverses the v0.14 experiment.

A real sparse Rexx Array contains:
1. an absent slot,
2. `.nil`,
3. `""`,
4. `"hello"`.

The native boundary maps those to the Python bridge vocabulary:
`OMITTED`, `None`, `""`, `"hello"` and invokes a retained Python object's
`receive_slots(*values)` method.

The numeric-context harness now parses `key: value` semantically and strips
display whitespace instead of asserting Rexx `SAY` formatting.

## v0.16 — existing UNKNOWN collision

Tests projection onto an existing ooRexx object which already owns `UNKNOWN`.

The object performs the mutation from one of its own methods, using ooRexx
`instanceMethod("UNKNOWN")` to obtain the actual Method object and protected
`setMethod()` to:

1. retain that Method object under a unique per-object bridge-private alias;
2. overlay `UNKNOWN` on that object only;
3. dispatch projected profile names to Python;
4. forward unclaimed messages to the relocated original UNKNOWN via
   `sendWith(alias, .array~of(messageName, arguments))`.

The test also covers a Python method literally named `unknown`: a direct
`obj~UNKNOWN` call is distinguished from ooRexx's two-argument UNKNOWN
protocol invocation.

No original UNKNOWN source text is copied or reconstructed.

## v0.16.1 build repair

Repairs a compile regression inherited by v0.16 from the v0.15 reverse-argument
experiment: `rexx_slots_to_python()` referenced a nonexistent `py_lookup()`.
Python handles in this POC are retained `PyObject *` addresses, so the callback
now reconstructs the retained pointer using the same handle representation.
No v0.16 UNKNOWN-collision semantics are changed.
