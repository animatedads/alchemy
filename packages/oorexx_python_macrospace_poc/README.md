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

## v0.15.3 host-qualified rebase

Built from the user-supplied qualified v0.14 baseline plus the v0.15.2
registry-correct reverse-argument experiment.  The numeric-context Python
qualification harness now parses semantic `key: value` fields and strips
incidental ooRexx SAY whitespace, matching the already-established v0.14
qualification rule.

## v0.16.0 existing-UNKNOWN composition

Object-local composition preserves the receiver's existing UNKNOWN Method
object under a generated private selector, then installs the already-compiled
BRIDGEUNKNOWN Method object as UNKNOWN. Projected names dispatch through
PYCALL; unclaimed names use SENDWITH to the preserved original Method.
The installer explicitly registers PYCALL before projection.

Host qualification: native build PASS and the focused collision test PASS.
The aggregate multi-process harness is not claimed here because this execution
environment's unrelated Python artifact-runtime startup repeatedly consumed
the harness timeout; v0.15.3 remains the qualified inherited baseline.

## v0.16.1 reserved UNKNOWN observation

A direct `receiver~UNKNOWN` is not an unknown-message event in ooRexx once the
bridge Method is installed: it selects the actual UNKNOWN method and therefore
does not arrive in the `(messageName, argumentsArray)` UNKNOWN protocol shape.
Consequently a Python member literally named `unknown` cannot be transparently
projected onto the same selector without an explicit escape/alias API. This is
now treated as a reserved-selector boundary rather than conflated with UNKNOWN
fallback dispatch.

## v0.17.0 Python-thread / ooRexx-activity concurrency

Adds a per-calling-thread native send path. Each Python worker attaches its own
`RexxThreadContext` to the existing `RexxInstance`, releases the Python GIL
while ooRexx executes, and detaches after the result has been converted.

The focused qualification starts a guarded Rexx call from Python thread A.
While that call is waiting for a Rexx object guard, Python thread B enters an
UNGUARDED method on the same Rexx object and returns before A is released.
The Rexx START'ed gate activity subsequently opens the guard and A returns.

This establishes that the bridge need not serialize independent Python callers
behind the creator thread context or the Python GIL.

## v0.18.0 Python-authoritative class and inheritance semantics

Python classes now cross the bridge with the same retained opaque identity
model as other Python objects. The bridge can obtain an object's exact class,
ask Python `isinstance` / `issubclass`, and inspect Python's authoritative MRO.
It does not infer inheritance from projected methods and does not reimplement
Python C3 linearization in Rexx.

The focused test covers multiple inheritance, transitive bases, an unrelated
class, exact class identity and the complete `__mro__` ordering.

## v0.18.1 Rexx-facing foreign class surface

`PythonObjectProxy~pythonClass` now returns a `PythonClassProxy`.
`PythonObjectProxy~isInstanceOfPython(classProxy)` and
`PythonClassProxy~isSubclassOf(otherClassProxy)` delegate the relationship
question to CPython. `PythonClassProxy~qualifiedName` exposes diagnostic
module/qualname information without using names as identity.

ooRexx's own `isInstanceOf()` remains untouched: a foreign proxy is still an
ooRexx PythonObjectProxy. Foreign inheritance is a separate authoritative
relationship owned by Python.

## v0.19.0 — Alchemy adoption

The Rexx-side foreign object is now `.AlchemyPythonObject`, a real descendant
of the existing `.AlchemyObject` from Alchemy Objects v0.8. The foreign class
representation is `.AlchemyPythonClass`, also an Alchemy descendant.

This package does not copy or fork `AlchemyObject.cls`. It declares the
authoritative Alchemy Objects package as an external dependency. Descendant
construction uses `self~init:super`, as required by the Alchemy v0.8 adoption
contract. Existing Alchemy reserved surface names are not overridden.

The provider-specific rule remains: Python owns Python object/class identity
and Python type relationships; Alchemy supplies the ooRexx object contract.
The same shape is intended to permit a future `.AlchemyDotNetObject` without
putting Python- or CLR-specific type rules into `.AlchemyObject`.

## v0.19.1 — Python type-authority torture

Adds an explicit direct-base query and qualifies the Alchemy Python type seam
against Python relationships that cannot safely be reconstructed from names
or a copied inheritance tree: ABC virtual subclass registration, metaclasses,
runtime-generated classes, multiple class identities with identical
module/qualname, and authoritative `__bases__`.

The rule is now executable: Alchemy carries identity and asks the owning
runtime. It does not synthesize Python inheritance in ooRexx.

## v0.20.0 — shared foreign-runtime package-space foundation

Adds `AlchemyForeignObject.cls`, the common Alchemy descendant intended for
both Python and CLR bridges.  Python object/class proxies now inherit it.
Provider-specific type rules remain outside this class.

The embedded bootstrap establishes the resolved `REXX_PATH` before creating
the ooRexx interpreter, then loads entry packages with the ooRexx package API.
Nested `::requires` are therefore resolved by ooRexx itself.  The bridge does
not vendor Alchemy Objects, crypto, or the ooRexx platform `json.cls`.

Focused qualification requires `ALCHEMY_OBJECTS_SRC`, `ALCHEMY_CRYPTO_SRC`,
and `OOREXX_PLATFORM_BIN` and runs `python/alchemy_package_space_demo.py`.

## v0.21.0
Adds Python-authoritative BASES/MRO queries and Rexx-side AlchemyPythonClass directBases/mro surfaces. Shared AlchemyForeignObject remains the separately shareable dependency seam.

## v0.22.0
Indexed real-Stem semantics: `.0` count plus `.1..n`, Python `len`, iteration and append. A bridge-unaware Rexx `StemConsumer` consumes the same retained Stem after Python mutation.

## v0.22.1
Test-harness cleanup: legacy `stem_demo.py` now establishes the same Alchemy/package-space environment as current embedded tests. No knowingly failing focused tests remain in this qualification set.

## v0.23.0
Rebased existing-UNKNOWN composition on shared Alchemy Foreign Object v0.2. Python no longer owns relocation/preservation/fallback machinery; ExistingUnknownThing subclasses AlchemyForeignObject and delegates installation/fallback to the shared base. Legacy UNKNOWN tests now establish current package space. Fixed stale foreign factory class name.

## v0.24.0
Python foreign-handle registry now reference-counts repeated retains of the same Python identity. One release no longer invalidates another live owner. Final release drops the registry's CPython reference; stale repeated release is tolerated. Added weakref/GC lifetime torture.

## v0.25.0
Extends lifetime qualification to Python class/type and direct-base handles. Repeated type/base queries retain the same identity handle with independent ownership; penultimate release preserves class relationships and final release is safe. No semantic implementation change beyond v0.24 registry ownership fix.

## v0.26.0
Adds cross-runtime lifetime torture for a non-scalar Python object returned through Rexx UNKNOWN. The returned Python identity is retained, represented by an AlchemyPythonObject Rexx proxy, remains callable after parent/external ownership is dropped, and is collected only after its explicit foreign handle is released. Rexx global-reference lifetime and Python foreign-handle lifetime are proven independent.

## v0.27.0
Adds Rexx-held foreign-proxy lifetime qualification. An ordinary Rexx collection retains AlchemyPythonObject after the native Rexx global-reference handle is released; the Python target remains callable and identity-stable through the Rexx-held proxy. Explicit Python foreign-handle ownership remains independent and controls final Python collection.

## v0.30.0 — dual-runtime live method surgery
Qualifies independent live mutation layers on the same projected Python object. Python class method P1 is visible through existing Rexx proxies; an object-local Rexx FOO layer R1/R2 shadows natural Rexx dispatch without freezing Python authority; Python may replace P1 with P2 underneath that live Rexx layer; a future Python instance sees P2; removing the Rexx object-local method reveals the current Python P2 rather than a cached P1; deleting Python foo is immediately visible through all existing proxies. No proxy recreation or Python type-identity replacement occurs.

## v0.29 live Rexx callable surgery

The reverse mutation path is now qualified: Python may retain a descriptor-capable
`RexxLiveCallable` whose identity remains stable while the target ooRexx object's
object-local method is replaced. Invocation resolves the Rexx target and selector
at call time; it does not snapshot a Rexx Method. Revoking the retained Rexx handle
causes a deterministic `RuntimeError` instead of dereferencing stale storage.


## v0.30.0 concurrent dual-runtime surgery

Adds concurrent Python-class mutation and Rexx-target mutation while independent Python activities continuously invoke both surfaces. RexxLiveCallable now attaches each calling thread to ooRexx and pins the target with an invocation-owned global reference before releasing the registry lock. Concurrent revocation can therefore invalidate future calls without freeing a target underneath an in-flight invocation. The torture accepts only values from fully published Python/Rexx implementations and deterministic revoked-call failures.

## v0.30.1 code-review maintenance pass

This maintenance pass intentionally changes no public bridge API.  It documents
method-level ownership/threading contracts in the native boundary and centralizes
Python-object registry release semantics.

Review fixes:

- `wrap_python_object()` validates/normalizes method-case metadata before taking
  ownership, so malformed metadata cannot leak a retain.
- failed Rexx-proxy construction now rolls back through the same counted release
  path as normal destruction; it no longer directly erases/`DECREF`s registry
  state and therefore cannot invalidate another owner of the same Python object.
- `py_object_call()` pins its Python target with `INCREF` while still under the
  registry mutex, then invokes outside the mutex.  Concurrent release therefore
  cannot turn a valid lookup into a use-after-free.
- registry teardown is centralized in `release_python_object_locked()` /
  `release_python_object_handle()` to keep the object table, reverse identity
  map, retain counts, method-case metadata, and CPython reference count in sync.
- concise method-level comments now identify the non-obvious package bootstrap,
  handle ownership, attached-thread, callback pinning, and live-callable rules.

The design rule remains: runtime locks protect only bridge bookkeeping.  They are
not held while arbitrary Python or ooRexx application code executes.

## v0.30.3 maintainability checkpoint

The aggregate test runner now includes every current ownership, rollback,
type-authority and live-surgery torture from the v0.24-v0.30 line.  Shared
coordinator/interposition and sparse-position fixes identified by the stack
design review are explicitly left to their owning shared Alchemy layer rather
than being patched privately into the Python bridge.  See
`REVIEW_FOLLOWUP_v0.30.2.md`.


## v0.30.3 shared semantic-target qualification

The reverse-direction live Rexx callable now qualifies against Alchemy Objects
0.8.2's shared semantic-target seam. `LiveRexxTarget` subclasses `AlchemyObject`,
instruments `VALUE` once, and advances R1 -> R2 -> R3 through
`amendSemanticTarget()` rather than replacing the public coordinator.  The Python
callable retains only Rexx object identity + selector; it does not cache the target
Method or generation.  The focused test also distinguishes semantic target
revocation from native Rexx-handle revocation.

Required qualification dependency: `ALCHEMY_OBJECTS_SRC` must identify an Alchemy
Objects tree providing `alchemy.objects.semantic-target/0.1` (v0.8.2 candidate or
later compatible implementation).

## v0.31.0 — Rexx-facing virtual Python class load/operate surface

The existing Python-authoritative class projection is now directly loadable and
operable from ooRexx.  `.AlchemyPythonClass~loadCls(module, qualifiedName)` (and
its `resolveCls` synonym) imports a live Python type and returns the existing
`.AlchemyPythonClass` projection; it does not synthesize or copy a Rexx class.

A loaded projection accepts `~new(...)` to invoke the retained Python type and
returns the existing `.AlchemyPythonObject` projection.  Class/static method
messages are dispatched live through Python lookup, while instance messages
continue through the existing UNKNOWN bridge.  Python therefore remains
authoritative for identity, descriptors, metaclasses, bases/MRO and runtime
mutation.

`PYCLASSLOAD` and `PYCLASSCONSTRUCT` are registered during package-space
bootstrap, together with PYCALL/PYTYPEQUERY/PYTYPERELATION, so Rexx code can
use the class surface before any Python object has first been wrapped.  The
constructor deliberately retains the current POC's two-scalar-argument bound;
this release does not create a second argument-marshalling model.

Focused proof: `rexx/virtual_python_class.rex` loads
`python/virtual_class_demo.py::VirtualCounter`, calls a class method, constructs
an instance, calls instance methods, and verifies Python-authoritative
`isInstanceOfPython`.

## v0.31.2 — Rexx projection ownership closes with the class surface

The Rexx-facing Python object and Python class projections now own and release
their Python-registry retain explicitly.  `AlchemyPythonObject` and
`AlchemyPythonClass` implement idempotent `UNINIT` finalization through the new
`PYRELEASE` bridge routine.  The native registry's existing stale-release rule
makes shutdown/finalizer ordering safe and prevents a second finalizer call from
underflowing ownership.

`wrap_python_object()` now registers the complete class-facing routine family
(`PYCLASSLOAD`, `PYCLASSCONSTRUCT`, and `PYRELEASE`) as well as the existing
call/type routines.  A bridge first entered from Python can therefore reverse
into Rexx, obtain/load a Python class projection, construct through it, and
return to Python without depending on a prior package-space bootstrap to have
incidentally registered the class operations.

Focused proofs: `rexx/virtual_python_class.rex` remains green and
`rexx/virtual_python_class_release.rex` proves one projected class retain is
released exactly once (including an explicit repeated-UNINIT stale-release
check).  The release proof is run in a fresh embedded interpreter so unrelated
live projections cannot mask the retain count.

## v0.31.3 - identity-bearing class-family arguments

The class-facing Rexx surface now accepts existing `.AlchemyPythonObject` and
`.AlchemyPythonClass` projections as positional constructor/method/class-method
arguments.  They cross as retained Python identities (`P:` / `C:` handles), not
as strings or serialized snapshots.  Decode takes a temporary Python INCREF so
a concurrent Rexx projection release cannot invalidate an in-flight call.

Python `type` objects returned by live dispatch are now classified as
`@PYCLASS:` and reprojected as `.AlchemyPythonClass`; ordinary non-scalars remain
`.AlchemyPythonObject`.  This makes class identity round-trip through ordinary
Rexx message traffic while leaving Python authoritative for the type itself.


## v0.31.6 - natural Python operation of retained Rexx objects

A retained Rexx projection now maps an otherwise-missing Python attribute to a
live Rexx message callable.  `peer.describe()` therefore sends `DESCRIBE` to the
original Rexx object.  Concrete Python attributes remain authoritative and the
legacy explicit `peer.send("DESCRIBE")` seam remains available.


## v0.31.7 - structured Rexx exceptions in natural Python dispatch

Natural Python calls on retained Rexx objects now preserve ooRexx condition
identity instead of collapsing every Rexx failure to a generic RuntimeError.
The native module exports `RexxError(RuntimeError)`.  A failed live Rexx message
raises `RexxError` with `code`, `rc`, `position`, `condition_name`,
`rexx_message`, `program`, and `description` attributes populated from
`RexxCondition`.  This keeps Python exception handling idiomatic while retaining
the authoritative Rexx failure information for logging, policy, or re-entry.

Focused proof: `rexx/virtual_python_class_rexx_exception.rex`.
