# Security Effect v0.13 — invocation freshness

## Purpose

Method/object binding alone is insufficient when business arguments or session context can change between Security assessment and execution. v0.13 makes the Security assessment evidence-specific to one exact invocation.

## Evidence

`SecurityInvocationEvidence` is sealed and includes:

- unique invocation id;
- deterministic business argument identity;
- deterministic invocation-context identity;
- observation time;
- semantic identity over all of the above.

The domain integration is responsible for meaningful deterministic identities (for example a Staff Banking admission payload identity or a payment amount/currency/beneficiary identity). Raw arguments need not be copied into the Security layer.

## Fixed freshness policy

`SecurityInvocationPolicy` is sealed/versioned and declares maximum evidence age, tolerated future skew, whether argument and context identities are mandatory, and whether the binding is single-use. It remains a fixed reviewable algorithm; no runtime LLM is consulted.

## Guard semantics

`SecurityInvocationGuard` fails closed on exact evidence mismatch, missing required identities, excessive future skew, expiry and replay of consumed single-use bindings. Consumption happens only after Access Permissions returns an actual allow decision.

## Enforcement path

The invocation-aware Alchemy adapter creates fresh evidence from the live METHOD checkpoint and live arguments. A Security resolver must assess that exact evidence. The adapter validates the assessment before Access Permissions is called; successful Permission authority consumes the binding before the Security Manager permits method execution.

This preserves the institutional separation: **Bouncer supplies fresh security meaning; Permissions supplies exact authority; Security Manager supplies enforcement.**
