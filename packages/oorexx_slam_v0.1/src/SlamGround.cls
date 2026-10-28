/* SlamGround.cls - grounding: corpus words anchored to tested ooRexx code.
 *
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-28.
 *
 * The circular corpus is one closed circle: definitions alone ground nothing. Here the circle is broken
 * by execution. Each procedural maths/statistics word is anchored to a SlamMaths method, the method is
 * checked against known answers, and every check is recorded as an outcome on the edge
 * (word node -> code node). Only anchors whose edge is TESTED at rate 1 are used.
 *
 * ask(sentence, values) reads the sentence with SLAM's own vocabulary (any unknown word: refused),
 * picks the anchored words in order, and applies them right to left, the way "the X of the Y of the
 * values" means X(Y(values)). Numerals in the sentence are the values when none are passed. Two corpus compounds are read as one word, as the corpus defines them:
 * "square root" is root, "standard deviation" is standard. Every operation takes and returns a list.
 */

::requires 'SlamStore.cls'

::class SlamMaths public
::method total class
  use strict arg v
  numeric digits 20
  s = 0
  do x over v
    s = s + x
  end
  return s
::method add class
  use strict arg v
  return .array~of(self~total(v))
::method count class
  use strict arg v
  return .array~of(v~items)
::method mean class
  use strict arg v
  numeric digits 20
  if v~items == 0 then raise syntax 88.900 array('mean of no values')
  return .array~of(self~total(v) / v~items)
::method sorted class
  use strict arg v
  out = v~copy
  out~sortWith(.NumericComparator~new)
  return out
::method median class
  use strict arg v
  numeric digits 20
  if v~items == 0 then raise syntax 88.900 array('median of no values')
  s = self~sorted(v)
  n = s~items
  if n // 2 == 1 then return .array~of(s[(n + 1) % 2])
  return .array~of((s[n % 2] + s[n % 2 + 1]) / 2)
::method mode class
  use strict arg v
  counts = .directory~new
  do x over v
    k = x~string
    if counts~hasIndex(k) then counts[k] = counts[k] + 1
    else counts[k] = 1
  end
  best = ''
  bestN = 0
  tie = .false
  do k over counts~allIndexes
    if counts[k] > bestN then do
      best = k
      bestN = counts[k]
      tie = .false
    end
    else if counts[k] == bestN then tie = .true
  end
  if tie then raise syntax 88.900 array('no mode: two values have the same count')
  return .array~of(best)
::method range class
  use strict arg v
  numeric digits 20
  s = self~sorted(v)
  return .array~of(s[s~items] - s[1])
::method deviation class
  use strict arg v
  numeric digits 20
  m = self~mean(v)[1]
  out = .array~new
  do x over v
    out~append(x - m)
  end
  return out
::method square class
  use strict arg v
  numeric digits 20
  out = .array~new
  do x over v
    out~append(x * x)
  end
  return out
::method sqrtOf class
  use strict arg x
  numeric digits 30
  if x < 0 then raise syntax 88.900 array('root of a number less than zero')
  if x = 0 then return 0
  g = x / 2
  if g < 1 then g = 1
  do 300
    n = (g + x / g) / 2
    if n = g then leave
    g = n
  end
  numeric digits 20
  return format(g)
::method root class
  use strict arg v
  out = .array~new
  do x over v
    out~append(self~sqrtOf(x))
  end
  return out
::method variance class
  use strict arg v
  return self~mean(self~square(self~deviation(v)))
::method standard class
  use strict arg v
  return self~root(self~variance(v))
::method multiply class
  use strict arg v
  numeric digits 20
  p = 1
  do x over v
    p = p * x
  end
  return .array~of(p)
::method subtract class
  use strict arg v
  numeric digits 20
  r = v[1]
  do i = 2 to v~items
    r = r - v[i]
  end
  return .array~of(r)
::method divide class
  use strict arg v
  numeric digits 20
  r = v[1]
  do i = 2 to v~items
    if v[i] = 0 then raise syntax 88.900 array('divide by zero')
    r = r / v[i]
  end
  return .array~of(r)

::class SlamGround public
/* word -> SlamMaths method. Plurals the corpus defines (squares) map to their singular. */
::method anchors class
  d = .directory~new
  d['add'] = 'ADD'; d['sum'] = 'ADD'; d['count'] = 'COUNT'; d['mean'] = 'MEAN'
  d['median'] = 'MEDIAN'; d['mode'] = 'MODE'; d['range'] = 'RANGE'; d['variance'] = 'VARIANCE'
  d['standard'] = 'STANDARD'; d['deviation'] = 'DEVIATION'; d['square'] = 'SQUARE'; d['squares'] = 'SQUARE'
  d['root'] = 'ROOT'; d['multiply'] = 'MULTIPLY'; d['subtract'] = 'SUBTRACT'; d['difference'] = 'SUBTRACT'
  d['divide'] = 'DIVIDE'
  return d
/* Known answers: method, input list, expected list ('ERROR' when the method must refuse). */
::method cases class
  c = .array~new
  data = '2 4 4 4 5 5 7 9'
  c~append(.array~of('ADD', data, '40'));        c~append(.array~of('ADD', '1 2 3', '6'))
  c~append(.array~of('COUNT', data, '8'));       c~append(.array~of('COUNT', '7', '1'))
  c~append(.array~of('MEAN', data, '5'));        c~append(.array~of('MEAN', '1 2', '1.5'))
  c~append(.array~of('MEDIAN', data, '4.5'));    c~append(.array~of('MEDIAN', '3 1 2', '2'))
  c~append(.array~of('MODE', data, '4'));        c~append(.array~of('MODE', '1 1 2 2', 'ERROR'))
  c~append(.array~of('RANGE', data, '7'));       c~append(.array~of('RANGE', '5 -1', '6'))
  c~append(.array~of('VARIANCE', data, '4'));    c~append(.array~of('VARIANCE', '1 2 3 4', '1.25'))
  c~append(.array~of('STANDARD', data, '2'));    c~append(.array~of('STANDARD', '1 1 1', '0'))
  c~append(.array~of('DEVIATION', data, '-3 -1 -1 -1 0 0 2 4')); c~append(.array~of('DEVIATION', '1 3', '-1 1'))
  c~append(.array~of('SQUARE', '2 -3', '4 9'));  c~append(.array~of('SQUARE', '0.5', '0.25'))
  c~append(.array~of('ROOT', '16 2', '4 1.41421356237309504880')); c~append(.array~of('ROOT', '-1', 'ERROR'))
  c~append(.array~of('MULTIPLY', '2 3 4', '24')); c~append(.array~of('MULTIPLY', '5', '5'))
  c~append(.array~of('SUBTRACT', '10 3 2', '5')); c~append(.array~of('SUBTRACT', '1 4', '-3'))
  c~append(.array~of('DIVIDE', '24 2 3', '4'));  c~append(.array~of('DIVIDE', '1 0', 'ERROR'))
  return c
::method list class
  use strict arg text
  a = .array~new
  do i = 1 to text~words
    a~append(text~word(i))
  end
  return a
::method same class
  use strict arg got, expected
  numeric digits 20
  if got~items \= expected~items then return .false
  do i = 1 to got~items
    if \datatype(got[i], 'N') then return .false
    if abs(got[i] - expected[i]) > 1e-15 then return .false
  end
  return .true
::method codeNode class
  use strict arg store, method
  return store~shapeId('CODE', 'CODE', 'CODE: SlamMaths~' || method~lower)
/* Run every known answer; record each as an outcome on word -> code. Returns passes and trials. */
::method qualify class
  use strict arg store
  anchors = self~anchors
  passes = 0
  trials = 0
  store~begin
  do c over self~cases
    method = c[1]
    ok = self~check(method, self~list(c[2]), c[3])
    do w over anchors~allIndexes
      if anchors[w] == method then store~record(store~wordId(w), self~codeNode(store, method), ok)
    end
    trials += 1
    if ok then passes += 1
  end
  store~commit
  return .array~of(passes, trials)
::method check class
  use strict arg method, input, expected
  signal on syntax name refused
  got = .SlamMaths~send(method, input)
  if expected == 'ERROR' then return .false
  return self~same(got, self~list(expected))
refused:
  return expected == 'ERROR'
/* Read a request in SLAM's words and run its anchored words right to left over the values. */
::method ask class
  use strict arg store, sentence, values
  out = .directory~new
  out['UNKNOWN'] = .array~new
  out['OPS'] = .array~new
  vocab = .directory~new
  r = store~q("SELECT canon AS canon FROM shape WHERE kind = 'WORD'")
  do row over r~rows
    vocab[row['CANON']~substr(7)] = .true
  end
  clean = sentence~lower~translate('', '.,;:()"''?!')
  words = .array~new
  numerals = .array~new
  do i = 1 to clean~words
    w = clean~word(i)
    if datatype(w, 'N') then do
      numerals~append(w)
      iterate
    end
    words~append(w)
    if \vocab~hasIndex(w) then out['UNKNOWN']~append(w)
  end
  /* A numeral is a value, not a word (the corpus defines number, not numerals). */
  if values~items == 0 then values = numerals
  if out['UNKNOWN']~items > 0 then do
    out['STATUS'] = 'UNKNOWN_WORDS'
    return out
  end
  anchors = self~anchors
  ops = .array~new
  do i = 1 to words~items
    w = words[i]
    if \anchors~hasIndex(w) then iterate
    if w == 'square' then if i < words~items then if words[i + 1] == 'root' then iterate
    if w == 'deviation' then if i > 1 then if words[i - 1] == 'standard' then iterate
    d = store~rate(store~wordId(w), self~codeNode(store, anchors[w]))
    if d['TIER'] \== 'TESTED' then do
      out['STATUS'] = 'NOT_TESTED'
      out['WORD'] = w
      return out
    end
    if d['RATE'] < 1 then do
      out['STATUS'] = 'TEST_FAILED'
      out['WORD'] = w
      return out
    end
    ops~append(w)
  end
  out['OPS'] = ops
  if ops~items == 0 then do
    out['STATUS'] = 'NOTHING_TO_RUN'
    return out
  end
  signal on syntax name failed
  v = values
  do i = ops~items to 1 by -1
    v = .SlamMaths~send(anchors[ops[i]], v)
  end
  out['STATUS'] = 'OK'
  out['RESULT'] = v
  return out
failed:
  out['STATUS'] = 'ERROR'
  out['DETAIL'] = condition('O')['MESSAGE']
  return out
