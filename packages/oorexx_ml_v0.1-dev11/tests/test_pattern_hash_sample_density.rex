base=.array~of(0,1,3,7,10,7,3,1)
/* same piecewise-linear circular curve sampled at twice the density */
stretched=.array~new
n=base~items
do j=0 to 2*n-1
  phase=j/2; lo=trunc(phase)+1; frac=phase-trunc(phase); hi=lo+1; if hi>n then hi=1
  stretched~append(base[lo]+frac*(base[hi]-base[lo]))
end
s=.MLPatternHashSchema~new(.MLPatternHashPolicy~new(32,32,1,4,8,.true,.false),'PATTERN-DENSITY')
a=s~encode(base); b=s~encode(stretched); d=s~difference(a,b)
call eq a~key,b~key,'sample-density change preserves hash after angular resampling'
call truth d~exact,'sample-density pattern difference exact'
say 'PASS test_pattern_hash_sample_density'
exit 0
eq: procedure; use arg a,e,l; if a\==e then do; say 'FAIL' l; exit 1; end; return
truth: procedure; use arg v,l; if \v then do; say 'FAIL' l; exit 1; end; return
::requires "OorexxML.cls"
