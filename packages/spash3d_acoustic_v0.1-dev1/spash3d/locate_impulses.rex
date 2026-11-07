/* locate_impulses.rex -- absolute FD/FC delay for impulses in door-anchored files -> consistent Physics World positions.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 31 Oct 2026.
 * Anchors (clock residual delta per FC file, from F11-door-consistent impulses; door path +26.01 ms):
 *   tp31 -26.7 ms (3 impulses), tp29 -28.0 ms (1), tp34 +80.0 ms (1).
 * physical delay = onset lag - delta.  A position P is consistent when |tau(P) - physical| <= tolMs,
 *   tau(P) = FC first arrival - FD first arrival (Physics World F11 v0.4 map table).
 * usage: locate_impulses.rex onsetTsv doorBangsTsv outTsv [tolMs]
 */
numeric digits 16
parse arg onF dbF outF tol .
if tol='' then tol=2
anchor=.directory~new; anchor['tp31']=-26.7; anchor['tp29']=-28.0; anchor['tp34']=80.0
maps=.array~new; do w over value('SPASH_MAPS',,'ENVIRONMENT')~space~makeArray(' '); maps~append(w); end
pts=.Spash3DWindow~loadMap(maps)
/* level ratio per event from door_bangs.tsv (FC/FD dB, broadband 250 ms) */
lvl=.directory~new
s=.stream~new(dbF); s~open('READ'); h=s~linein
do while s~lines>0; c=s~linein~makeArray('09'x); if c~items>=9 then lvl[c[1]]=c[9]; end
s~close
o=.stream~new(outF); o~open('WRITE REPLACE')
o~lineout('fd_time'||'09'x||'fc_file'||'09'x||'onset_lag_ms'||'09'x||'delta_ms'||'09'x||'physical_ms'||'09'x||'fc_over_fd_db'||'09'x||'n_consistent'||'09'x||'regions'||'09'x||'best_positions')
s=.stream~new(onF); s~open('READ'); h=s~linein
do while s~lines>0
  c=s~linein~makeArray('09'x); if c~items<5 then iterate
  f=c[2]; if \anchor~hasIndex(f) | c[5]='NA' then iterate
  if c~items>=11 then if c[11]='WIND_FC' then iterate      /* wind buffeting at FC does not propagate */
  phys=c[5]-anchor[f]
  hits=.array~new; reg=.directory~new
  do id over pts~allIndexes
    p=pts[id]; if p['FD']~items=0 | p['FC']~items=0 then iterate
    tau=p['FC'][1]['DELAY']-p['FD'][1]['DELAY']
    /* first arrival = earliest, not strongest: */
    tfd=9e9; do a over p['FD']; tfd=min(tfd,a['DELAY']); end
    tfc=9e9; do a over p['FC']; tfc=min(tfc,a['DELAY']); end
    tau=tfc-tfd
    if abs(tau-phys)<=tol then do
      r=p['ROOM']; if reg~hasIndex(r) then reg[r]=reg[r]+1; else reg[r]=1
      hits~append(format(abs(tau-phys),,2) p['X']','p['Y']','p['Z']'('r')')
    end
  end
  hits=hits~sort
  rs=''; do k over reg~allIndexes~sort; rs=rs||k':'reg[k]' '; end
  bp=''; do j=1 to min(5,hits~items); bp=bp||hits[j]~word(2)' '; end
  lv='NA'; if lvl~hasIndex(c[1]) then lv=lvl[c[1]]
  o~lineout(c[1]'09'x||f'09'x||c[5]'09'x||anchor[f]'09'x||format(phys,,1)'09'x||lv'09'x||hits~items'09'x||rs~strip'09'x||bp~strip)
end
s~close; o~close
exit 0
::requires 'Spash3DWindow.cls'
