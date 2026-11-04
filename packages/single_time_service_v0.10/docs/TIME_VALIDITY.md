# Time validity for HTTPS, LDAP, SMTP/IMAP and internal services (v0.10)

The independent `TimeClockInterval` and `TimeValidityWindow` classes provide a **pure temporal predicate**, not a certificate verifier or a clock synchronizer.

X.509 notAfter encodes an inclusive validity instant. If this component is used for certificates, a separately qualified parser must normalise the end onto the exclusive POSIX-second boundary (for whole-second encoding, add one second), while preserving overflow checks.

Inputs: `notBefore` and exclusive `notAfter` on the POSIX seconds scale, plus an explicit bounded UTC interval `(lower, upper)` from a caller-selected clock authority. Endpoints with ASN.1 GeneralizedTime or UTCTime must parse and normalize their input with independently qualified crypto/X.509 code. This API does not do it.

Outputs: `DEFINITELY_TOO_EARLY`, `DEFINITELY_EXPIRED`, `INSIDE_TIME_WINDOW`, or `INDETERMINATE`. An interval that crosses either boundary is `INDETERMINATE`, never silently accepted. `timeCriterionSatisfied` is true only when the complete interval fits and the caller already marked the source `POLICY_AUTHORISED`; `authorisesUse` remains **false** regardless. Only the security owner can combine this predicate with signature chain, private CA, revocation, host identity, LDAP authorization, issuer policy, clock authentication, and application context.

`POLICY_AUTHORISED` is an injected policy assertion, not proof of secure NTP/PTP, cross-node consensus or monotonic time. The output does not authenticate the source. Do not expose a remote endpoint accepting an arbitrary client-provided clock as a certificate admission oracle. No automatic certificate admission, retry, network access, historical rule extrapolation or Queue Fabric dispatch is performed.

A typical consumer flow is: acquire authenticated clock interval from the platform's authority -> verify source authorization against local policy -> parse X.509 validity with crypto owner -> call `assess` -> reject anything except `INSIDE_TIME_WINDOW` **and** policy-authorised clock -> independently verify the remaining TLS/LDAP/mail security requirements.
