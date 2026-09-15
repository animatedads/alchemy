# External reasoning budget

The PA has three deliberately separate accounting concerns:

1. **WLU ledger** — work reserved, settled, or released.
2. **Rate book** — a versioned `provider + model` rate translating settled
   micro-WLU into accounting microdollars.
3. **Hourly allowance** — the external-reasoning spending ceiling. The
   development default is 30,000 microdollars (`$0.03`) per hour.

WLU is not money. A provider planner must produce an admissible estimate before
the provider call. `LlmPaExternalBudgetAuthority~reserve` checks both the
hourly WLU ceiling and the money allowance. Only a successful reservation may
proceed to provider execution. On completion, settle with measured WLU; on a
non-executed or abandoned call, release the reservation.

The authority keeps an event ledger in memory and can persist the same events
as JSON lines when constructed with a ledger path. A fresh authority instance
replays reserve/settle/release events, retaining settled spend and any active
reservations across restart. Events contain provider/model and numeric
accounting metadata, never prompts or credentials. The production daemon must
provide a stable path in its runtime state directory.

The hourly window is UTC-clock based and rolls over automatically. Rates are
registered independently, for example:

```rexx
authority~registerRate("huggingface", "Qwen/Qwen3.8-27B:ovhcloud", 10000, "hf-2026-09")
authority~registerRate("deepseek", "deepseek-reasoner", 20000, "ds-2026-09")
```

The provider-specific WLU planner remains responsible for estimating the
request. The budget authority is the admission and accounting boundary; it
does not inspect model prose and it does not silently invoke a provider.
