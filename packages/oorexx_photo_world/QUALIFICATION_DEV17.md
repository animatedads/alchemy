# Photo Survey World v0.1-dev18 qualification

Qualification target: Open Object Rexx 5.3.0 r13196 Internal Test Version, 64-bit, user-supplied Ubuntu debug package SHA-256 `8add57fd2463403c9e91f3f49856e3f61b34753938abab3a617fc8063d2df4ae`.

## Photo World runtime regressions

All twelve ordinary Photo World regressions pass under the real interpreter, and the exact Maths v0.14 `test_math3d.rex` dependency suite passes all 74 assertions. Runtime log SHA-256: `4cd42c3d25de8a3181348d7da36911e3ecd96da34774d52be2c88df5b9048d15`.

## Python Macrospace v0.31.6

Exact supplied archive SHA-256: `38175f11db8e7e7de28a37e4012c92a94109b4fbcfec7fb96ee166b4d4644c6b`. It was rebuilt as a host extension against the same r13196 headers/libraries and CPython 3.13. The focused class-family regressions pass for virtual class loading, arbitrary arity, Python object/class identity arguments, arbitrary live Rexx-object arguments, natural Python dispatch into retained Rexx objects, and positional-argument/non-string-return chaining. Macrospace log SHA-256: `052e5205856551dd611e10d726faf0640b9853fd8a38f9db09e334d176812e79`.

The Photo World-specific crossing additionally passes a real Maths `MathMatrix` into Python by live Rexx identity. Python reads `rows()`, `cols()`, calls `at(1,2)`, then chains through the non-string `context()` return and calls `provider()`. Expected and observed contract: `2x3:2:PURE`. This is the concrete proof that Maths, not a new Python tensor model, remains numerical authority across the bridge.

The copy of `AlchemyForeignObject.cls` inside Macrospace v0.31.6 is byte-identical (SHA-256 `e8ba3480e5c067615615026c9a9fb38d8c3bdfef465b0d8a0072531d416e43c8`) to the authoritative Alchemy Foreign Object v0.2 package supplied for Photo World.

## Standards gate

Claude's `oorexx_standards_enforcer.py` was run directly against the dev17 release candidate. Result: 30 source files scanned, 0 errors, 6 reviewed `PRIVATE_METHOD` warnings, `VERDICT: PASS`. Text log SHA-256 `6e7cc2e55a526325a51fac32255edfbc891b3a6b1d29ad52809d0fa10de430ff`; JSON log SHA-256 `7cd273b8aa3da5edd00c1546fff0c812a9f2ad112de087700d58fba05fea7c82`.

## Qualification summary

Machine-readable receipts report **17 PASS, 0 NOT_RUN, 0 FAIL**. The former Macrospace NOT_RUN lane is now closed for v0.31.6; no earlier bridge is substituted.
