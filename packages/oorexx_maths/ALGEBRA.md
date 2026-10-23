# Exact algebra — ooRexx Maths v0.19

v0.19 adds the first non-finite algebra layer on top of the executable finite structures introduced in v0.18. The initial coefficient/scalar field is Q so closure, equality, polynomial algorithms and linearity are exact.

## Rational field

\`MathRationalField\` is the structural field authority for existing \`MathRational\` / \`MathInteger\` values. \`coerce\`, addition, subtraction, multiplication, division, negation and inverse retain the existing exact rational representation and evidence semantics.

## Polynomial ring Q[x]

\`MathPolynomialRing\` constructs univariate \`MathPolynomial\` values. Coefficients are stored from degree zero upward and trailing exact zeros are canonicalized away. Supported operations include addition/subtraction, scalar and polynomial multiplication, Horner evaluation, formal derivative, Euclidean quotient/remainder, divisibility, monic normalization and Euclidean gcd.

The zero polynomial has degree -1. Polynomial equality is structural mathematical equality after canonical coefficient trimming, not object identity or rendered-text equality.

## Finite-dimensional vector spaces

\`MathRationalVectorSpace(n)\` is Q^n. Its elements are existing \`MathVector\` objects under \`MathContext~rational\`; basis construction, zero, addition and scalar multiplication therefore reuse the established Maths exact-number and vector implementation.

\`MathLinearMap\` is a linear transformation represented by an exact rational matrix with rows equal to the target dimension and columns equal to the source dimension. Application and composition delegate to existing exact matrix/vector multiplication.

## Boundary

This release does not yet claim general modules over arbitrary rings, multivariate polynomial rings, ideals, quotient rings, polynomial factorization, algebraic extensions, tensor products or infinite-dimensional vector spaces. The point is to establish exact executable reference semantics before widening those abstractions.
