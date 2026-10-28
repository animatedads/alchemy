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
 * functions that were themselves the same. The units skipped at ingest are the store's aliases (the
 * same body under another name, as libc's putc and fputc): they count as pass 0, so a call to an alias
 * is a call to the unit kept from the first pass on.
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
::attribute aliases        /* the units skipped at ingest as the same text: .array of (kept unit id, selector, owner, path) */
::method init
  expose store units foldedInto renames passes aliases
  use strict arg store
  units = .directory~new
  foldedInto = .directory~new
  renames = .directory~new
  passes = .array~new
  aliases = .array~new
/* Load the units whose path matches the SQL LIKE pattern (all when omitted). */
::method load
  expose store units aliases
  use strict arg like = '%'
  rows = store~q('SELECT a.unit_id AS uid, a.selector AS sel, a.owner AS owner, a.path AS path FROM alias a JOIN unit u ON u.id = a.unit_id WHERE u.path LIKE ? AND a.path LIKE ?', store~binds(like, like))~rows
  do r over rows
    aliases~append(.array~of(r['UID'], r['SEL'], r['OWNER'], r['PATH']))
  end
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
  expose units foldedInto renames passes aliases
  use strict arg minSize = 1
  /* how many units (aliases too) have each selector: only a selector that one unit has is ever renamed */
  selCount = .directory~new
  names = .array~new
  do id over units~allIndexes; names~append(units[id]['SEL']~lower); end
  /* an alias under its kept unit's own name (libc++'s __cxx03 copies) is the same code: not a second unit */
  do a over aliases
    if units~hasIndex(a[1]) then if a[2]~lower == units[a[1]]['SEL']~lower then iterate
    names~append(a[2]~lower)
  end
  do s over names
    if selCount~hasIndex(s) then selCount[s] = selCount[s] + 1
    else selCount[s] = 1
  end
  /* pass 0, made at ingest: a call to an alias is a call to the unit kept */
  do a over aliases
    if \units~hasIndex(a[1]) then iterate
    as = a[2]~lower
    ks = units[a[1]]['SEL']~lower
    if as \== ks then if selCount[as] == 1 then renames[as] = ks
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
