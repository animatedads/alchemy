/* Do two runs of the same mutants agree (the in-process runner, and the real ooTest framework)?
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-29.
 * Args: verdicts file | verdicts file   (unit, mutant, suite, verdict, change; tab-separated)
 * KILLED and TIMEOUT count as caught. Prints: AGREE n DISAGREE m, then each disagreement.
 */
parse arg a '|' b
va = read(a)
vb = read(b)
agree = 0; differ = 0; out = .array~new
do k over vb~allIndexes
  if \va~hasIndex(k) then iterate
  if caught(va[k]) == caught(vb[k]) then agree += 1
  else do
    differ += 1
    out~append(k va[k] vb[k])
  end
end
say 'AGREE' agree 'DISAGREE' differ
do l over out; say '  ' l; end
exit 0
read: procedure
  use arg f
  d = .directory~new
  do while lines(f) > 0
    parse value linein(f) with . '09'x m '09'x s '09'x v '09'x .
    if m == '' then iterate
    d[m s] = v~word(1)
  end
  call stream f, 'C', 'CLOSE'
  return d
caught: procedure
  use arg v
  return wordpos(v, 'KILLED TIMEOUT') > 0
