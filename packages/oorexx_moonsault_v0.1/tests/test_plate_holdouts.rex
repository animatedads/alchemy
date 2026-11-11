/* Three five-frame anchors, three withheld four-frame trajectories.
 * Only matched catalogue predictions count; no star fix is authorised. */
numeric digits 17
parse arg options
parse var options catalogue centerAz centerAlt
if catalogue='' then catalogue='../fixtures/yale_sydney_southwest_bright.csv'
if centerAz='' then centerAz=250
if centerAlt='' then centerAlt=25
root=.MoonsaultSkyPlate
cat=root~loadCatalog(catalogue,5.5)
sec=root~utcToUnix('2026-11-09T09:17:25Z')
times=.array~new
do d over .array~of(0,425,880,892,1186)
  times~append(sec+d)
end
obs=.array~of( -
  .array~of(.array~of(917,147),.array~of(903,164),.array~of(887,181),.array~of(887,182),.array~of(877,193)), -
  .array~of(.array~of(564,189),.array~of(548,196),.array~of(531,203),.array~of(531,203),.array~of(519,207)), -
  .array~of(.array~of(851,235),.array~of(835,249),.array~of(818,264),.array~of(817,264),.array~of(806,274)))
held=.array~of( -
  .array~of(.array~of(830,85),.array~of(816,101),.array~of(816,101),.array~of(807,111)), -
  .array~of(.array~of(536,97),.array~of(522,103),.array~of(522,104),.array~of(513,108)), -
  .array~of(.array~of(149,176),.array~of(127,171),.array~of(126,171),.array~of(112,167)))
models=root~matchThree(cat,obs,times,-33.86,151.21,centerAz,centerAlt,12,20)
rank=root~scoreHoldouts(models,cat,held,times,-33.86,151.21,centerAz,centerAlt,10)
say 'SKY_CENTRE' centerAz centerAlt 'CATALOGUE' cat~items 'REFERENCE_HYPOTHESES' models~items
limit=min(8,rank~items)
do i=1 to limit
  m=rank[i];n=m['NAMES']
  say 'CANDIDATE' i 'refs='n[1] n[2] n[3] 'fit='format(m['RMS'],,2) -
      'withheld='m['HELDOUT_MATCHES'] 'heldout_rms='format(m['HELDOUT_RMS'],,2)
  do t over m['HELDOUT']
    say '  HELDOUT' t['NAME'] format(t['RMS'],,3)
  end
end
if rank~items>0 then do
  if rank[1]['HELDOUT_MATCHES']>=2 then -
    say 'STATUS: WEAK_HELDOUT_MATCH_ONLY; CELESTIAL FIX REFUSED'
  else say 'STATUS: INSUFFICIENT HELDOUT MATCH; CELESTIAL FIX REFUSED'
end
else say 'STATUS: NO CATALOGUE MATCH; CELESTIAL FIX REFUSED'
if rank~items=0 then say 'PASS: no spurious catalogue identification'
else say 'PASS: hypotheses ranked by independent withheld evidence'
::requires '../src/MoonsaultSkyPlate.cls'