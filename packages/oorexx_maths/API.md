
## v0.16 discrete state-space systems

```rexx
sys=.Maths~discreteStateSpace(A,B,C,D,ctx)
tr=sys~process(inputRows,initialState)
cont=sys~continuation(initialState)
tr2=cont~advance(nextInputRows)
snap=cont~snapshot
cont~restore(snap)
```

`MathDiscreteStateSpaceSystem` evaluates `y[k]=C*x[k]+D*u[k]` followed by `x[k+1]=A*x[k]+B*u[k]`. `MathDiscreteStateSpaceTrajectory` exposes `outputs`, `finalState`, `sampleCount` and `outputChannel(n)`. `MathDiscreteStateContinuation` retains state and processed-sample count across blocks.  Channel semantics and sample timing remain consumer-owned.

# ooRexx Maths v0.14 API summary

## Core factories (`.Maths`)

- `~integer(value, context=.nil)` -> canonical `.MathInteger`
- `~fraction(numerator, denominator, context=.nil)` -> `.MathFraction` or `.MathInteger` after exact reduction
- `~rational(numerator, denominator=1, context=.nil)` -> canonical exact rational subtype
- `~exact(value, context=.nil)` -> exact integer, fraction, finite/scientific decimal, or recurring-decimal parser
- `~decimalExpansion(value, maxDigits=10000, context=.nil)` -> `.MathDecimalExpansion`
- `~rationalFromDecimal(text, context=.nil)`
- `~matrix`, `~vector`, `~complex`, `~identity`, `~variable`, `~constant`, `~assumptions`
- `~rationalMatrix`, `~rationalVector`
- provider registry/query methods
- `~dtype(name)`, `~quantization(name, blockSize=64, computeType='FLOAT32', nested=.false)`, `~quantize(value, scheme=.nil)`, `~mixedPrecision(...)`
- `~planProof(value, claim=.nil, assumptions=.nil, policy=.nil)`
- `~prove(value, claim=.nil, assumptions=.nil, policy=.nil)`

## Exact numbers

`.MathExactNumber` is the exact-value base.

`.MathRational` supplies `numerator`, `denominator`, exact `+ - * / **`, exact `= \\= < > <= >=`, `abs`, `compareTo`, proof support, `toDecimal`, `decimalExpansion`, and formatting.

`.MathInteger` is the canonical denominator-one subtype. `.MathFraction` is the canonical proper-rational subtype.

Exact arithmetic evidence records the unreduced operation result and canonical result. `1/3 + 1/3 + 1/3` therefore retains `unreduced=3/3`, `canonical=1`, while returning `.MathInteger(1)`.

## `.MathDecimalExpansion`

Exact base-10 representation of a rational value.

Methods:

- `string` -> exact finite/recurring notation, e.g. `0.1(6)`
- `integerPart`
- `nonRepeatingDigits`
- `repeatingDigits`
- `periodLength`
- `isTerminating`
- `isRecurring`
- `isExact`
- `source` / `toRational`
- `canonical`
- `evidence`
- `prove` -> for `IS_EXACT`, replay the expansion through an independent exact inverse conversion and require exact rational equality

`MathRational~format('EXPANSION')` and `~format('REPEATING')` render this notation. `~format('DECIMAL', digits)` remains an explicitly rounded presentation boundary.

`.Maths~exact()` accepts recurring notation such as `0.(3)`, `0.1(6)`, and `3.(142857)` and converts it algebraically to a canonical exact rational. `0.(9)` canonicalizes to `.MathInteger(1)`.

Expansion generation is exact integer long division. `maxDigits` is a resource bound: if a complete finite expansion or recurring cycle is not discovered within it, the operation fails rather than returning a truncated value falsely labelled exact.

## Context

- `.MathContext~decimal(digits=50, provider='PURE')`
- `.MathContext~binary64(provider='NUMPY')`
- `.MathContext~rational(provider='PURE')`
- `context~verificationContext`

## Evidence / derivation

`.MathPathStep`, `.MathEvidence`, `.MathDerivation`, and `.MathSeal` retain operation/provider/algorithm/domain/precision/representation/guarantee/lineage/check data.

## Claims / proof planner

Policies: `STANDARD`, `STRONG`, `CERTIFIED`, `DIAGNOSTIC`.

`.MathProofPlan`, `.MathProofRoute`, `.MathProofAttempt`, and `.MathProof` retain planned/executed proof paths. Claims include independent reproduction, equality, equation satisfaction, digits of accuracy, exactness, enclosure, and containment.

## Quantization / mixed precision

`.MathDType` models storage/compute representations such as `INT8`, `UINT8`, `FLOAT16`, `BFLOAT16`, `FLOAT32`, `FLOAT64`, and `RATIONAL`.

`.MathQuantizationCodebook` retains named code values and lineage. `~nf4` returns the 16-value bitsandbytes NF4 reference codebook as exact decimal rationals.

`.MathQuantizationScheme`:

- `~int8(blockSize=64, computeType='FLOAT32')`
- `~nf4(blockSize=64, computeType='BFLOAT16', nested=.false)`
- `name`, `bits`, `blockSize`, `storageType`, `computeType`, `codebook`, `nested`, `rounding`, `providerHint`, `canonical`

`.MathMatrix~quantize(scheme)` and `.MathVector~quantize(scheme)` return `.MathQuantizedMatrix` / `.MathQuantizedVector`. These retain payload, `.MathQuantizationState`, exact represented-source snapshots, evidence and derivation. `~dequantize(context=.nil)` reconstructs through an explicit path. Arithmetic operators on quantized values currently dequantize explicitly before using the ordinary Maths operation.

`.MathClaim~quantizationErrorBelow(tolerance)` is proved or disproved by exact rational replay over the retained represented source values. A successful proof strength is `EXACT_BOUND_CERTIFIED`; its scope is the declared quantization state, not unknown pre-Maths values or model-level accuracy.

`.MathPrecisionPolicy` and `.MathMixedPrecisionPlan` provide size thresholds, protected semantic roles, exact-value preservation, high-precision island dtype, and optional outlier thresholds.

## Vector / matrix

`.MathVector`: `+ - *`, index access, dot via `*`, evidence/derivation/proof.

`.MathMatrix`: `+ - *`, transpose, inverse, solve, row/column/index access, identity factory, evidence/derivation/proof.

Under `RATIONAL`, vectors/matrices retain `.MathInteger` / `.MathFraction` values exactly.

## Symbolic / interval / ball

`.MathExpression` subclasses use overloaded arithmetic. `~interval(bounds)` uses MPMATH-IV; `~ball(bounds)` uses FLINT-ARB when registered.

## Crypto

`MathCryptoEvidence.cls` provides SHA-256 sealing and verification for canonical evidence and full proof records.



## v0.11 second-order linear dynamics

Factories:

- `.Maths~secondOrderLinearSystem(M,C,K[,context])`
- `.Maths~secondOrderSystem(M,C,K[,context])` (alias)

`.MathSecondOrderLinearSystem` models the generic mathematical system `M*x'' + C*x' + K*x = f(t)` with constant square matrices. Public methods include `massMatrix`, `dampingMatrix`, `stiffnessMatrix`, `dimension`, `context`, `withContext`, `integrate`, and `integrateFinal`.

`integrate(x0,v0,dt,steps,forces=.nil,startTime=0,method='NEWMARK_AVERAGE_ACCELERATION')` returns `.MathSecondOrderTrajectory`. `integrateFinal(...)` returns `.MathSecondOrderState` and is preferred when only the terminal state is required.

Supported methods are `NEWMARK_AVERAGE_ACCELERATION` (`NEWMARK` alias; beta=1/4, gamma=1/2) and `SYMPLECTIC_EULER`. Forces may be nil (zero), a constant `MathVector`, or a `(steps+1) x dimension` `MathMatrix`.

`.MathSecondOrderState` exposes `time`, `displacement`, `velocity`, `acceleration`, `evidence`, `derivation`, and `maxAbsDifference`. `.MathSecondOrderTrajectory` exposes retained time/state matrices, `stepCount`, `dimension`, `state(index)`, `initialState`, `finalState`, evidence/derivation and proof-compatible maximum difference.

A BINARY64 `SCIPY` context selects the accelerated NumPy/SciPy provider when available. RATIONAL/PURE and REFERENCE paths execute in ooRexx and support exact discrete arithmetic where closed. Independent-reproduction proofs replay the same declared integrator through a different provider/linear-solver implementation.

## v0.9 reusable numerical foundations

### Scalar factories (`.Maths`)
- `~pi(context=.nil)`
- `~sqrt(value, context=.nil)`
- `~sin`, `~cos`, `~tan` (radian scalar input)
- `~exp`, `~ln`, `~log10`
- `~atan(value[,context])` -> `.MathAngle`
- `~atan2(y,x[,context])` -> `.MathAngle`
- `~scalarResult(operation,value[,context])` -> evidence-bearing `.MathScalarResult`

### Interpolation
- `.Maths~linearInterpolator(coordinates,values[,context,boundaryPolicy])` -> `.MathLinearInterpolator1D`
- `.Maths~bilinearInterpolator(xCoordinates,yCoordinates,valueRows[,context,boundaryPolicy])` -> `.MathBilinearInterpolator2D`
- policies: `FAIL` (default), `CLAMP`, `EXTRAPOLATE`
- `~evaluate`, `~evaluateResult`

### Sampled/spectral analysis
- `.Maths~sampledSeries([context])` -> `.MathSampledScalarSeries`
- `~append`, `~count`, `~duration`, `~mean`, `~rms`, `~isUniform`
- `~fourierComponent(frequency)` / `~component`
- `~spectrum(frequencies)`
- `.MathSpectralComponent`: `frequency`, `amplitude`, `cosineComponent`, `sineComponent`, `sampleCount`

### Quadratics
- `.Maths~quadratic(a,b,c[,context])` -> `.MathQuadraticEquation`
- `~discriminant`, `~solve`
- `.MathQuadraticRoots`: `root1`, `root2`, `roots`, `hasRealRoots`, `smallestPositive([epsilon])`
- real numerical solve uses the stable-q formulation; rational perfect-square roots stay exact; negative discriminants use `.MathComplex` outside the rational domain.

### Simultaneous linear systems
- `.Maths~linearSystem(coefficients,rhs[,context])` -> `.MathLinearSystem`
- `~coefficientMatrix`, `~rhs`, `~solve`, `~residual(solution)`
- delegates to established `.MathMatrix~solve`; no second matrix solver is introduced.

## v0.8 3D API

### Angles
- `.MathAngle~degrees(value[,context])`
- `.MathAngle~radians(value[,context])`
- `~reduced`, `~radiansValue`, `~degreesValue`, `~sin`, `~cos`, `~tan`, `~half`

### Vectors and matrices
- `.MathVector3~new(x,y,z[,context])`: `+`, `-`, `*` (dot/scalar), `~cross`, `~norm`, `~normalized`
- `.MathVector4~new(x,y,z,w[,context])`
- `.MathMatrix3`, `.MathMatrix4`; `MathMatrix4~toRowMajorArray`, `~toColumnMajorArray`

### Quaternion
- `.MathQuaternion~fromAxisAngle(axis,angle[,context])`
- `+`, `-`, `*` Hamilton product / scalar / Vector3 rotation
- `~norm`, `~normalized`, `~conjugate`, `~inverse`, `~rotate`, `~toMatrix3`

### Conventions
- `.Math3DConvention~openGL`
- `.Math3DConvention~vulkan`
- `.Math3DConvention~directX`

### Transforms
- `.MathTransform3D~identity`
- `~translation`, `~scale`, `~rotation`, `~lookAt`
- `*` transform composition / point transform
- `~transformPoint`, `~transformDirection`, `~inverse`
- `~toRowMajorArray`, `~toColumnMajorArray`

### Projection
- `.MathPerspective~new(fovY,aspect,near,far[,context,convention])`
- `.MathOrthographic~new(left,right,bottom,top,near,far[,context,convention])`

### Geometry
- `.MathRay3D~new(origin,direction)` / `~pointAt(t)`
- `.MathPlane3D~new(normal,offset)` / `~fromPointNormal(point,normal)` / `~signedDistance(point)`


## Native signal / modal acceleration (v0.11)

```rexx
ctx = .MathContext~binary64('NUMPY')

wave = .Maths~oscillatorBank(amplitudes, frequenciesHz, decayRates, phases, sampleRate, ctx)~render(samples)
filtered = wave~convolve(impulseResponse)

series = .Maths~sampledSeries(ctx)
/* append(time,value) ... */
spectrum = series~rfft

y = matrix * vector
```

`MathDampedOscillatorBank~render` is chunk-addressable through its `startSample` argument, so long-running simulations can render deterministic consecutive blocks without resetting phase/time. Long NumPy convolution switches to zero-padded RFFT convolution; its independent witness remains direct high-precision convolution. `MathFFTResult` uses a direct half-DFT as its independent REFERENCE witness.

Native acceleration does not broaden the precision contract. These NumPy routes require BINARY64 context; higher-precision DECIMAL and exact RATIONAL callers remain on the appropriate provider.


## Named mathematical constants

`Maths~namedConstant(name, context=.nil)` is the context-sensitive constant registry. It is distinct from `Maths~constant(value, context)`, which remains the symbolic/value expression constructor. Evaluated registry values are cached by canonical constant name, numeric domain, and working precision.

The v0.13 foundational catalogue publishes:

- `ZERO`, `ONE`, `IMAGINARYUNIT` — exact structural values; valid in rational contexts too.
- `PI`, `TAU`, `E`, `EULERMASCHERONI` — transcendental/analysis constants.
- `GOLDENRATIO`, `SQRT2` — algebraic constants evaluated from their authoritative derivations.

Aliases include `0`, `1`, `i`, `2pi`, `phi`, `pythagoras`, `gamma0`, and conventional long names. Alias resolution occurs before caching, so aliases share the same context cache entry.

```rexx
ctx = .MathContext~decimal(70)
pi    = .Maths~namedConstant('pi', ctx)
tau   = .Maths~namedConstant('tau', ctx)
phi   = .Maths~namedConstant('phi', ctx)
gamma = .Maths~namedConstant('eulerMascheroni', ctx)
```

Discovery and metadata are public:

```rexx
names = .Maths~constantNames
info  = .Maths~constantInfo('phi')
if .Maths~hasNamedConstant('sqrt2') then say info['definition']
```

Metadata records canonical name, aliases, category, mathematical kind, computability, definition, precision capability, supported number domains, cache policy, and registry provenance. Derived constants such as `TAU`, `GOLDENRATIO`, and `SQRT2` are recomputed from their mathematical definitions at the requested context rather than promoted from a lower-precision cached decimal.

`EULERMASCHERONI` currently uses a sealed 250-digit registry seed and fails closed if the requested working precision exceeds that capability. This prevents the registry from claiming digits it does not possess.

`Maths~pi(context)` remains a convenience alias into the same registry.
## v0.14 causal block continuation

```rexx
delay=.Maths~sampleDelayLine(delaySamples,initialValue,ctx)
continuation=.Maths~secondOrderContinuation(system,x0,v0,startTime,'SYMPLECTIC_EULER')
trajectory=continuation~advance(dt,steps,forceHistory)
final=continuation~advanceFinal(dt,steps,forceHistory)
```

`MathSampleDelayLine` provides bounded `push`, block `process`, `snapshot`, `restore`, and `reset`. `MathSecondOrderContinuation` retains displacement, velocity and time while delegating every block to the wrapped system's selected provider. These are mathematical state/causality primitives only; domain feedback semantics remain with the caller.


## v0.15 second-order input/output projection

```rexx
base=.Maths~secondOrderSystem(M,C,K,ctx)
io=.Maths~secondOrderInputOutputSystem(base,B,Hx,Hv,ctx)
result=io~integrateProjected(x0,v0,dt,steps,inputHistory,startTime,'SYMPLECTIC_EULER')

result~outputs
result~finalState
```

The mathematical contract is `M*x''+C*x'+K*x=B*u` and
`y=Hx*x+Hv*x'`. Channel semantics belong to the caller.
