# The_Oracle — Action Value v2

`THE_ORACLE` remains an ordinary, non-psychic player.  Its advantage is the
persistent experiment database, not hidden current-hand information.

v2 replaces the original winner-only rule with signed action attribution.

Historical source:
- completed ordinary-player hands from all prior experiments;
- completed ordinary-player hands earlier in the current experiment;
- psychic actions remain excluded.

Credit assignment:
- CALL and RAISE inherit signed bankroll outcome, normalized by starting stack;
- later actions receive stronger attribution than early setup actions;
- high-chip commitments receive stronger positive or negative attribution;
- CHECK receives weaker attribution;
- FOLD is treated as damage limitation: a cheap fold receives modest positive
  credit instead of being labelled bad merely because folded hands cannot win.

At decision time Oracle compares same-street / same-facing-state examples and
weights them by similarity in equity and pot odds.  Sparse evidence is shrunk
toward a conservative poker prior.

Current-state safety overrides remain deliberately present, so a historical
winner's heroic all-in does not by itself teach Oracle to call a large bet with
insufficient current equity.

The model refreshes before every Oracle decision.  Because only completed
`hand_result` rows are admitted, it can learn from hands that finished earlier
in the same casino without seeing the future of the current hand.

Model identifier:

    ORACLE_ACTION_VALUE_V2

## v0.7.25 database boolean boundary repair

NoSQLServer can return BOOLEAN values through SQL rows as textual `TRUE` /
`FALSE`. ooRexx does not accept the literal string `FALSE` as the expression
following `IF`; it requires logical `0` or `1`.

Oracle history loading now normalizes the SQL value to text and treats only
`TRUE` or `1` as psychic. This repair applies to every Oracle history scan and
does not change the model semantics.

## v0.7.26 ooRexx RESULT-variable repair

`RESULT` / `result` is special in Rexx and can be overwritten by calls or
message activity. `OracleHistoryModel~refresh` incorrectly used `result` as an
ordinary persistent local directory while reading historical hand outcomes.

The local is now named `handOutcome` throughout the model. No model semantics
changed.
