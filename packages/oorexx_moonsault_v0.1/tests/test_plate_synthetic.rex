/* Regression: the inverse ooRexx matcher must recover known synthetic stars
 * while three other stars remain withheld from the pair+third fit.
 * Validates first-frame projection stability across all catalogue iterations.
 */
numeric digits 17
p=.MoonsaultSkyPlate
stars=p~loadCatalog('../fixtures/yale_sydney_southwest_bright.csv',5.5)
sec=p~utcToUnix('2026-11-09T09:17:25Z')
times=.array~new
do delta over .array~of(0,425,880,892,1186)
  times~append(sec+delta)
end
names=.array~of('Nunki','Sargas','Kaus Australis','Shaula','Kaus Borealis','HD160578')
tracks=.array~new
do name over names
  star=.nil
  do st over stars
    if st['NAME']=name then do
      star=st;leave
    end
  end
  if star==.nil then do
    say 'FAIL missing known Yale star' name;exit 3
  end
  track=.array~new
  do timestamp over times
    pt=p~project(star,timestamp,-33.86,151.21,250,25)
    if pt==.nil then exit 4
    track~append(.array~of(trunc(960+900*pt[1]+0.5),trunc(540+900*pt[2]+0.5)))
  end
  tracks~append(track)
end
anchors=.array~of(tracks[1],tracks[2],tracks[3])
held=.array~new
do i=4 to 6
  withheld=.array~new
  do j=2 to 5
    withheld~append(tracks[i][j])
  end
  held~append(withheld)
end
models=p~matchThree(stars,anchors,times,-33.86,151.21,250,25,4,2)
if models~items<1 then do
  say 'FAIL exact simulated sky was not recovered';exit 7
end
rank=p~scoreHoldouts(models,stars,held,times,-33.86,151.21,250,25,3)
found=.false
do model over rank
  ids=model['NAMES']
  if ids[1]='Nunki' & ids[2]='Sargas' & ids[3]='Kaus Australis' then do
    say 'SYNTHETIC_KNOWN' ids[1] ids[2] ids[3] 'fit='format(model['RMS'],,3) -
      'heldout='model['HELDOUT_MATCHES'] 'heldout_rms='format(model['HELDOUT_RMS'],,3)
    if model['RMS']<1 & model['HELDOUT_MATCHES']=3 & model['HELDOUT_RMS']<1 then found=.true
  end
end
if \found then do
  say 'FAIL synthetic known stars and three heldouts mismatch';exit 8
end
say 'PASS: exact forward/inverse sky, 3 independent heldouts, integer pixel rounding'
::requires '../src/MoonsaultSkyPlate.cls'