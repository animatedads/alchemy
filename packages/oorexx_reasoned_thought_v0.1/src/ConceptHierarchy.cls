/*
 * Concept Hierarchy: the "tree of knowledge" layer under Reasoned Thought, for discussion over
 * UNIVERSALS ("all A are B"), not just flat propositions. (Tom's requirement, 2026-10-26.)
 *
 * A universal "all A are B" is a directed subsumption edge A -> B. Reasoning is:
 *   - transitivity:  A->B and B->C  gives  A->C (a derived universal; warrant = TRANSITIVITY)
 *   - coextension:   A->B and B->A  gives  A == B  (a subsumption CYCLE is MEANINGFUL - an
 *                    equivalence class - NOT the fail-closed that a DEFEAT cycle gets in the combiner)
 *   - property flow: a property is a concept; "A are foolish" is A -> FOOLISH, so anything that
 *                    subsumes down to A inherits it.
 * Nothing is derived that was not entailed: a shouted assertion ("GIRLS RULE!") creates no edge,
 * so it is never subsumed into the tree. Entailment lives here; whether an asserted universal is
 * believed (its evidence tier, assertibility, settlement) is decided by the Reasoned Thought layer.
 *
 * Author: Claude (Opus 4.8), 2026-10-26. Architecture: Tom Dyer. Pure ooRexx 5.3.
 */

::class ConceptHierarchy public
::method init
  expose succ asserted nodes
  succ = .directory~new     /* concept -> set of direct supers (its immediate "all X are _") */
  asserted = .array~new     /* audit log of asserted universals with their source */
  nodes = .set~new

::method allAre
  /* record "all <sub> are <super>" */
  expose succ asserted nodes
  use strict arg sub, super, source = ""
  if \succ~hasIndex(sub) then succ[sub] = .set~new
  succ[sub]~put(super)
  nodes~put(sub); nodes~put(super)
  asserted~append("all" sub "are" super self~srcNote(source))
  return

::method srcNote private
  use strict arg source
  if source = "" then return ""
  return "  <" || source || ">"

/* Is "all <sub> are <super>" entailed (directly or transitively)? */
::method subsumes
  expose succ
  use strict arg sub, super
  return self~path(sub, super) \== .nil

/* Shortest subsumption path sub..super as an array of concepts, or .nil if none. */
::method path
  expose succ
  use strict arg a, b
  if a == b then return .array~of(a)
  visited = .set~new; visited~put(a)
  frontier = .array~of(.array~of(a))
  do while frontier~items > 0
    next = .array~new
    do p over frontier
      last = p[p~items]
      if \succ~hasIndex(last) then iterate
      do nx over succ[last]
        if nx == b then do
          r = .array~new; do n over p; r~append(n); end; r~append(b); return r
        end
        if \visited~hasItem(nx) then do
          visited~put(nx)
          np = .array~new; do n over p; np~append(n); end; np~append(nx)
          next~append(np)
        end
      end
    end
    frontier = next
  end
  return .nil

::method pathString
  use strict arg a, b
  p = self~path(a, b)
  if p == .nil then return "(no path)"
  out = ""
  do i = 1 to p~items
    if i = 1 then out = p[i]; else out = out " -> " p[i]
  end
  return out

/* A and B are the same class: each subsumes the other (a subsumption cycle). */
::method coextensive
  use strict arg a, b
  if a == b then return .false
  return self~subsumes(a, b) & self~subsumes(b, a)

/* The equivalence class of a: everything coextensive with it (including a). */
::method equivalenceClass
  expose nodes
  use strict arg a
  cls = .set~new; cls~put(a)
  do n over nodes
    if n \== a, self~coextensive(a, n) then cls~put(n)
  end
  return cls

::method assertedUniversals
  expose asserted
  return asserted
