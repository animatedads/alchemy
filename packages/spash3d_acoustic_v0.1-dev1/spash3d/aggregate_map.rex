/* aggregate_map.rex -- where do the reviewed V7 Tier A voices map?  Sum over all known-speech windows.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 31 Oct 2026.
 * usage: aggregate_map.rex outPrefix in1.tsv [in2.tsv ...]
 * Outputs: <prefix>_units.tsv (best-position unit counts; top-10 unit shares), <prefix>_heat.tsv, <prefix>_heat.svg
 */
numeric digits 16
parse arg prefix rest
best=.directory~new; top=.directory~new; heat=.directory~new; n=0; deltas=.array~new; agree=.directory~new
do f over rest~space~makeArray(' ')
  s=.stream~new(f); s~open('READ'); h=s~linein
  do while s~lines>0
    l=s~linein; if l='' then iterate
    c=l~makeArray('09'x); n+=1
    u=c[9]; if u='Stairs' then u='STAIRWELL_SHAFT'
    if best~hasIndex(u) then best[u]=best[u]+1; else best[u]=1
    names=.array~of('UNIT_AEF','UNIT_OTHER','STREET','REAR','STAIRWELL_SHAFT')
    do k=1 to 5; v=c[11+k]+0; if top~hasIndex(names[k]) then top[names[k]]=top[names[k]]+v; else top[names[k]]=v; end
    deltas~append(c[4]+0)
    do p over c[18]~makeArray(';'); if p='' then iterate; if heat~hasIndex(p) then heat[p]=heat[p]+1; else heat[p]=1; end
    /* independent check: measured FC/FD level (650-1000 Hz band) vs the side of the map's top 10 */
    lv=c[17]; fcN=0; fdN=0
    do p over c[18]~makeArray(';')
      if p='' then iterate
      parse var p x ',' y ',' z
      if (x-14.267)**2+(y-9.449)**2 < (x-7.014)**2+(y-3.422)**2 then fcN+=1; else fdN+=1
    end
    if datatype(lv,'N') then do
      lside='AMBIG'; if lv>=6 then lside='FC'; if lv<=-6 then lside='FD'
      mside='AMBIG'; if fcN>=7 then mside='FC'; if fdN>=7 then mside='FD'
      key=lside'/'mside; if agree~hasIndex(key) then agree[key]=agree[key]+1; else agree[key]=1
    end
  end
  s~close
end
o=.stream~new(prefix'_units.tsv'); o~open('WRITE REPLACE')
o~lineout('windows'||'09'x||n)
o~lineout('unit_or_region'||'09'x||'best_position_count'||'09'x||'best_share'||'09'x||'top10_share')
tt=0; do k over top~allIndexes; tt+=top[k]; end
do k over .array~of('UNIT_AEF','UNIT_OTHER','STREET','REAR','STAIRWELL_SHAFT')
  b=0; if best~hasIndex(k) then b=best[k]
  o~lineout(k'09'x||b'09'x||format(100*b/n,,1)'%'||'09'x||format(100*top[k]/max(1,tt),,1)'%')
end
d=deltas~sortWith(.NumericComparator~new)
o~lineout('clock_residual_delta_ms_median'||'09'x||d[(d~items+1)%2])
o~lineout('level_side/map_side (level: FC/FD >= +6 dB => FC, <= -6 dB => FD; map: >= 7 of top 10 on that side)')
do k over agree~allIndexes~sort; o~lineout(k'09'x||agree[k]); end
ok=0; bad=0
do k over agree~allIndexes; parse var k ls '/' ms; if ls='AMBIG' | ms='AMBIG' then iterate; if ls=ms then ok+=agree[k]; else bad+=agree[k]; end
o~lineout('decided_both_agree'||'09'x||ok); o~lineout('decided_both_disagree'||'09'x||bad)
o~close
o=.stream~new(prefix'_heat.tsv'); o~open('WRITE REPLACE'); o~lineout('x,y,z'||'09'x||'top10_count'||'09'x||'share_of_windows')
idx=heat~allIndexes; mx=1; do k over idx; if heat[k]>mx then mx=heat[k]; o~lineout(k'09'x||heat[k]'09'x||format(100*heat[k]/n,,1)'%'); end
o~close
/* svg: plan, cells coloured by top-10 frequency (max over z) */
sc=34; ox=20; oy=40; W=ox*2+21*sc; H=oy+18*sc+40
sv=.mutablebuffer~new
sv~append('<svg xmlns="http://www.w3.org/2000/svg" width="'W'" height="'H'" font-family="sans-serif" font-size="11"><rect width="100%" height="100%" fill="#fff"/>')
sv~append('<text x="'ox'" y="20" font-size="13">V7 Tier A voices (n='n' windows): how often each position is in a window''s top 10</text>')
cell=.directory~new
do k over idx; parse var k x ',' y ',' z; key=x','y; v=heat[k]; if cell~hasIndex(key) then do; if v>cell[key] then cell[key]=v; end; else cell[key]=v; end
do key over cell~allIndexes
  parse var key x ',' y; v=cell[key]/mx
  sz=1.0
  red=trunc(255*v); blue=trunc(255*(1-v))
  sv~append('<rect x="'format(ox+(x-sz/2)*sc,,1)'" y="'format(oy+(y+4-sz/2)*sc,,1)'" width="'format(sz*sc,,1)'" height="'format(sz*sc,,1)'" fill="rgb('red',40,'blue')" fill-opacity="'format(0.15+0.75*v,,2)'"/>')
end
rooms=.array~of('A 142 161 383 370','E 76 371 280 699','F 294 371 495 699','B 510 176 725 699','C 744 161 960 371','D 976 161 1230 371','G 744 458 921 699','H 1078 382 1217 517','I 1001 516 1250 766','Stairs 398 145 486 371')
do rm over rooms
  parse var rm nm x1 y1 x2 y2
  a=.F11SceneV04~pxToM(x1,y1); b=.F11SceneV04~pxToM(x2,y2); parse var a mx1 my1; parse var b mx2 my2
  if wordpos(nm,'A E F')>0 then col='#c00'; else col='#000'
  sv~append('<rect x="'format(ox+mx1*sc,,1)'" y="'format(oy+(my1+4)*sc,,1)'" width="'format((mx2-mx1)*sc,,1)'" height="'format((my2-my1)*sc,,1)'" fill="none" stroke="'col'" stroke-width="1.5"/>')
  sv~append('<text x="'format(ox+mx1*sc+3,,1)'" y="'format(oy+(my1+4)*sc+12,,1)'">'nm'</text>')
end
do mic over .array~of('FC 14.267 9.449','FD 7.014 3.422')
  parse var mic nm x y
  sv~append('<circle cx="'format(ox+x*sc,,1)'" cy="'format(oy+(y+4)*sc,,1)'" r="5" fill="#0a0"/><text x="'format(ox+x*sc+7,,1)'" y="'format(oy+(y+4)*sc-6,,1)'" font-weight="bold">'nm'</text>')
end
sv~append('<text x="'ox'" y="'H-12'">red outline: unit A+E+F | rear y&lt;0 | street y&gt;10.2 | colour: share of windows (blue rare, red frequent)</text></svg>')
call sysFileDelete prefix'_heat.svg'
o=.stream~new(prefix'_heat.svg'); o~open('WRITE REPLACE'); o~charout(sv~string); o~close
say 'windows' n
exit 0
::requires 'F11SceneV04.cls'
