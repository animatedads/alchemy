# Approximate flat topology qualification note

Source: user-supplied hand-drawn approximate floor plan in the active bodycam
reconstruction session, compared with the three bodycam traversals.

This note intentionally extracts connectivity, not scale.

Provisional topology:

    HALL  <---->  LIVING / MAIN SPACE  <---->  KITCHEN
      |
      +------->  BATHROOM

The sketch also marks sofas/furniture in the main room.  Those marks are useful
for later object-registration checks but are not building-boundary authority.

The sketch is explicitly approximate and is not assumed to be drawn to scale.
It therefore must not directly provide wall lengths, room widths or opening
widths.  Those remain products of the Vision floor/edge solve plus metric
anchors and priors.

Metric priors available to the solver from the same qualification conversation:

- modern internal doorway width: practical lower bound 0.76 m;
- modern internal doorway height: practical lower bound 1.97 m;
- internal door leaf thickness: about 0.04--0.05 m;
- ordinary hall width: practical lower bound 0.80 m;
- UK double wall socket: about 0.15 m across;
- square light switch: about 0.10 m x 0.10 m;
- typical bare bulb: about 0.07 m diameter when the bulb itself is visible;
- ordinary radiator: at least about 0.025 m wall stand-off and about
  0.05--0.12 m body depth;
- ordinary interior ceiling context: about 8--12 ft, explicitly defeasible per
  space (historic low rooms and large-volume rooms are known exceptions).

These are reconstruction priors, not universal building-code claims.
