# ooRexx AI Provider - OpenAI Compatible v0.5

Live-capable OpenAI-compatible adapter behind AI Access v0.5. v0.5 preserves the v0.4 wire/secret boundary while rebinding to Alchemy Objects v0.7 and WLU v0.11. The package keeps provider wire syntax, endpoint configuration and secret material outside the generic AI layer.

## Credential / transport boundary

Deployment configuration owns the endpoint, opaque credential reference, model allowlist and output cap. Credentials are acquired through Secret Broker v0.1. `OpenAICompatCurlTransport` materializes the short-lived lease into a mode-0600 curl config containing the Authorization header; the secret is not placed in command-line arguments or Alchemy instrumentation. Raw provider/network response bodies are bounded and not exposed as trusted error detail.

## Tool and structured-message wire mapping

Generic `AIProviderToolDefinition` values map to OpenAI-compatible `type:function` tools. Generic `AIProviderToolCall` values returned by the provider remain typed proposals with no execution authority.

The structured-message path maps `AIProviderMessage` values:

- `user` -> OpenAI `role:user`;
- `assistant` -> `role:assistant`, with typed calls projected to OpenAI `tool_calls`;
- `tool` -> `role:tool` with `tool_call_id`.

Function `arguments` are encoded as a JSON string on the OpenAI wire and decoded back to detached generic argument objects on response. Provider-specific wire objects do not escape into AI Access.

## WLU

`OpenAICompatWLU.cls` is optional and remains separately loadable. Its v0.4 conservative planner accounts for all model-visible input:

- legacy prompt bytes;
- serialized tool-definition bytes;
- serialized structured-message bytes;
- explicit conservative allowance for OpenAI message/tool-call wire expansion.

Qualification for the three-message continuation records 268 serialized message bytes plus 288 bytes of structural allowance. Evidence contains counts/byte totals only, never conversation contents, historical tool arguments or tool results. Provider-reported usage remains authoritative for settlement.

## Dependencies

Required:
- AI Access v0.5
- Secret Broker v0.1
- Alchemy Objects v0.7
- ooRexx Crypto v0.1

Optional WLU qualification:
- Runtime Registry v0.13
- Work Load Units v0.11

## Qualification

```sh
REXX_BIN=/path/to/rexx \
AI_ACCESS_ROOT=/path/to/oorexx_ai_access_v0.5 \
SECRET_BROKER_ROOT=/path/to/oorexx_secret_broker_v0.1 \
ALCHEMY_OBJECTS_ROOT=/path/to/alchemy_objects_v0.7 \
CRYPTO_SRC=/path/to/oorexx_crypto_v0.1/src \
RUNTIME_REGISTRY_ROOT=/path/to/runtime_registry_v0.13 \
WLU_ROOT=/path/to/oorexx_work_load_units_v0.11 \
./run_tests.sh
```

Omit both Runtime Registry/WLU roots to exercise the complete provider path with WLU explicitly absent.
