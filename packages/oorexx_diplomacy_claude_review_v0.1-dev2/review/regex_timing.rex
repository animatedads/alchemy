/* Word-boundary workaround and runaway-pattern timing. Claude (Opus 5.5). */
text = ' ' || 'WE ATTACK TURKEY. TURKEYS ARE BIRDS.' || ' '
re = .RegularExpression~new('[^A-Z]TURKEY[^A-Z]')
say 'bounded TURKEY pos=' re~pos(text)
re = .RegularExpression~new('[^A-Z]TURKEYS[^A-Z]')
say 'bounded TURKEYS pos=' re~pos(text)
long = copies('A', 12000)
pats = .array~of('(A*)*B', '(A|AA)*B', '((A*)*)*B', '(?*)*?*B', 'A*A*A*A*A*A*A*A*A*A*B')
do pat over pats
  call time 'R'
  re = .RegularExpression~new(pat)
  hit = re~pos(long)
  say left(pat, 24) 'pos='hit 'seconds='format(time('E'),,3)
end
::requires 'rxregexp.cls'
