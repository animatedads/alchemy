# Model escalation policy

Gemma is the default PA model because she is local, cheap, and close to the
PA's durable state. A stronger model is an exception path for work Gemma
explicitly marks with `THINKING_REQUIRED|...` or `NEEDS_DEEPER_REASONING`.

The provider chain is injected into `LlmPaWorker`; providers are not selected
by arbitrary model prose. A fallback receives the same grounded prompt plus a
short instruction to reason more carefully. If the fallback fails, the PA
returns Gemma's bounded answer and records the escalation failure.

## Provider order

The intended order is configurable per deployment, with local Gemma first:

1. local `gemma2:2b` through Ollama;
2. a configured stronger provider such as DeepSeek, Grok, Claude, ChatGPT, or
   Hugging Face inference;
3. no provider, which means the PA must state that deeper reasoning is
   unavailable rather than pretending.

Paid providers require explicit deployment configuration, bounded output
tokens, and a per-request escalation decision. Keys remain outside prompts,
memory, queues, audit text and continuity briefs. The currently available key
locations are deployment secrets, not source defaults:

    /home/hc3/deepseek_key.txt
    /home/hc3/grok.api.key
    /home/hc3/huggingface.key

No provider is contacted merely because its key exists. Provider adapters must
also preserve the PA's authority boundary: model output can propose work, but
only the injected broker executes tools.

## Gemma behavior notes

- She is sometimes overly cheerful and adds service pleasantries; prompts ask
  for concise operational answers.
- With `gemma2:2b`, strict one-line control formats can drift or be prefixed by
  explanation; parsers tolerate harmless formatting but validate semantics.
- She may misclassify an explicit future reminder as recall; the PA has a narrow
  deterministic guard for numeric units and typos such as `secdonds`.
- Exact identifiers and nonces must be copied character-for-character; this is
  part of the live qualification.
- She must not infer live state, authority, responsibilities or command syntax
  from a friendly prompt or remembered metadata.
