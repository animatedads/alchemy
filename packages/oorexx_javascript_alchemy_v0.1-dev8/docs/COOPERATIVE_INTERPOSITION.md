# Cooperative interposition

The public ooRexx selector is a stable dispatch point. JavaScript member changes update the semantic target beneath that dispatch point rather than replacing the public Method object.

## Invariants

1. `projectJavaScriptSelector(NAME)` installs the public trampoline at most once.
2. JavaScript dispatch resolves the current JavaScript property at call time.
3. JavaScript mutation must not call `setMethod(NAME, ...)`.
4. Rexx-local overrides are installed under hidden aliases and take semantic precedence.
5. Changing the JavaScript target while a Rexx override is active does not disturb the override.
6. Removing the Rexx override reveals the current JavaScript target, not a stale saved Method.
7. Passive inspection of projection state must not invoke JavaScript.

This is intentionally compatible with a cooperative coordinator owning the physical public wrapper while Clouseau, Logging and Alchemy telemetry observe the same selector.
