/* v7_voice_scan.rex -- scan V7 Tier A clips against voice profiles (voice-profile SLAM).
 * Architecture: Tom Dyer (5 Nov 2026).  Coding: Claude (Opus 5.5).
 * Per clip and per channel (1 and 2): decode to 8 kHz mono (container decode only), native voice features
 * (YIN 50-500 Hz, 50 ms frames, 10 ms step, 32 shape bands), voiced runs (>= 8 frames, octave errors removed).
 * Per run: median F0; each profile's run score; STRICT = best profile whose own-window threshold is met;
 * PITCH_ONLY = profiles whose p5-p95 pitch window contains the run's median F0 (channel-proof, weaker).
 * Output TSV row per run.  Temporary PCM/feature files are deleted after each clip.
 * usage: v7_voice_scan.rex clipList shard nShards outTsv workDir profile [profile ...] */
numeric digits 16
parse arg listF shard nShards outF w profs
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
profA=.array~new; do pf over profs~space~makeArray(' '); profA~append(.VoiceProfile~load(pf)); end
o=.stream~new(outF); o~open('WRITE REPLACE')
hdr='clip'||'09'x||'v7_start'||'09'x||'fc_time'||'09'x||'channel'||'09'x||'run_start_s'||'09'x||'run_end_s'||'09'x||'frames'||'09'x||'median_f0'
do p over profA; hdr=hdr||'09'x||p~label; end
o~lineout(hdr||'09'x||'strict'||'09'x||'pitch_only'||'09'x||'flat_fraction')
s=.stream~new(listF); s~open('READ'); i=0
do while s~lines>0
  f=s~linein; if f='' then iterate; i+=1; if (i-1)//nShards<>shard-1 then iterate
  nm=filespec('name',f); parse var nm id '_t' tt '.ogg'
  t=substr(tt,1,2)*3600+substr(tt,3,2)*60+substr(tt,5,2); fc=sec2hms(t+28800)
  do ch=1 to 2
    pcm=w'/s'shard'.f32'; vf=w'/s'shard'.vf.tsv'
    address system 'ffmpeg -v error -nostdin -y -i "'f'" -af "pan=mono|c0=c'ch-1'" -ar 8000 -f f32le "'pcm'"'
    n=prov~voiceFeatures(pcm,vf,8000,400,80,50,500,0.25,32)
    .VoiceProfile~cache~remove(vf)
    fr=.VoiceProfile~voicedFrames(vf); rs=.VoiceProfile~runsOf(fr,8)
    do r over rs
      a=.array~new; do x over r; a~append(x['F0']); end; a=a~sortWith(.NumericComparator~new); med=a[(a~items+1)%2]
      line=nm'09'x||sec2hms(t)'09'x||fc'09'x||ch'09'x||format(r[1]['T'],,2)'09'x||format(r[r~items]['T'],,2)'09'x||r~items'09'x||format(med,,1)
      best='NONE'; bs=-9e9; po=''
      do p over profA
        sc=p~runScore(r); line=line||'09'x||format(sc,,3)
        if sc>=p~threshold & sc>bs then do; bs=sc; best=p~label; end
        if med>=p~winLo & med<=p~winHi then po=po||p~label||','
      end
      if po='' then po='NONE'; else po=po~strip('T',',')
      ff=flatFraction(r)
      if ff>=0.8 then do; best='TONE'; po='TONE'; end      /* machine tone: pitch does not move like a voice */
      o~lineout(line||'09'x||best||'09'x||po||'09'x||format(ff,,2))
    end
  end
  call stream outF,'C','FLUSH'
end
s~close; o~close
say 'shard' shard 'done' i
exit 0
/* fraction of frames whose pitch, with the previous 5 frames, spans less than 0.2 semitones.
   Sliding window is a queue (Tom's method): it fills over the first 5 frames; only full windows are judged. */
flatFraction: procedure
  use arg run
  recent=.queue~new; flat=0; judged=0
  loop fr over run
    if recent~items=5 then do
      lo=fr['F0']; hi=fr['F0']
      loop prev over recent; lo=min(lo,prev); hi=max(hi,prev); end
      judged+=1; if 12*RxCalcLog(hi/lo,16)/RxCalcLog(2,16)<0.2 then flat+=1
    end
    recent~queue(fr['F0']); if recent~items>5 then recent~pull
  end
  if judged=0 then return 0
  return flat/judged
::requires 'rxmath' LIBRARY
::requires 'VoiceProfile.cls'
::requires 'FeedChain.cls'
::requires 'AudioV9SpatialNativeProvider.cls'
