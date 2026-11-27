/* Probe ooRexx RegularExpression behaviour. Claude (Opus 5.5). */
text = 'Then we attack Turkey from the north. A centre and a center. position'
tests = .array~of('\bTURKEY\b', 'TURKEY', 'Turkey', '[Tt]urkey', '.', '.*', '?*', 'cent(er|re)', 'center', '[[:alpha:]]+', 'ion', '(Turkey|Russia)', '^Then', 'north\.', 'T.rkey', '[', '(')
do pat over tests
  say left(pat, 18) probe(pat, text)
end
say 'MINIMAL .* :' probe2('.*', text)
exit

::routine probe
  use strict arg pat, text
  signal on syntax name bad
  re = .RegularExpression~new(pat)
  return 'match='re~match(text) 'pos='re~pos(text) 'posUpper='re~pos(text~upper)
bad:
  return 'SYNTAX:' condition('O')['MESSAGE']

::routine probe2
  use strict arg pat, text
  re = .RegularExpression~new(pat, 'MINIMAL')
  return 'pos='re~pos(text)

::requires 'rxregexp.cls'
