# Pharo 12 executable baseline

The user-supplied `stableStackVM12.zip` layout is:

    bin/pharo       launcher
    lib/pharo       native VM executable

Both need executable permission after ZIP extraction in this Linux environment.

The launcher successfully boots the supplied Pharo 12 image headlessly. Live
image probes establish:

* `Smalltalk version` -> Pharo12.0.0SNAPSHOT
* Object understands `doesNotUnderstand:`
* a Message retains selector `alpha:beta:`
* the Message retains two argument objects
* a BlockClosure receives `value:` and returns 42
* ordinary resident identity obeys `==`

These are executed image semantics, not source inspection.

The supplied ooRexx Debian package also executes here and reports ooRexx 5.3.0
r13196, 64-bit. The upstream Alchemy Foreign Object v0.2 test was attempted
against Alchemy Objects v0.8 extracted from the supplied API corpus. It reaches
the authoritative dependency chain and stops at missing `crypto.cls`; dev3
records this as BLOCKED rather than replacing the dependency with a fake.
