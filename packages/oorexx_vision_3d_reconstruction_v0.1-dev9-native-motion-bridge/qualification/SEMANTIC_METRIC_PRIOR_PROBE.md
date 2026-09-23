# Semantic metric prior probe — 2026-09-22

The dev5 layer was introduced after the hall-first three-bodycam probe established that floor/support registration is strong enough to recover a sparse building skeleton before dense object reconstruction.

The next problem is metric scale and plan tightening.  The supplied interior stills show ordinary wall fixtures, door leaves, radiators and room transitions.  Dev5 does **not** assert those objects merely from pixels.  It provides an explicit place for an upstream Vision/Line Assessment observation to become a defeasible semantic hypothesis and contribute a dimensional prior.

Initial practical priors supplied for the experiment include:

- modern internal door: width >= 0.76 m, height >= 1.97 m, leaf thickness about 0.04-0.05 m;
- hall width >= 0.80 m, with room width expected to exceed hall width;
- UK double wall socket approximately 0.15 m across;
- square light switch approximately 0.10 m x 0.10 m;
- ordinary-interior ceiling context about 8-12 ft, explicitly not global or hard because historic/large-volume spaces can differ radically;
- bare lightbulb approximately 0.07 m diameter when directly visible;
- ordinary radiator stand-off >= about 0.025 m and body depth about 0.05-0.12 m.

The model separates four evidence grades:

1. DIRECT_OBSERVATION
2. HIGH_CONFIDENCE_SEMANTIC_GUESS
3. ARCHITECTURAL_PRIOR
4. WEAK_GUESS

A socket-like wall rectangle can therefore provide an approximate local scale anchor without becoming an observed fact.  Door/hall minima constrain lower scale.  Approximate fixture dimensions contribute nominal scale.  Contextual ceiling ranges are opt-in per space.

This probe is architectural qualification, not a claim that the current bodycam floor plan has already been measured to centimetres.
