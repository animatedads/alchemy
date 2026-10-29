/* slam_untested.rex - which files and units no test reaches, read statically.
 *
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-29.
 * Asked for by the rx2cpp lane: "code no test builds" (files that had stopped compiling, and nothing
 * noticed) is, in SLAM's terms, nodes with no tested edge.
 *
 * Usage:  rexx slam_untested.rex <root> [<test pattern> ...] [> report.txt]
 *   root          the tree to read (every .rex .cls .testGroup .cpp .cc .h .hpp .c .java .nrx .sh, and
 *                 Makefile / CMakeLists.txt / *.mk / *.cmake)
 *   test pattern  a path fragment that marks a file as a test (default: /tests/ /test/ /ootest/ test_
 *                 .testGroup); a file whose path holds any of them is a test
 *
 * The rule, stated so it can be argued with:
 *   1. A test reaches every file whose name (the file name, with or without its extension) it holds as
 *      a word: a ::requires, a #include, a "rexx core/x.rex", a source list in a Makefile. A reached
 *      file reaches the files it names, and so on.
 *   2. In a reached file, a unit (an ooRexx ::routine or ::method, a C++ function) is reached when its
 *      name is a word in a test, or in a unit already reached, or in a reached file's top-level code
 *      (the code before its first unit). Names are matched by spelling, ignoring case for ooRexx: a
 *      name two units share reaches both, so the report errs towards "reached".
 * What it cannot see: calls made by building a name at run time (interpret, send with a computed
 * message, function pointers), and a test that runs a file it does not name (a glob). Those show as
 * not reached; check them by hand.
 *
 * Output: a summary, then one line per file no test reaches (FILE path), then one line per unit no
 * test reaches in a reached file (UNIT path name line).
 */
signal on syntax name onSyntax
parse arg root rest
if root == '' then do
  say 'usage: rexx slam_untested.rex <root> [<test pattern> ...]'
  exit 2
end
root = qualify(root)~strip('T', '/')          /* absolute: the files come back with full paths */
patterns = rest~space
if patterns == '' then patterns = '/tests/ /test/ /ootest/ test_ .testGroup'
call SysFileTree root || '/*', 'f.', 'FSO'
files = .array~new
do i = 1 to f.0
  p = f.i
  if p~pos('/.git/') > 0 then iterate
  if kindOf(p) \== '' then files~append(p)
end
/* the words of every file, and which files each name stands for */
words = .directory~new           /* path -> directory of words (upper case) */
byName = .directory~new          /* NAME or NAME.EXT (upper) -> array of paths */
isTest = .directory~new
do p over files
  text = charin(p, 1, chars(p)); call stream p, 'C', 'CLOSE'
  words[p] = wordsOf(stripComments(text, kindOf(p)))
  base = p~substr(p~lastPos('/') + 1)~upper
  call addName byName, base, p
  if base~pos('.') > 0 then call addName byName, base~left(base~lastPos('.') - 1), p
  t = .false
  rel = p~substr(root~length + 1)
  do pat over patterns~makeArray(' ')
    if rel~caselessPos(pat) > 0 then t = .true
  end
  isTest[p] = t
end
/* 1. files: from the tests, through the names each reached file holds */
reached = .directory~new
queue = .array~new
do p over files
  if isTest[p] then do
    reached[p] = .true
    queue~append(p)
  end
end
globsDone = .directory~new
do while queue~items > 0
  p = queue[1]; queue~delete(1)
  do w over words[p]~allIndexes
    if \byName~hasIndex(w) then iterate
    do q over byName[w]
      if reached~hasIndex(q) then iterate
      reached[q] = .true
      queue~append(q)
    end
  end
  /* a script or build file that runs files by a pattern (fixtures, then star_client.rex) reaches them */
  if kindOf(p) == 'BUILD' then do g over globsOf(p)
    if globsDone~hasIndex(g) then iterate
    globsDone[g] = .true
    do q over files
      if reached~hasIndex(q) then iterate
      if \globMatches(g, q) then iterate
      reached[q] = .true
      queue~append(q)
    end
  end
end
/* 2. units in reached files */
units = .array~new               /* directories PATH NAME LINE WORDS */
do p over files
  if \reached~hasIndex(p) then iterate
  if isTest[p] then iterate
  do u over unitsOf(p)
    units~append(u)
  end
end
known = .directory~new           /* the words that reach a unit: tests, top-level code, reached units */
do p over files
  if \reached~hasIndex(p) then iterate
  if isTest[p] then do w over words[p]~allIndexes; known[w] = .true; end
end
do u over units
  if u['NAME'] == '' then do w over u['WORDS']~allIndexes; known[w] = .true; end   /* top-level code */
end
done = .directory~new
do forever
  added = 0
  do u over units
    if u['NAME'] == '' then iterate
    id = u['PATH'] || ':' || u['LINE']
    if done~hasIndex(id) then iterate
    /* operators ([]=, ==) and destructors (~Name) are called without their name being written */
    nm = u['NAME']
    implicit = (nm~left(1)~verify(xrange('a', 'z') || xrange('A', 'Z') || '_') > 0)
    if \implicit then if \known~hasIndex(nm~upper) then iterate
    done[id] = .true
    added += 1
    do w over u['WORDS']~allIndexes; known[w] = .true; end
  end
  if added == 0 then leave
end
nFiles = 0; nReached = 0; nUnits = 0; nUnitsReached = 0
do p over files
  if isTest[p] then iterate
  nFiles += 1
  if reached~hasIndex(p) then nReached += 1
end
do u over units
  if u['NAME'] == '' then iterate
  nUnits += 1
  if done~hasIndex(u['PATH'] || ':' || u['LINE']) then nUnitsReached += 1
end
nTests = 0
do p over files; if isTest[p] then nTests += 1; end
say 'SLAM untested report for' root
say 'tests' nTests '(paths holding:' patterns || ')'
say 'files' nFiles ' reached by a test' nReached ' not reached' (nFiles - nReached)
say 'units in reached files' nUnits ' reached' nUnitsReached ' not reached' (nUnits - nUnitsReached)
say
do p over files~sort
  if isTest[p] then iterate
  if \reached~hasIndex(p) then say 'FILE' p~substr(root~length + 2)
end
do u over units
  if u['NAME'] == '' then iterate
  if \done~hasIndex(u['PATH'] || ':' || u['LINE']) then say 'UNIT' u['PATH']~substr(root~length + 2) u['NAME'] u['LINE']
end
exit 0

kindOf: procedure
  use arg p
  base = p~substr(p~lastPos('/') + 1)
  if base == 'Makefile' | base == 'CMakeLists.txt' then return 'BUILD'
  ext = base~substr(base~lastPos('.') + 1)~lower
  if base~pos('.') == 0 then return ''
  if wordpos(ext, 'rex cls rexx orx testgroup frm') > 0 then return 'REXX'
  if wordpos(ext, 'cpp cc cxx c h hpp hh hxx inc') > 0 then return 'CPP'
  if wordpos(ext, 'java nrx') > 0 then return 'JVM'
  if wordpos(ext, 'sh mk cmake') > 0 then return 'BUILD'
  return ''

addName: procedure
  use arg d, name, p
  if \d~hasIndex(name) then d[name] = .array~new
  d[name]~append(p)
  return

/* The words of a text: runs of letters, digits, _ . ! ? (a file name keeps its dot), upper case. */
wordsOf: procedure
  use arg text
  keep = xrange('a', 'z') || xrange('A', 'Z') || xrange('0', '9') || '_.!?'
  out = .directory~new
  /* every character that is not a word character becomes a blank */
  bad = ''
  do i = 0 to 255
    ch = d2c(i)
    if keep~pos(ch) == 0 then bad = bad || ch
  end
  t = translate(text, copies(' ', bad~length), bad)
  do w over t~upper~makeArray(' ')
    if w == '' then iterate
    out[w] = .true
    /* a.b.c: the parts too (a qualified name, a path) */
    if w~pos('.') > 0 then do part over w~makeArray('.')
      if part \== '' then out[part] = .true
    end
  end
  return out

/* Units of a file, by its directives (ooRexx) or definitions (C++), with their words. The code before
 * the first unit is a unit with no name. */
unitsOf: procedure
  use arg p
  out = .array~new
  k = kindOf(p)
  if k \== 'REXX' & k \== 'CPP' then return out
  text = charin(p, 1, chars(p)); call stream p, 'C', 'CLOSE'
  if k == 'REXX' then text = stripComments(text, k)
  lines = text~makeArray('0a'x)
  starts = .array~new            /* .array(line, name) */
  if k == 'REXX' then do
    do i = 1 to lines~items
      s = lines[i]~strip
      if s~left(2) \== '::' then iterate
      parse upper var s d nm .
      if wordpos(d, '::ROUTINE ::METHOD ::CLASS ::REQUIRES ::OPTIONS ::ATTRIBUTE ::CONSTANT ::RESOURCE') == 0 then iterate
      nm = nm~strip('B', ';')~strip('B', ',')~strip('B', "'")~strip('B', '"')
      if wordpos(d, '::ROUTINE ::METHOD') > 0 then starts~append(.array~of(i, nm))
      else starts~append(.array~of(i, ''))
    end
  end
  else do
    signal on syntax name cppFailed
    do u over .SlamCppSplitter~new~split(text)
      nm = u~selector
      if nm~pos('<') > 0 then nm = nm~left(nm~pos('<') - 1)
      if nm~left(8) == 'operator' then iterate
      /* a C++ unit's words are its own tokens: a lambda inside a function is a unit of its own, so
         a range of lines would cut the function short */
      buf = .mutablebuffer~new
      do t over u~tokens; buf~append(t~text, ' '); end
      starts~append(.array~of(u~line, nm, buf~string))
    end
  end
  /* in line order (a splitter may list a class's members after what follows the class) */
  sorted = .array~new
  do st over starts
    pos = sorted~items + 1
    do j = 1 to sorted~items
      if sorted[j][1] > st[1] then do
        pos = j
        leave
      end
    end
    if pos == 1 then sorted~insert(st, .nil)
    else sorted~insert(st, pos - 1)
  end
  starts = sorted
  /* the top-level code: lines before the first unit (ooRexx), or the whole file's words (C++: it is
     compiled when the file is) */
  first = lines~items + 1
  if starts~items > 0 then first = starts[1][1]
  top = .directory~new
  top['PATH'] = p
  top['NAME'] = ''
  top['LINE'] = 0
  if k == 'REXX' then top['WORDS'] = wordsOf(linesText(lines, 1, first - 1))
  else top['WORDS'] = .directory~new
  out~append(top)
  do i = 1 to starts~items
    s = starts[i]
    last = lines~items
    if i < starts~items then last = starts[i + 1][1] - 1
    if s[2] == '' then do
      /* a ::class or other directive: its own line's words count as top level */
      d = .directory~new
      d['PATH'] = p; d['NAME'] = ''; d['LINE'] = s[1]
      d['WORDS'] = wordsOf(lines[s[1]])
      out~append(d)
      iterate
    end
    d = .directory~new
    d['PATH'] = p
    d['NAME'] = s[2]
    d['LINE'] = s[1]
    if k == 'REXX' then d['WORDS'] = wordsOf(linesText(lines, s[1] + 1, last))
    else d['WORDS'] = wordsOf(s[3])
    out~append(d)
  end
  return out
cppFailed:
  return out

/* The patterns a script names: words holding * or ? (quotes and $VAR/ prefixes taken off). */
globsOf: procedure
  use arg p
  text = charin(p, 1, chars(p)); call stream p, 'C', 'CLOSE'
  t = translate(text, '      ', '"''();|' || '09'x)
  t = translate(t, ' ', '0a'x)
  out = .array~new
  do w over t~makeArray(' ')
    if w~verify('*?', 'M') == 0 then iterate
    if w~verify('*?./', 'N') == 0 then iterate          /* a pattern of only stars, dots and slashes says nothing */
    /* keep the part after the last variable: $ROOT, then native, then the pattern */
    at = w~lastPos('}')
    if at == 0 then at = w~lastPos('$')
    if at > 0 then do
      sl = w~pos('/', at)
      if sl == 0 then iterate
      w = w~substr(sl + 1)
    end
    /* "$ROOT"/examples/x.rex: the quote has split the variable off, so the pattern starts with / */
    do while w~left(2) == './'; w = w~substr(3); end
    w = w~strip('L', '/')
    if w == '' then iterate
    out~append(w)
  end
  return out

/* Does a file's path end with something the pattern matches (by whole path parts)? */
globMatches: procedure
  use arg g, path
  parts = g~makeArray('/')~items
  segs = path~makeArray('/')
  if segs~items < parts then return .false
  tail = ''
  do i = segs~items - parts + 1 to segs~items
    if tail \== '' then tail = tail || '/'
    tail = tail || segs[i]
  end
  return wild(g, tail)

wild: procedure
  use arg g, s
  if g == '' then return s == ''
  c = g~left(1)
  if c == '*' then do
    do i = 0 to s~length
      if wild(g~substr(2), s~substr(i + 1)) then return .true
    end
    return .false
  end
  if s == '' then return .false
  if c == '?' | c == s~left(1) then return wild(g~substr(2), s~substr(2))
  return .false

/* The text without its comments (a comment that names a routine does not call it): ooRexx block and
   line comments, C and C++ comments, # in scripts. Quoted strings are kept; line breaks are kept, so
   line numbers stay right. */
stripComments: procedure
  use arg text, kind
  out = .mutablebuffer~new
  i = 1
  n = text~length
  depth = 0
  do while i <= n
    ch = text~subchar(i)
    two = text~substr(i, 2)
    if depth > 0 then do
      if two == '*/' then do
        depth -= 1
        i += 2
        iterate
      end
      if kind == 'REXX' then if two == '/*' then do
        depth += 1
        i += 2
        iterate
      end
      if ch == '0a'x then out~append(ch)
      i += 1
      iterate
    end
    if ch == '"' | ch == "'" then do
      j = text~pos(ch, i + 1)
      if kind == 'BUILD' then if j == 0 then j = n
      if j == 0 then j = n
      lf = text~pos('0a'x, i + 1)
      if kind \== 'REXX' then if lf > 0 then if lf < j then j = lf - 1
      out~append(text~substr(i, j - i + 1))
      i = j + 1
      iterate
    end
    if kind \== 'BUILD' then if two == '/*' then do
      depth = 1
      i += 2
      iterate
    end
    lineComment = .false
    if kind == 'REXX' then if two == '--' then lineComment = .true
    if kind == 'CPP' | kind == 'JVM' then if two == '//' then lineComment = .true
    if kind == 'BUILD' then if ch == '#' then lineComment = .true
    if lineComment then do
      lf = text~pos('0a'x, i)
      if lf == 0 then leave
      i = lf
      iterate
    end
    out~append(ch)
    i += 1
  end
  return out~string

linesText: procedure
  use arg lines, a, b
  buf = .mutablebuffer~new
  do i = a to b
    if i < 1 | i > lines~items then iterate
    buf~append(lines[i], ' ')
  end
  return buf~string

onSyntax:
  say 'SYNTAX rc=' || rc 'sigl=' || sigl condition('C') condition('D') condition('O')~traceback~makeArray~makeString('L', ' | ')
  exit 1

::requires 'SlamCpp.cls'
