# NoSQLServer v0.85 — precision-independent INTEGER validation

World intention qualification exposed a real v0.84 boundary: `DatabaseColumn~coerce`
and typed/prepared INTEGER validation used `DATATYPE(value,"W")`. Under the default
Rexx numeric precision, valid 10-digit integer spellings could be rejected even though
the database stores integer values as exact text.

v0.85 moves INTEGER validation to `NoSQLIntegerSupport`, which validates the lexical
integer form directly and therefore does not depend on ambient/package `NUMERIC DIGITS`.
The same validator is used by:

- table-column coercion;
- `DatabaseValue~integer`;
- prepared INTEGER parameter rendering.

INTEGER relational comparison also uses exact sign/magnitude comparison rather than
Rexx numeric coercion, preventing 10+ digit values from comparing equal merely because
an activation has insufficient numeric precision.

The forcing regression stores and retrieves `1277558000`, performs predicates/order over
10-digit values, and sends the same value through a typed prepared parameter.

The World qualification's temporary `Population DECIMAL` projection remains a valid
qualification workaround for v0.84. It must not be interpreted as changing the domain
meaning of population from an integer-valued quantity.

This change does **not** impose a new 32-bit range limit on NoSQLServer `INTEGER`.
NoSQLServer historically accepted integral text without a declared width, and the DB2
personality separately avoids claiming DB2 range/precision parity. v0.85 repairs the
precision-dependent rejection without silently narrowing that existing domain.
