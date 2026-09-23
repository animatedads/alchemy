# dev1 qualification gates

1. Construct box(41); read 41.
2. Increment; read 42.
3. Alias it; identities match.
4. Mutate alias; original observes mutation.
5. Close through one alias; all aliases observe closed state; repeated close succeeds.
6. CALLMETHOD into a live cREXX `on_value(.int)`.
7. `on_value` calls `alchemytest.nested_add_one` while the outer RXPA call is active.
8. Outer invocation resumes with the typed result.
9. Repeat nested path.
10. Negative integer callback result remains an ordinary result.
11. Callback signal propagates as a signal.
12. A -> RXPA -> B -> RXPA -> C with distinct sentinel locals.
13. Retain/finalize accounting balances at teardown.
14. Use-after-close fails closed.

Never retain an `rxpa_attribute_value` beyond its active RXPA invocation.
Persistent callback rooting is outside dev1.
