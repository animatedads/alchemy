# Alchemy base adoption rule retained by AI Access v0.6

The common `alchemy_objects_v0.7` base belongs on behavioural service objects, not on narrow provider-neutral DTOs.

`AIProviderAdapterBase` and `AIProviderRuntimeCapability` inherit `AlchemyObject` and obtain lifecycle/contracts/instrumentation facilities. `AIProviderRequest`, usage/reply, tool definition/call and structured-message DTOs remain plain values. This is intentional: expanding the provider input objects with a behavioural/security surface would weaken the authority boundary for no business benefit.

Runtime Registry qualification captures the minimal Alchemy base source closure inside each immutable generated provider artifact. The AI Access package itself does not vendor Runtime Registry, WLU, Crypto or Alchemy Objects source.
