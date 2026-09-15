# Cooperative method interposition contract

Alchemy Objects v0.8 does not depend on a logging framework or another runtime interposition package. It can, however, cooperate with an object that already exposes the generic method-interposition protocol:

```text
__methodInterpositionAdd(methodName, providerId, interceptor [, priority])
__methodInterpositionRemove(methodName, providerId)
methodInterpositionStatus([methodName])
```

The protocol was supplied in the project update by ooRexx Logging v0.3 (`MethodInterpositionParticipant`). Alchemy uses it structurally rather than requiring or naming that class at runtime.

## Provider shape

Alchemy registers provider id:

```text
ALCHEMY.EXECUTION_PROVENANCE
```

at numeric priority `1000`.

A coordinator calls the registered interceptor using nested around-method semantics:

```text
before(receiver, methodName, arguments) -> token
... business method ...
after(receiver, methodName, token, result)
```

or, on a condition:

```text
failure(receiver, methodName, token, conditionObject)
```

Alchemy's package-local interceptor forwards to the object's execution telemetry/provenance machinery. The callback bridge requires an opaque identity token created and retained by the Alchemy object; a caller cannot authorize itself merely by knowing the callback method names.

## Ordering

### External coordinator first

```text
business method
     |
external coordinator wrapper     physical wrappers = 1
     |
     +-- external provider
     +-- Alchemy provider
     |
original business method
```

`instrumentMethod()` joins the existing coordinator. Either provider may later withdraw independently. The physical wrapper disappears only when the coordinator's final provider leaves.

### Alchemy first

If a compatible participant exists but no coordinator wrapper is active yet, Alchemy deliberately retains its historical direct wrapper:

```text
Alchemy wrapper
    |
original business method
```

This preserves Logging v0.3's existing contract: when Logging subsequently arrives it captures the pre-existing Alchemy object method, places its coordinator wrapper above it, and restores that exact Alchemy wrapper when Logging's final provider leaves.

While the external wrapper remains active, Alchemy refuses to remove the underlying direct layer:

```text
TELEMETRY_EXTERNAL_INTERPOSITION_ACTIVE
```

No method dictionary is changed on that failure. Once the outer coordinator releases, normal `uninstrumentMethod()` succeeds.

## Security boundary

The cooperative protocol does not change the rule that Alchemy automatic instrumentation refuses target methods that are:

- `PROTECTED`;
- `PRIVATE`;
- PACKAGE-scope;
- reserved AlchemyObject base surfaces.

`instrumentMethod()`, `instrumentRegisteredMethods()`, and `uninstrumentMethod()` are themselves `PROTECTED` in v0.8. A hosted execution package can therefore be denied these mutations by the normal Alchemy Security Manager policy.

The coordinator is an instrumentation mechanism, not an authority source. Alchemy does not accept coordinator presence as evidence that a caller is permitted to introspect, mutate security policy, unlock methods, or obtain cryptographic material.

## Compatibility evidence

The v0.8 development validation used the supplied:

```text
oorexx_logging_v0.3.zip
SHA-256 a8d5e7ea1e1c1001528c99a58c68f3ff6703a7a43c551505aeee2337882a8a11
```

Three actual-package compatibility cases were executed:

1. Alchemy telemetry first, Logging second — Logging's unchanged `test_alchemy_preexisting_telemetry.rex` PASSed.
2. Logging first, Alchemy second — one physical wrapper retained two providers; Alchemy and Logging each observed the business call; removing Alchemy left Logging active; removing Logging then restored the original method.
3. Alchemy first, Logging second, Alchemy release attempted while Logging remains active — Alchemy returns `TELEMETRY_EXTERNAL_INTERPOSITION_ACTIVE` without mutating either layer; after Logging releases, Alchemy removes safely.

The package includes `run_logging_integration.sh` for repeating these checks against an external Logging v0.3 tree; Logging is not required by the core test runner or by Alchemy Objects at runtime.

The package's normal test suite also includes a dependency-free protocol fixture so the base behavior remains regression-tested even when Logging is not installed.
