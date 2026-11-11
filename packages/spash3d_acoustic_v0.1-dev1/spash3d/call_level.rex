/* call_level.rex -- per-clip FD/FC speech-band level signature (a phone speaker is a fixed source).
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 31 Oct 2026.
 * Speech band 300-3400 Hz (native render_select); 100 ms frames (native band_blocks).
 * Per feed: p90 frame level in the clip window, minus the median frame level of the surrounding 60 s (background).
 * usage: call_level.rex labelsTsv clipStartOffsetS clipSec */
numeric digits 16
parse arg labF pre clipS .
parse value value('SPASH_CLOCK',,'ENVIRONMENT') with cA cB
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
ch=fcfdChains(value('SPASH_PCM',,'ENVIRONMENT'),'CONTINUOUS'); work=value('SPASH_WORK',,'ENVIRONMENT')
say 'clip label'~left(22) 'FD_excess'~right(10) 'FC_excess'~right(10) 'FCp90-FDp90'~right(12) 'FD_active_frac'~right(15)
s=.stream~new(labF); s~open('READ'); h=s~linein
do while s~lines>0
  c=s~linein~makeArray('09'x); if c~items<3 then iterate
  t=hms2sec(c[2]~changestr(':','')~left(6))+('0'c[2]~substr(9))~changestr('0.','.')  /* keep fraction */
  t=t+pre; off=cA+cB*(t-hms2sec('120000'))/3600
  r=.directory~new
  do feed over .array~of('FD','FC')
    tt=t; if feed='FC' then tt=t+off
    w=work'/cl_'feed'.f32'; ch[feed]~writeWindow(tt-30+clipS/2,60*8000,w)
    lv=levels(prov,w,work'/cl_'feed)
    bg=lv~copy~sortWith(.NumericComparator~new); bg=bg[(bg~items+1)%2]
    i0=trunc((30-clipS/2)*10)+1; cl=.array~new; do k=i0 to i0+clipS*10-1; cl~append(lv[k]); end
    so=cl~copy~sortWith(.NumericComparator~new); p90=so[trunc(so~items*0.9)]
    act=0; do v over cl; if v>=bg+10 then act+=1; end
    r[feed'_P90']=p90; r[feed'_EX']=p90-bg; r[feed'_ACT']=act/cl~items
  end
  say (c[1] c[3])~left(22) format(r['FD_EX'],,1)~right(10) format(r['FC_EX'],,1)~right(10) format(r['FC_P90']-r['FD_P90'],,1)~right(12) format(r['FD_ACT'],,2)~right(15)
end
exit 0
levels: procedure
  use arg prov, f, base
  n=.stream~new(f)~query('size')/4
  m=.stream~new(base'.mask.tsv'); m~open('WRITE REPLACE'); m~lineout('s'||'09'x||'e'||'09'x||'lo'||'09'x||'hi'||'09'x||'w'); m~lineout(0'09'x||n'09'x||300'09'x||3400'09'x||1); m~close
  sel=base'.sp.f32'; x=prov~renderSelection(f,base'.mask.tsv',sel,8000,256,64)
  bl=prov~bandBlocks(sel,8000,256,200,4,1,300,3400)
  out=.array~new; do d over bl; out~append(10*RxCalcLog10(max(d['BANDS'][1],1e-20),16)); end
  return out
::requires 'FeedChain.cls'
::requires 'AudioV9SpatialNativeProvider.cls'
::requires 'rxmath' LIBRARY
