# Proof planner — ooRexx Maths v0.8

## Principle

The planner answers two different questions separately:

1. **What routes could establish this claim?** (`.MathProofPlan`)
2. **What did those routes actually establish?** (`.MathProofAttempt` + `.MathProof`)

It never silently changes the claim to suit an available provider.

## Example: solve residual

```rexx
claim = .MathClaim~satisfiesEquation('1E-45')

standard  = x~prove(claim, .nil, .MathProofPolicy~standard)
certified = x~prove(claim, .nil, .MathProofPolicy~certified)
strong    = x~prove(claim, .nil, .MathProofPolicy~strong)
```

For a normal decimal solve:

- STANDARD: numerical residual obligation;
- CERTIFIED: exact rational residual over retained values;
- STRONG: exact residual obligation + numerical residual obligation + independent reproduction SUPPORT route.

The support route has its own claim (`INDEPENDENT_REPRODUCTION`) because that is not logically equivalent to the equation residual claim.

## Ill-conditioned example

For the binary64 10x10 Hilbert regression and a loose residual tolerance:

- exact represented-value residual: PROVED;
- numerical residual: PROVED;
- independent solution reproduction: DISAGREEMENT.

Therefore:

- `CERTIFIED` => `PROVED / EXACT_BOUND_CERTIFIED` for the scoped residual claim;
- `STRONG` => `INDETERMINATE / CORROBORATION_REQUIRED` because the requested independent support failed.

This is intentional, not a contradiction.

## Symbolic example

For `2*x - 2*x = 0` under STRONG:

- SymPy exact-zero simplification: PROVED;
- local ooRexx structural rewrite: PROVED;
- final proof: PROVED with materially different verification evidence.

For `(x+1)*(x-1) = x**2-1`:

- SymPy: PROVED;
- small local rewrite set: INDETERMINATE;
- CERTIFIED: PROVED (a valid symbolic certificate exists);
- STRONG: INDETERMINATE / CORROBORATION_REQUIRED (the requested second route could not establish it).

## Scope discipline

A route's guarantee is part of the route, not inferred from the provider's brand. `EXACT_BOUND_ON_REPRESENTED_VALUES` is deliberately narrower than “the original user input was exact”. `RIGOROUS_BALL_ENCLOSURE` is deliberately narrower than “N decimal digits are correct”. `INDEPENDENT_RECOMPUTATION` is deliberately narrower than “the answer is mathematically exact”.
