/* av_sync.rex -- FD TP8 audio/video offset from door/mechanical micro-movement events vs audio onsets.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 31 Oct 2026.
 * Video: SPASH_RECOVERED_VISUAL_EVENTS_362.tsv (FD events, video_peak_ms relative to first video frame).
 * Audio: Audio V9 native loud-event onsets of tp08 (local ms into the audio file).
 * Histogram of (audio onset - video peak) within +-maxS s, binMs bins; a real sync shows as one dominant bin.
 * usage: av_sync.rex eventsTsv onsetTsv outTsv [maxS] [binMs] [classes]
 */
numeric digits 16
parse arg evF onF outF maxS binMs classes
if maxS='' then maxS=3; if binMs='' then binMs=40; if classes='' then classes='FD_DOOR_MICRO_DEFLECTION FD_COMBINED_MECHANICAL_RESPONSE FD_GLOBAL_MICRO_VIBRATION'
vid=.array~new
s=.stream~new(evF); s~open('READ'); h=s~linein
do while s~lines>0
  c=s~linein~makeArray('09'x); if c~items<7 then iterate
  if c[1]<>'FD' | wordpos(c[5],classes)=0 then iterate
  vid~append(c[7]/1000 c[4] c[5])
end
s~close
aud=.array~new
s=.stream~new(onF); s~open('READ'); h=s~linein
do while s~lines>0
  l=s~linein; if l='' then iterate
  parse var l . '09'x . '09'x ms '09'x . '09'x . '09'x . '09'x pk '09'x . '09'x . '09'x . '09'x ratio '09'x .
  aud~append(ms/1000 pk ratio)
end
s~close
hist=.directory~new
do v over vid
  parse var v vt .
  do a over aud
    parse var a at .
    d=at-vt; if abs(d)>maxS then iterate
    b=trunc((d*1000+maxS*1000)/binMs)
    if hist~hasIndex(b) then hist[b]=hist[b]+1; else hist[b]=1
  end
end
o=.stream~new(outF); o~open('WRITE REPLACE'); o~lineout('audio_minus_video_ms'||'09'x||'pairs')
srt=.array~new; do b over hist~allIndexes; srt~append(right(hist[b],6,'0') b); end
srt=srt~sort
tot=0; do b over hist~allIndexes; tot+=hist[b]; end
do k=srt~items to max(1,srt~items-9) by -1
  parse value srt[k] with c b
  ms=b*binMs-maxS*1000+binMs/2
  o~lineout(ms'09'x||c+0); say 'offset' ms 'ms pairs' c+0
end
o~close
say 'video events' vid~items 'audio onsets' aud~items 'pairs' tot 'bins' hist~items 'mean/bin' format(tot/max(1,hist~items),,2)
