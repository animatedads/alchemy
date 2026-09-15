# ooRexx Secret Broker v0.2

Reference-only provider credential broker for the Alchemy ooRexx stack.

The broker is deliberately **not** a secret database. A provider-specific resolver owns where a value comes from; callers name a logical reference and receive a short-lived `SecretLease`. Instrumentation records references/status/sequence only and never secret contents.

## Current API

- `SecretBroker~new(provider)`
- `broker~acquire(reference)` -> `SecretLease`
- `lease~secretForTrustedConsumer()` -> `SecretValueResult`
- `lease~retire()` / compatibility `release()`
- compatibility `lease~secretValue` for older provider packages
- `MappedEnvironmentSecretProvider` resolves a configured reference -> environment-variable name on each acquisition, allowing host-side rotation without rebuilding provider objects
- `TestSecretProvider` is deterministic fixture-only storage

A successful `SecretLease` also exposes `ok` and `value` (`value` is the lease itself), preserving result-style acquisition used by current Grok/OpenAI real-time providers while retaining the older direct-lease batch surface.

## Authority boundary

Secret Broker does not receive Runtime Registry, WLU authority, prompts, model responses or provider endpoint authority. Trusted transports are responsible for materializing the lease without placing credentials on argv and for deleting temporary material. Provider certifications historically used mode-0600 curl config files for this purpose.

## Dependencies

- Alchemy Objects v0.7
- ooRexx Crypto v0.1 (shared dependency required by Alchemy Objects)

## Limits

v0.2 provides in-process reference/lease governance. It does not claim hardware-backed storage, encryption-at-rest, cross-process isolation, automatic external-vault renewal, or secure memory erasure guarantees beyond dropping ooRexx references/strings on lease retirement.
