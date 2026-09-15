# ooRexx AI Access v0.6

Provider-neutral model access qualified against Runtime Registry v0.14. v0.6 is a common-base repair/qualification release: the public provider API remains `ai.provider.access/0.5`, while the two behavioural bases now use preferred Alchemy Objects v0.7 `INIT` construction with complete STANDARD metadata and optional admission/accounting is requalified against Work Load Units v0.12.

## Structured conversation contract

`AIProviderMessage` is a plain DTO with roles `user`, `assistant`, and `tool`. Assistant messages may carry detached `AIProviderToolCall` values; tool messages bind their result to the provider call through `tool_call_id`. User messages cannot carry tool ids or calls, and tool messages cannot carry new calls.

`AIProviderRequest` keeps its existing model/prompt/output/tool-definition arguments and adds an optional bounded message array. A request must use either legacy prompt content or structured messages: when messages are present, `prompt` must be the empty string. This prevents accidental duplicate model input and duplicate WLU accounting.

The Runtime capability accepts the provider-neutral JSON fields `role`, `content`, `tool_calls`, and `tool_call_id`. Nested calls contain only `call_id`, `name`, and detached `arguments`. Unknown fields, including attempts to inject an internal `ability_id`, are rejected.

## Authority boundary

The plain value objects intentionally do **not** inherit `AlchemyObject`:

- `AIProviderRequest`
- `AIProviderUsage`
- `AIProviderReply`
- `AIProviderToolDefinition`
- `AIProviderToolCall`
- `AIProviderMessage`

The behavioural objects `AIProviderAdapterBase` and `AIProviderRuntimeCapability` do inherit the common Alchemy base. The provider receives model input and model-visible descriptions only; it never receives Runtime Registry, `AbilitySession`, broker authority, caller credentials, WLU account/rate-card/reservation objects, or a dispatch method.

Instrumentation records bounded metadata such as model, output limit, prompt character count, tool-definition/call counts, message count, status and token counts. It does not record prompt text, message contents, tool schemas, tool arguments, generated text, or tool results.

## Tool proposal channel

`AIProviderToolDefinition` remains description, not authority: name + description + detached input schema, with no Ability id. `AIProviderToolCall` remains proposal, not execution: call id + name + detached arguments. Runtime projection can return these calls as business data; the separate AI Tool Broker owns authorization and execution.

## WLU and immutable generations

WLU remains optional. Provider/model-specific planners forecast before dynamic execution; the outer runtime wrapper meters provider-returned actual usage. WLU evidence remains detached execution metadata.

Runtime Registry qualification retains immutable generation closure for the minimal Alchemy base source units so a staged provider generation cannot change because a later host search path contains a different base source.

## Dependencies

Required:

- Runtime Registry v0.14
- Alchemy Objects v0.7
- ooRexx Crypto v0.1

Optional qualification/integration:

- Work Load Units v0.12

## Qualification

```sh
REXX_BIN=/path/to/rexx \
RUNTIME_REGISTRY_ROOT=/path/to/runtime_registry_v0.14 \
ALCHEMY_OBJECTS_ROOT=/path/to/alchemy_objects_v0.7 \
CRYPTO_SRC=/path/to/oorexx_crypto_v0.1/src \
WLU_ROOT=/path/to/oorexx_work_load_units_v0.12 \
./run_tests.sh
```

Omit `WLU_ROOT` for the complete no-WLU qualification.
