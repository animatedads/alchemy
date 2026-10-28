/* SlamFold.cls - identical code folding over SLAM's store, learned from BOLT's IdenticalCodeFolding.
 *
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-28.
 *
 * BOLT (llvm-project/bolt/lib/Passes/IdenticalCodeFolding.cpp) folds functions in a binary:
 *   1. hash every function, ignoring symbol operands, and bucket the CONGRUENT ones (equal but for
 *      the symbols they refer to);
 *   2. in each bucket, fold the ones that are IDENTICAL, a call to a folded function counting as a
 *      call to the function it was folded into; keep the lowest-numbered one;
 *   3. repeat until a pass folds nothing: folding callees can make callers identical (a fixpoint).
 * The same algorithm on code units:
 *   congruent   the same tree of FAMILY shapes (message, function and class names abstracted)
 *   identical   the same tree of FINE shapes and the same literal values (shapes abstract them to S
 *               and N; BOLT compares constants exactly), with each called name replaced by the name of
 *               the unit it was folded into; renames made in a pass apply from the next pass, so the
 *               passes do not depend on the order buckets are visited in
 * Units whose text is the same were already skipped at ingest (SlamUnit~signature), so what folds here
 * is the same code under other names: other variable names, and, from the second pass on, calls to
 * functions that were themselves the same.
 * A called name is the word just before a "(" in a FINE shape. Names are matched by selector; a selector
 * that more than one unit has is never renamed (it would be a guess).
 *
 * Alchemy rules kept: no private methods, expose first, no variable named result, nested IF instead of
 * relying on & short-circuit, no labels inside loops.
 */

::requires 'SlamStore.cls'

::class SlamFold public
::attribute store
::attribute units          /* unit id -> directory: SEL, OWNER, PATH, FAMILY (text), FINE (array of canons), PARENTS, SIZE */
::attribute foldedInto     /* unit id -> the unit id it was folded into */
::attribute renames        /* lower-case selector -> lower-case selector it now stands for */
::attribute passes         /* folds made in each pass */
::method init
  expose store units foldedInto renames passes
  use strict arg store
  units = .directory~new
  foldedInto = .directory~new
  renames = .directory~new
  passes = .array~new
/* Load the units whose path matches the SQL LIKE pattern (all when omitted). */
::method load
  expose store units
  use strict arg like = '%'
  rows = store~q('SELECT id AS id, selector AS sel, owner AS owner, path AS path FROM unit WHERE path LIKE ?', store~binds(like))~rows
  do r over rows
    d = .directory~new
    d['SEL'] = r['SEL']
    d['OWNER'] = r['OWNER']
    d['PATH'] = r['PATH']
    d['FAMILY'] = .array~new
    d['FINE'] = .array~new
    d['PARENTS'] = .array~new
    d['POS'] = .directory~new
    units[r['ID']] = d
  end
  last = 0
  do forever
    rows = store~q('SELECT i.id AS id, i.unit_id AS uid, i.parent_id AS par, s.canon AS canon, s.family AS fam, i.consts AS consts FROM instance i JOIN shape s ON s.id = i.shape_id JOIN unit u ON u.id = i.unit_id WHERE i.id > ? AND u.path LIKE ? ORDER BY i.id LIMIT 20000', store~binds(last, like))~rows
    if rows~items == 0 then leave
    do r over rows
      last = r['ID']
      d = units[r['UID']]
      if d == .nil then iterate
      d['FINE']~append(r['CANON'] || '0e'x || r['CONSTS'])
      d['FAMILY']~append(r['FAM'])
      p = 0
      if d['POS']~hasIndex(r['PAR']) then p = d['POS'][r['PAR']]
      d['PARENTS']~append(p)
      d['POS'][r['ID']] = d['FINE']~items
    end
  end
  do id over units~allIndexes
    d = units[id]
    d['SIZE'] = d['FINE']~items
    d['FAMTEXT'] = self~treeText(d['FAMILY'], d['PARENTS'])
  end
  return units~items
::method treeText
  use strict arg texts, parents
  buf = .mutablebuffer~new
  do k = 1 to texts~items
    buf~append(parents[k] || '>' || texts[k] || '0a'x)
  end
  return buf~string
/* The FINE tree of a unit, with each called name replaced by what it was folded into. */
::method resolved
  expose units renames
  use strict arg id
  d = units[id]
  out = .array~new
  do c over d['FINE']
    if renames~items > 0 then do
      w = c~makeArray(' ')
      do k = 1 to w~items - 1
        if w[k + 1] == '(' then if renames~hasIndex(w[k]~lower) then w[k] = renames[w[k]~lower]
      end
      c = w~makeString('L', ' ')
    end
    out~append(c)
  end
  return self~treeText(out, d['PARENTS'])
/* Fold to a fixpoint. minSize: the fewest segments a unit needs to be folded (1 folds everything). */
::method run
  expose units foldedInto renames passes
  use strict arg minSize = 1
  /* how many units have each selector: only a selector that one unit has is ever renamed */
  selCount = .directory~new
  do id over units~allIndexes
    s = units[id]['SEL']~lower
    if selCount~hasIndex(s) then selCount[s] = selCount[s] + 1
    else selCount[s] = 1
  end
  /* 1. congruent buckets */
  buckets = .directory~new
  do id over units~allIndexes
    d = units[id]
    if d['SIZE'] < minSize then iterate
    k = d['FAMTEXT']
    if \buckets~hasIndex(k) then buckets[k] = .array~new
    buckets[k]~append(id)
  end
  /* 2 and 3. fold the identical ones in each bucket, pass after pass, until a pass folds nothing */
  do forever
    folded = 0
    pending = .directory~new
    do k over buckets~allIndexes
      ids = buckets[k]
      if ids~items < 2 then iterate
      twins = .directory~new
      do id over self~sorted(ids)
        if foldedInto~hasIndex(id) then iterate
        t = self~resolved(id)
        if \twins~hasIndex(t) then twins[t] = .array~new
        twins[t]~append(id)
      end
      do t over twins~allIndexes
        grp = twins[t]
        if grp~items < 2 then iterate
        parent = grp[1]
        do m = 2 to grp~items
          child = grp[m]
          foldedInto[child] = parent
          cs = units[child]['SEL']~lower
          ps = units[parent]['SEL']~lower
          if cs \== ps then if selCount[cs] == 1 then pending[cs] = ps
          folded += 1
        end
      end
    end
    do cs over pending~allIndexes; renames[cs] = pending[cs]; end
    passes~append(folded)
    if folded == 0 then leave
  end
  return passes
::method sorted
  use strict arg ids
  a = .array~new
  do id over ids; a~append(id); end
  return a~sortWith(.NumericComparator~new)
/* Groups: the unit kept -> the units folded into it (directly or through a chain). */
::method groups
  expose foldedInto
  out = .directory~new
  do child over foldedInto~allIndexes
    root = foldedInto[child]
    do while foldedInto~hasIndex(root)
      root = foldedInto[root]
    end
    if \out~hasIndex(root) then out[root] = .array~new
    out[root]~append(child)
  end
  return out
