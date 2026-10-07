# ooRexx Management Intention Discovery v0.1-dev7

Dev7 keeps the Management resolver domain-blind while rebasing its transient network specialist on the current transport stack.

The Network Transport surface now carries, when advertised by related objects:

- Socket Provider v0.1-dev8 address/family/capability objects, including NORM and XTP multicast;
- XTP v0.1-dev11 route objects supplied by the XTP authority;
- independent path observations such as `PASS` or `NO_RESPONSE_OR_FILTERED`;
- Spiral 1 COTS-interface witnesses mapping standard/interface to ooRexx access object, provider/binding, native implementation and qualification state.

Management does not interpret those protocols or statuses. It performs bounded relationship traversal, discovers transient intention sources from related objects, asks those specialists whether the original request is relevant, and preserves their evidence.

A configured route, a path observation and a standards/interface witness are different facts. None is promoted into another by the Management layer.

## Dynamic qualification

The dev7 regression begins at machine `ED209C`, reaches a related multicast service, discovers Network Transport Intentions transiently, and exposes NORM, XTP route state, path evidence and an interface witness. The path authority is then changed from `NO_RESPONSE_OR_FILTERED` to `PASS`; the identical exploration sees the new observation and does not retain stale state.

## Run

```sh
REXX_BIN=/path/to/rexx ./tools/run_environment_test.sh
```

The environment suite is read-only and requires no live cloud or network access.
