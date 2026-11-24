/* NewShellMuTree.cls - survey a whole-filesystem path list against witness rules.
 *
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5).  23 Nov 2026.
 *
 * Input 1: a path list, one absolute path per line (the output of `find /`).
 * Input 2: a rule file. Each rule names a path prefix and a verdict:
 *
 *     keep    PREFIX | witness: why the MU needs it
 *     cut     PREFIX | why it has no witness
 *     virtual PREFIX | kernel or runtime view, not on disk (/proc, /sys ...)
 *
 * The longest matching prefix decides a path. Paths no rule matches are
 * UNCLASSIFIED: those are the ones nobody has argued for yet, and the report
 * groups them by directory so the next rules can be written.
 */

::class MuTreeRule public
::method module_version class
  return '0.1-dev1'
::method module_lastChanged class
  return '2026-11-23'
::attribute verdict get
::attribute prefix get
::attribute reason get
::attribute count
::attribute example
::method init
  expose verdict prefix reason count example
  use strict arg verdict, prefix, reason
  count = 0
  example = ''
::method matches
  expose prefix
  use strict arg path
  if path == prefix then return .true
  return path~startsWith(prefix || '/')

::class MuTreeSurvey public
::method module_version class
  return '0.1-dev1'
::method module_lastChanged class
  return '2026-11-23'
::attribute rules get
::attribute unclassified get
::attribute total get
::method init
  expose rules unclassified total
  rules = .array~new
  unclassified = .directory~new
  total = 0

/* Read the rule file. Blank lines and lines starting with # are ignored. */
::method loadRules
  expose rules
  use strict arg rulePath
  rf = .stream~new(rulePath)
  if rf~open('read') \= 'READY:' then
    throw syntax 98.900 array ('cannot open rule file' rulePath)
  lineNo = 0
  do while rf~lines > 0
    line = rf~linein~strip
    lineNo = lineNo + 1
    if line == '' then iterate
    if line~left(1) == '#' then iterate
    parse var line verdictWord rulePrefix '|' ruleReason
    verdictWord = verdictWord~lower
    rulePrefix = rulePrefix~strip
    if wordpos(verdictWord, 'keep cut virtual') = 0 | rulePrefix~left(1) \== '/' then do
      rf~close
      throw syntax 98.900 array ('rule file' rulePath 'line' lineNo 'is not "keep|cut|virtual /prefix | reason"')
    end
    rules~append(.MuTreeRule~new(verdictWord, rulePrefix~strip('T', '/'), ruleReason~strip))
  end
  rf~close
  .NewShellLog~progress('loaded' rules~items 'rules from' rulePath)

/* Longest matching prefix wins. Returns .nil when no rule matches. */
::method ruleFor
  expose rules
  use strict arg path
  best = .nil
  do rule over rules
    if \rule~matches(path) then iterate
    if best == .nil then best = rule
    else if rule~prefix~length > best~prefix~length then best = rule
  end
  return best

/* Classify every path in the list. Unclassified paths are grouped by their
   first `depth` directory levels. */
::method survey
  expose unclassified total
  use strict arg listPath, depth = 3
  lf = .stream~new(listPath)
  if lf~open('read') \= 'READY:' then
    throw syntax 98.900 array ('cannot open path list' listPath)
  do while lf~lines > 0
    path = lf~linein~strip('T')
    if path == '' then iterate
    total = total + 1
    if total // 20000 = 0 then .NewShellLog~progress(total 'paths read')
    rule = self~ruleFor(path)
    if rule \== .nil then do
      rule~count = rule~count + 1
      if rule~example == '' then rule~example = path
      iterate
    end
    group = self~groupOf(path, depth)
    if unclassified~hasIndex(group) then unclassified[group] = unclassified[group] + 1
    else unclassified[group] = 1
  end
  lf~close
  .NewShellLog~progress('survey done:' total 'paths')

::method groupOf
  use strict arg path, depth
  parts = path~makeArray('/')
  groupText = ''
  taken = 0
  do part over parts
    if part == '' then iterate
    groupText = groupText || '/' || part
    taken = taken + 1
    if taken = depth then leave
  end
  if groupText == '' then return '/'
  return groupText

/* Lines of the report, as an array of strings. */
::method report
  expose rules unclassified total
  use strict arg topUnclassified = 30
  out = .array~new
  out~append('MU tree survey:' total 'paths')
  do verdictWord over .array~of('virtual', 'keep', 'cut')
    sum = 0
    do rule over rules
      if rule~verdict == verdictWord then sum = sum + rule~count
    end
    out~append('')
    out~append(verdictWord~upper 'total' sum)
    do rule over self~sortedRules(verdictWord)
      if rule~count = 0 then iterate
      out~append('  ' || rule~count~right(7) rule~prefix~left(48) '|' rule~reason)
    end
  end
  unSum = 0
  do group over unclassified
    unSum = unSum + unclassified[group]
  end
  out~append('')
  out~append('UNCLASSIFIED total' unSum '(no rule yet; top' topUnclassified 'by count)')
  groups = .array~new
  do group over unclassified
    groups~append(unclassified[group]~right(9, '0') || ' ' || group)
  end
  groups = groups~sort
  shown = 0
  do i = groups~items to 1 by -1
    parse value groups[i] with n groupName
    out~append('  ' || (n + 0)~right(7) groupName)
    shown = shown + 1
    if shown = topUnclassified then leave
  end
  return out

::method sortedRules
  expose rules
  use strict arg verdictWord
  keyed = .array~new
  do i = 1 to rules~items
    rule = rules[i]
    if rule~verdict \== verdictWord then iterate
    keyed~append(rule~count~right(9, '0') || ' ' || i)
  end
  keyed = keyed~sort
  ordered = .array~new
  do j = keyed~items to 1 by -1
    parse value keyed[j] with . ruleIndex
    ordered~append(rules[ruleIndex])
  end
  return ordered

::requires 'NewShellIdentity.cls'
