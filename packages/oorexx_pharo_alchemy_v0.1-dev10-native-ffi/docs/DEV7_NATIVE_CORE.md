# dev7 native core

This cut implements the bridge-independent native correctness core needed before
binding to the Pharo VM.

* identity and generation are distinct fields;
* publication of a recycled resident identity creates a new generation;
* revocation prevents new pins of the exact generation;
* an already-pinned call may finish;
* the registry mutex is never held while foreign code executes;
* nested/reverse dispatch can therefore pin/re-enter without registry deadlock;
* positional count is independent of supplied-value presence;
* a presence bitmap distinguishes omission from a supplied nil/object;
* call correlation survives dispatch.

This test uses a native mock dispatch function only to exercise the lifecycle
machinery. It is NOT a claim of a Pharo VM crossing. The Pharo VM adapter remains
the next boundary.
