/* fd_pick.rex -- pick FD's own best moments from the lifted frames of fd_scan.rex.
 * Architecture: Tom Dyer (5 Nov 2026: FD's own moments, 6-10 s+ each, separate files).  Coding: Claude (Opus 5.5).
 * Per profile: lifted frames joined into stretches (gaps <= 0.3 s bridged), stretches < 0.15 s dropped;
 * a stretch >= 0.4 s whose pitch barely moves (p90/p10 < 1.015) is a machine tone, dropped.
 * Each stretch opens a window of winS s centred on it; windows from all profiles, in time order, merge while
 * they overlap and the merged window stays <= maxWinS.  Score = sum of mean contrast x stretch length.
 * Windows within `guard` s of an already rendered FD moment (excludeTsv: NN feed_time length_s) are skipped.
 * Best nMoments, renumbered from firstNN in time order.  Writes jobs TSV for moment_render.rex (FD) and one for
 * FC (FC = FD + 0.9065 + 0.1331 h on the continuous chains), plus an index with scores and profiles.
 * usage: fd_pick.rex scanDir excludeTsv outDir nMoments firstNN winS maxWinS guard label [label ...] */
numeric digits 16
parse arg sd exc outD nMom firstNN winS maxWinS guard labs
winList=.array~new
loop lab over labs~space~makeArray(' ')
  loop tp over .array~of('tp06','tp07','tp08','tp09')
    f=sd'/'tp'_'lab'.lifted.tsv'; if stream(f,'C','QUERY EXISTS')='' then iterate
    s=.stream~new(f); s~open('READ'); cur=.nil
    do while s~lines>0
      parse value s~linein with t '09'x f0 '09'x con
      if cur<>.nil then if t-cur['B']<=0.3 then do; cur['B']=t; cur['C']+=con; cur['N']+=1; cur['F']~append(f0+0); iterate; end
      if cur<>.nil then call close
      cur=.directory~new; cur['A']=t; cur['B']=t; cur['C']=con; cur['N']=1; cur['F']=.array~of(f0+0)
    end
    s~close; if cur<>.nil then call close
  end
end
/* merge in time order */
winList=winList~sort; merged=.array~new
loop wv over winList
  parse var wv a b sc lab
  a=a+0
  if merged~items>0 then do
    parse value merged[merged~items] with ma mb msc mlabs
    if a<=mb & max(mb,b)-ma<=maxWinS then do
      if pos(','||lab||',', ','||mlabs||',')=0 then mlabs=mlabs||','||lab
      merged[merged~items]=ma max(mb,b) (msc+sc) mlabs; iterate
    end
  end
  merged~append(a b sc lab)
end
/* exclusions */
ex=.array~new
if exc<>'-' then do
  e=.stream~new(exc); e~open('READ'); h=e~linein
  do while e~lines>0; parse value e~linein with . '09'x et '09'x el .; t0=hms2sec(et~substr(1,8))+('0'et~substr(9)); ex~append(t0 (t0+el)); end
  e~close
end
cand=.array~new
loop mv over merged
  parse var mv a b sc mlabs
  skip=.false
  loop xv over ex; parse var xv xa xb; if b>xa-guard & a<xb+guard then skip=.true; end
  if \skip then cand~append(right(format(sc,,4),14,'0')||'|'||a||'|'||b||'|'||mlabs)
end
cand=cand~sortWith(.DescendingComparator~new)
keep=.array~new
loop c over cand
  parse var c sc '|' a '|' b '|' mlabs
  keep~append(right(format(a,,3),12,'0')||'|'||b||'|'||sc||'|'||mlabs)
  if keep~items>=nMom then leave
end
keep=keep~sort
jf=.stream~new(outD'/jobs_fd_new.tsv'); jf~open('WRITE REPLACE'); jf~lineout('NN'||'09'x||'feed_time'||'09'x||'length_s')
jc=.stream~new(outD'/jobs_fc_new.tsv'); jc~open('WRITE REPLACE'); jc~lineout('NN'||'09'x||'feed_time'||'09'x||'length_s')
ix=.stream~new(outD'/fd_own_index.tsv'); ix~open('WRITE REPLACE')
ix~lineout('NN'||'09'x||'fd_time'||'09'x||'fc_time_clock'||'09'x||'length_s'||'09'x||'score'||'09'x||'profiles_locked')
nn=firstNN-1
loop k over keep
  parse var k a '|' b '|' sc '|' mlabs
  a=a+0; nn+=1; len=format(b-a,,1); off=0.9065+0.1331*(a-12*3600)/3600
  jf~lineout(nn'09'x||sec2hms(a)'09'x||len); jc~lineout(nn'09'x||sec2hms(a+off)'09'x||len)
  ix~lineout(nn'09'x||sec2hms(a)'09'x||sec2hms(a+off)'09'x||len'09'x||format(sc,,2)'09'x||mlabs~changestr('VOICE_',''))
end
jf~close; jc~close; ix~close
say keep~items 'FD moments picked from' merged~items 'windows (' cand~items 'after exclusions )'
exit 0
close:
  if cur['B']-cur['A']<0.15 then return
  if cur['B']-cur['A']>=0.4 then do
    fz=cur['F']~sortWith(.NumericComparator~new); q10=fz[max(1,trunc(fz~items*0.1))]; q90=fz[max(1,trunc(fz~items*0.9))]
    if q90/q10<1.015 then return
  end
  pa=cur['A']; pb=cur['B']; cc=(pa+pb)/2; wa=cc-winS/2; wb=wa+winS
  winList~append(right(format(wa,,3),12,'0') format(wb,,3) (cur['C']/cur['N'])*(pb-pa) lab)
  return
::requires 'FeedChain.cls'
