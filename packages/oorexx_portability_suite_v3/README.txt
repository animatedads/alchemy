ooRexx Portable Feature Suite + RexxFLOPS
=============================================

Files
-----

oorexx_portability_suite.rex
    One ooRexx program testing core language behavior, compound variables,
    objects, asynchronous START/RESULT activities, stream I/O, named rxapi
    queues, CSVStream, YAML, and RxSock.

    The RxSock test intentionally creates TWO DIFFERENT ooRexx objects.
    A listener object runs in one activity and a client object runs in another.
    The listener binds localhost port 0, obtains the OS-assigned ephemeral
    port, signals it through an ooRexx guarded latch, accepts the client,
    receives a payload and replies.  This avoids spawning a second Rexx
    process and directly exercises ooRexx object/activity + RxSock integration.

rexxflops.rex
    Standalone portable score.  No external class dependencies.

    It runs a deterministic NUMERIC DIGITS 18 kernel with exactly ten ooRexx
    arithmetic operators per iteration, calibrates the iteration count and
    reports the median of three trials in millions of ooRexx numeric operations
    per second (Mops/s).

    "RexxFLOPS" is deliberately a language/runtime score.  It is not a claim
    about CPU hardware IEEE floating-point FLOPS.

run_oorexx_suite.sh
    Convenience wrapper for Termux/Linux.  It recognizes the XCover build-tree
    layout and adds csvStream/yaml source directories to REXX_PATH.

Android / XCover
----------------

    chmod +x run_oorexx_suite.sh
    ./run_oorexx_suite.sh suite
    ./run_oorexx_suite.sh flops
    ./run_oorexx_suite.sh flops 2.0

Normal ooRexx installation
---------------------------

If csvStream.cls and yaml.cls are installed in the normal ooRexx search path:

    rexx oorexx_portability_suite.rex
    rexx rexxflops.rex

The standalone RexxFLOPS script is intentionally suitable for comparing the
same ooRexx workload across the phone, desktops, VMs and cloud nodes.


v2 notes
--------

* Fixed two false suite failures in v1.  v1 used STREAM(file,"C","DELETE")
  for temporary-file cleanup, but DELETE is not a Stream command.  v2 uses
  the ooRexx .File class delete method.

* Failure reporting now includes condition code, RC, position and program when
  the condition object provides them.

* RexxFLOPS calibration is now resistant to scheduler/GC pauses and uses five
  measured trials.  The portable score is their median; spread is also shown.


v3 notes
--------

* Corrected CSVStream test semantics.  CsvStream~open() intentionally performs
  the operation without returning a value; assigning its result caused v2's
  Error 91.999.  v3 calls open as a message, then checks csv~state.

* Corrected RexxFLOPS result construction.  v2 created a zero-sized Array and
  extended it slot-by-slot; on this ooRexx build the second indexed assignment
  raised Error 97.1.  v3 returns a fully-sized .Array~of(...) instead.


* v3 also adds an explicit .Array~new indexed-assignment/auto-extension probe.
  This distinguishes a benchmark result-packaging problem from a runtime Array
  regression on Android.
