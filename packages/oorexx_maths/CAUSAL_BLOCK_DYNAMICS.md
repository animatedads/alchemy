# Causal block continuation — ooRexx Maths v0.14

The Physics guitar synthesis consumer no longer needs a private coupled integrator: v0.11 already supplies `MathSecondOrderLinearSystem`. The remaining loop is delayed and causal: mechanical state produces a pickup observation, the electrical/amplifier/speaker path produces acoustic pressure, and that pressure returns to the mechanics only after propagation delay.

Maths v0.14 therefore adds two domain-neutral state objects:

- `MathSecondOrderContinuation` — resumes a `MathSecondOrderLinearSystem` from the exact previous displacement/velocity/time boundary and uses the same selected PURE/REFERENCE/SCIPY provider as the wrapped system.
- `MathSampleDelayLine` — a bounded ring delay in samples, with snapshot/restore state and no interpretation of the sample values.

A consumer may safely batch a closed delayed loop when each block is no longer than the already-established minimum feedback delay. During such a block, no output generated inside the block can causally return as an input before the block ends. The domain package remains responsible for establishing that delay and for all pickup, amplifier, loudspeaker, air-path and force-coupling semantics.

This is not a guitar model in Maths and it is not permission to batch through zero-delay or shorter-delay feedback. If a consumer has an instantaneous algebraic loop, it needs an appropriate coupled solve rather than this delayed-block rule.
