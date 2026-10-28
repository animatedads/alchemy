/* Old FDSqrt (fixed 14 steps) against new FDSqrt (until the answer does not change), at NUMERIC DIGITS 9,
 * on random values in the door's range (0 .. 1e6): pixel-step variances, whole numbers, ratios, gdx^2+gdy^2.
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-28.  Args: count seed
 * Result in evidence/fdsqrt/sweep.txt: 200000 values, all identical, most steps 15.
 */
parse arg n seed
r = random(1, 2, seed)
same = 0; diff = 0; oldBetter = 0; newBetter = 0; maxSteps = 0; worst = ''
do i = 1 to n
  select
    when i // 4 = 0 then x = random(0, 999999) / 1000          /* 0 .. 1000, 3 places   */
    when i // 4 = 1 then x = random(1, 999999)                  /* whole, up to 1e6      */
    when i // 4 = 2 then x = random(1, 99999) / random(1, 999)  /* variance-like ratios  */
    otherwise x = (random(-99999, 99999) / 100)**2 + (random(-99999, 99999) / 100)**2   /* gdx^2+gdy^2 */
  end
  if x > 1000000 then x = x // 1000000
  if x <= 0 then iterate
  o = oldSqrt(x); parse value newSqrt(x) with nw steps
  if steps > maxSteps then do; maxSteps = steps; worst = x; end
  if o == nw then same += 1
  else do
    diff += 1
    t = trueRoot(x)
    numeric digits 30
    if abs(o - t) < abs(nw - t) then oldBetter += 1
    else if abs(nw - t) < abs(o - t) then newBetter += 1
    if diff <= 5 then say '  differs x=' x 'old=' o 'new=' nw 'true=' format(t, , 12)
    numeric digits 9
  end
end
say 'values' n 'identical' same 'different' diff '(old closer' oldBetter || ', new closer' newBetter || ') most steps' maxSteps 'at x=' worst
exit
oldSqrt: procedure
  use arg x
  if x<=0 then return 0
  guess=x; if guess<1 then guess=1
  do 14; guess=(guess+(x/guess))/2; end
  return guess
newSqrt: procedure
  use arg x
  if x<=0 then return 0
  guess=x; if guess<1 then guess=1
  steps=0
  do forever
    next=(guess+(x/guess))/2; steps+=1
    if next>=guess then leave
    guess=next
  end
  return guess steps
trueRoot: procedure
  use arg x
  numeric digits 30
  g = x; if g < 1 then g = 1
  do 300; n = (g + x / g) / 2; if n = g then leave; g = n; end
  return g
