# Compatibility personalities

Compatibility packages belong here conceptually, but no vendor personality is claimed by v0.1-dev9.

A future AD/Entra compatibility lane may translate vendor attributes, controls, result conventions and object-class vocabulary into the native LDAP/Identity Directory model. It must not:

- make `sAMAccountName`, `objectGUID`, `userAccountControl` or any other Microsoft field a required semantic-core field;
- infer platform Permission from a successful vendor authentication exchange;
- replace Secret Broker with vendor credential materialization;
- replace key-lifetime authority with a vendor directory attribute;
- silently map an unsupported vendor semantic to an approximately similar platform concept.

Where an exact mapping does not exist, the edge package must preserve the external value as an explicit extension and report the mapping limitation.
