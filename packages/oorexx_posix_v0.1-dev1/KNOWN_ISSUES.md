# Known issues / runtime findings

## RxUnixSys missing-group lookup crash in supplied 5.3.0 r13196 build

Qualification against the supplied debug package found that both of these calls terminate the interpreter with SIGSEGV when the requested record does not exist:

```rexx
SysGetgrnam('definitely-no-such-group', 'NAME')
SysGetgrgid(2147483000, 'NAME')
```

Known records succeed. `SysGetpwnam` / `SysGetpwuid` do not show the same crash for a missing record; they return an empty string and errno 0.

Consequences for dev1:

- `lookupGroup()` fails closed with `CAPABILITY_UNAVAILABLE` and does **not** invoke the unsafe functions.
- `posix.group.safe-lookup` is not advertised.
- `lookupUser()` turns the empty/errno-0 missing-record convention into structured `LOOKUP_NOT_FOUND` evidence.
- the proposed RxUnixSys structured account/group lookup work should include a regression for missing records before this capability is enabled.

This is a runtime observation from the supplied package, not an assertion about all ooRexx releases/platforms.
