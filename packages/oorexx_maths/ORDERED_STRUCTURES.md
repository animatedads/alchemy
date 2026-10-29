# Finite ordered structures — ooRexx Maths v0.20

Maths v0.20 adds `.MathFiniteChain`, a finite totally ordered set represented by an explicit ascending value sequence. The object owns only mathematical order; consumers own the meaning of labels.

The API exposes `contains`, `rank`, `compare`, strict/non-strict comparisons, `min`/`max`, lattice aliases `meet`/`join`, `bottom`, `top`, and a stable canonical representation. Duplicate labels and unknown comparison operands fail closed.

Reasoned Thought may represent an admitted evidence-priority policy such as `STYLOMETRIC < TESTIMONY < DOCUMENTARY < PROVENANCE` with this object. Maths does not decide evidence authenticity, warrant validity, binding scope, support/rebut/undercut semantics, assertibility or settlement.
