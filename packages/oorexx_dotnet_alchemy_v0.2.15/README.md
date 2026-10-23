# ooRexx .NET Alchemy v0.2.15

Maintainability and live CLR-member interposition candidate, based on the phone-qualified v0.2.14 generation/Inspector baseline.

## Authority model

CLR object identity and `System.Type` remain authoritative. Rexx member overrides, Inspector Clouseau, Logging, and future observers are cooperative providers attached to the shared method-interposition coordinator; they do not own or save the underlying CLR implementation.

The managed reflection bridge resolves the current CLR member at invocation time. Removing a Rexx override therefore reveals the CLR target that is current when the next call occurs, rather than restoring a stale target captured when the override was installed.

## v0.2.15 qualification boundary

The first new torture sequence is:

1. publish C# `SPEAK` generation 1;
2. install a cooperative Rexx override;
3. verify calls expose the Rexx result;
4. publish C# generation 2 while the override remains installed;
5. verify the Rexx result still wins;
6. remove only the Rexx provider;
7. verify the next call exposes C# generation 2;
8. verify the physical coordinator remains singular.

Expected probe:

```text
override-reveal-current=REXX-OVERRIDE|2|REXX-OVERRIDE|C#-UNDER-OVERRIDE-2|1
REXX OVERRIDE REMOVAL REVEALS CURRENT CLR TARGET PASS
```

This is intentionally distinct from replacing a saved Rexx `Method`: no stale CLR target is stored by the override mechanism.
