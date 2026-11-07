/* mlines.rex -- multi-pitch lines and voice collections for one stretch (pattern plan steps 1-4 on multiF0).
 * Architecture: Tom Dyer (6 Nov 2026).  Coding: Claude (Opus 5.5).
 * multiF0 per 10 ms frame (up to 4 pitches, harmonics already cancelled); a line links a pitch to the previous
 * frame's nearest pitch within 3 % (gaps up to 30 ms bridged); a block = line >= 60 ms.  Levels: pitch bucket
 * 1/24, 1/12, 1/6, 1/3 octave; a collection = blocks sharing a bucket (Bag of keys).  Writes the blocks
 * (start end medianF0 meanStrength t:f0,t:f0,...) to outBlocks for the voice split (split.rex).
 * usage: mlines.rex enhF32 cleanStartClock fileStartClock refClock outBlocks */
numeric digits 16
parse arg enh c0 fs rc outB
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
a=hms2sec(c0); tf=hms2sec(fs); ref=hms2sec(rc); w=filespec('location',enh)
parse value value("MF0_RATIO",,"ENVIRONMENT") with mr .; if mr="" then mr=2.0
n=prov~multiF0(enh,w"ml.tsv",8000,1024,80,75,500,15,4,mr,0.25)
open=.array~new; done=.array~new
s=.stream~new(w'ml.tsv'); s~open('READ'); h=s~linein
do while s~lines>0
  c=s~linein~makeArray('09'x); t=c[1]
  picks=.array~new; loop i=2 to c~items by 2; if c[i]>0 then picks~append(c[i] c[i+1]); end
  still=.array~new
  loop ln over open                                   /* each open line takes its nearest pick within 3 % */
    parse value ln['LAST'] with lt lf
    best=0; bd=9
    loop i=1 to picks~items; parse value picks[i] with pf .; d=abs(pf/lf-1); if d<0.03 & d<bd then do; bd=d; best=i; end; end
    if best>0 then do; parse value picks[best] with pf ps; ln['PTS']~append(t pf ps); ln['LAST']=t pf; picks[best]='0 0'; still~append(ln); end
    else if t-lt<=0.03 then still~append(ln)
    else done~append(ln)
  end
  loop pk over picks; parse var pk pf ps; if pf>0 then do; ln=.directory~new; ln['PTS']=.array~of(t pf ps); ln['LAST']=t pf; still~append(ln); end; end
  open=still
end
s~close; loop ln over open; done~append(ln); end
blocks=.array~new
loop ln over done
  p=ln['PTS']; parse value p[1] with ta .; parse value p[p~items] with tb .
  if tb-ta<0.06 then iterate
  fz=.array~new; ss=0; loop pv over p; parse var pv . pf ps; fz~append(pf); ss+=ps; end
  fz=fz~sortWith(.NumericComparator~new)
  pts=''; loop pv over p; parse var pv pt pf .; pts=pts||pt':'pf','; end
  blocks~append(right(format(ta,,3),9,'0') format(tb,,3) fz[(fz~items+1)%2] format(ss/p~items,,2) pts~strip('T',','))
end
blocks=blocks~sort
o=.stream~new(outB); o~open('WRITE REPLACE'); loop b over blocks; o~lineout(b); end; o~close
say blocks~items 'blocks >= 60 ms from' done~items 'lines'
loop lv over .array~of(24,12,6,3)
  bag=.bag~new; mem=.directory~new
  loop b over blocks; parse var b ba bb bf .; k=trunc(lv*RxCalcLog(bf/60,16)/RxCalcLog(2,16)); bag~put(k); if \mem~hasIndex(k) then mem[k]=.array~new; mem[k]~append(ba bb); end
  line=''; big=0
  loop k over bag~uniqueIndexes~sortWith(.NumericComparator~new)
    secs=0; first=9e9; last=-1; loop mv over mem[k]; parse var mv x y; secs+=y-x; first=min(first,x); last=max(last,y); end
    if secs>=0.5 then big+=1
    line=line format(60*RxCalcPower(2,k/lv,16),,0)'-'format(60*RxCalcPower(2,(k+1)/lv,16),,0)'Hz:'bag~items(k)'/'format(secs,,1)'s@'format(a+first-ref,,0)'-'format(a+last-ref,,0)
  end
  say ''; say 'level 1/'lv 'octave:' bag~uniqueIndexes~items 'collections,' big 'with >= 0.5 s of voice'; say ' 'line
end
::requires 'FeedChain.cls'
::requires 'AudioV9SpatialNativeProvider.cls'
::requires 'rxmath' LIBRARY
