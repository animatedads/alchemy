# Theoretical mathematics foundations — ooRexx Maths v0.19

v0.18 begins the theoretical-mathematics line. The objective is not to copy a catalogue of theorem names into Maths. The objective is to provide mathematical objects capable of representing structures, statements, proof authority, revisions, and eventually formal proof interoperability.

## Executable finite foundations

The first release deliberately starts with finite structures whose axioms can be checked completely:

- \`MathSet\` — finite extensional sets with membership, union, intersection, difference and subset predicates.
- \`MathMap\` / \`MathMapEntry\` — total maps between finite sets, with image, injective/surjective/bijective predicates and composition.
- \`MathRelation\` / \`MathOrderedPair\` — finite binary relations with inverse, reflexive, symmetric, transitive and equivalence predicates.
- \`MathFiniteBinaryOperation\` — a total closed operation table over a finite carrier.
- \`MathFiniteMonoid\` — executable associativity and identity checks.
- \`MathFiniteGroup\` — executable associativity, identity and inverse checks; commutativity and order are exposed.
- \`MathFiniteRing\` — additive abelian-group, multiplicative associativity and both distributive laws, with optional multiplicative identity.
- \`MathFiniteField\` — a finite commutative unital ring in which every nonzero element has a multiplicative inverse.
- \`MathGroupHomomorphism\` — checks operation preservation and exposes kernel, injectivity, surjectivity and isomorphism.

Representative use:

\`\`\`rexx
z2 = .Maths~set(.array~of(0,1))
add = .array~of( -
  .array~of(0,0,0), .array~of(0,1,1), -
  .array~of(1,0,1), .array~of(1,1,0))
mul = .array~of( -
  .array~of(0,0,0), .array~of(0,1,0), -
  .array~of(1,0,0), .array~of(1,1,1))

field = .Maths~finiteField(z2,add,mul,0,1)
say field~valid       -- 1
say field~order       -- 2
\`\`\`

The finite scope is intentional. A later abstract/algebraic layer can generalize carriers and operations without weakening the executable reference semantics established here.

## Mathematical statements and proof authority

\`MathStatement\` is revision-bearing. Specialized statement classes are:

- \`MathDefinition\`
- \`MathAxiom\`
- \`MathLemma\`
- \`MathTheorem\`
- \`MathCorollary\`
- \`MathConjecture\`

Statements retain an id, exact revision, text, assumptions, dependencies, proof artifacts and lifecycle state.

Current states include \`PROPOSED\`, \`PROVED\`, \`INDEPENDENTLY_CHECKED\`, \`FORMALIZED\`, \`DISPROVED\`, \`SUPERSEDED\`, and \`WITHDRAWN\`.

\`MathProofArtifact\` is bound to **one exact statement id and revision**. Attaching an artifact for another revision fails closed. Accepted artifact kinds are \`DERIVATION\`, \`INDEPENDENT_CHECK\`, \`FORMAL\`, and \`COUNTEREXAMPLE\`. A verified formal artifact promotes a statement to \`FORMALIZED\`; a verified counterexample moves it to \`DISPROVED\`.

This is deliberately separate from the existing numerical \`MathProof\` / \`MathClaim\` machinery. Numerical evidence and theorem-level proof provenance can interoperate later, but neither is silently promoted into the other.

## Revision catalogue

\`MathTheoryCatalogue\` retains multiple revisions under one stable statement id:

\`\`\`rexx
catalogue = .Maths~theoryCatalogue
catalogue~add(.Maths~theorem('T.EXAMPLE','first statement',.nil,1))
catalogue~add(.Maths~theorem('T.EXAMPLE','corrected statement',.nil,2))

say catalogue~latest('T.EXAMPLE')~revision  -- 2
say catalogue~revision('T.EXAMPLE',1)~text
\`\`\`

Historical revisions remain addressable. A later correction never causes a proof artifact for revision 1 to become evidence for revision 2.

## Boundary

v0.18 does **not** claim to implement the full foundations of abstract algebra, topology, measure theory, analysis, category theory or formal proof. It establishes the reusable substrate those areas require.

The next natural layers are:

1. general algebraic structures and homomorphisms beyond finite carriers;
2. polynomials, ideals, modules and vector spaces;
3. sequences, limits and convergence propositions;
4. topology/metric-space objects;
5. measure/probability structures;
6. formal proof adapters, beginning with Lean, as external proof authorities rather than embedded truth by fiat.

## v0.19 algebra continuation

v0.19 follows the finite reference structures with exact rational-field algebra: Q[x] polynomials with Euclidean algorithms, Q^n vector spaces and exact linear maps. This is the first step toward modules, ideals, algebraic extensions and the algebraic vocabulary required by number theory and geometry. See \`ALGEBRA.md\`.
