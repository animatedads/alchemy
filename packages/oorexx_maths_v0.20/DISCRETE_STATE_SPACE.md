# Discrete linear state-space systems — ooRexx Maths v0.16

v0.16 adds a provider-neutral, checkpointable discrete-time linear state-space
object for sampled linear systems:

```text
x[k+1] = A x[k] + B u[k]
y[k]   = C x[k] + D u[k]
```

Maths owns only this recurrence, its numerical execution, evidence and
continuation state.  The caller owns the meaning of state, input and output
channels.  In particular, Maths does not define pickups, tone controls,
amplifiers, loudspeakers, circuits or acoustic paths.

## API

```rexx
ctx=.MathContext~binary64('AUTO')
sys=.Maths~discreteStateSpace(A,B,C,D,ctx)

trajectory=sys~process(inputRows,initialState)
y=trajectory~outputs
xFinal=trajectory~finalState
```

For chunked or journaled workloads:

```rexx
cont=sys~continuation(initialState)
a=cont~advance(block1)
snapshot=cont~snapshot
b=cont~advance(block2)
cont~restore(snapshot)
bAgain=cont~advance(block2)
```

`MathDiscreteStateSnapshot` retains the future-determining state vector and the
number of processed samples.  No wall-clock time is implied by the recurrence;
a consumer may associate samples with its own sample rate or simulation clock.

The sample convention is explicit: output is evaluated from the current state
and current input before the state advance:

```text
y[k]   = C x[k] + D u[k]
x[k+1] = A x[k] + B u[k]
```

## Exact and approximate domains

The PURE provider can execute the recurrence in the RATIONAL domain, retaining
exact arithmetic when A/B/C/D, initial state and input samples are rational.
DECIMAL contexts retain their declared Maths precision policy.

The NumPy provider is an explicitly BINARY64 path.  It executes a complete
input block through one Foreign Runtime call and returns selected output rows
plus the final state.  A SciPy context inherits this NumPy operation because no
SciPy-specific solver is needed for the recurrence.

## Workload-aware provider selection

The current Foreign Runtime path materializes ordinary ooRexx input/output rows
at the bridge.  That cost dominates tiny low-order filters.  Therefore an AUTO
BINARY64 context deliberately keeps state spaces with four or fewer states on
the PURE route, and also keeps workloads below a conservative state-work
threshold local.  Larger matrix-state workloads may select NumPy.

The threshold is a provider heuristic, not mathematical semantics.  Explicit
`PURE`, `NUMPY` or `SCIPY` contexts continue to mean exactly what the caller
requested.

Qualification on the supplied r13196 debug ooRexx and Foreign Runtime v0.22.6
recorded both sides of the crossover:

```text
2 states, 12,000 samples
  direct ooRexx scalar fixture   0.143071 s
  NumPy/Foreign block           15.644506 s
  native/scalar ratio            0.00915x

32 states, 1,200 samples
  generic PURE Maths             2.445634 s
  NumPy/Foreign block            0.154795 s
  native speedup                15.80x
```

These are bounded qualification-host measurements, not universal performance
claims.  They are retained specifically to prevent the library from treating
"native" as synonymous with "faster".
