/* v7_profile_render.rex -- punch every voice profile across the V7 clips: one render per profile per clip.
 * Architecture: Tom Dyer (5 Nov 2026): use each audio profile as a tone bucket, cut all other tones to 20 %
 *   of peak; each profile pulls its own side of a conversation / call.  Coding: Claude (Opus 5.5).
 * Per clip (channel 1): decode to 8 kHz (container decode only); bird-screech (tonal burst) suppression.
 * Per profile P:
 *   pitch track of P's voice inside P's own window (native harmonic contrast, 512/80, 20 harmonics, >= 0.3);
 *   a frame is lifted when that pitch exists, is typical of P (bucket probability >= P's own p20), and is not
 *   the 386.8 Hz device or its half (193.4 Hz) within 1 %;
 *   native voice mask: P's harmonics kept, everything else at -14 dB (20 % of peak), pure comb (no shape term).
 * Writes <work>/<clipId>_<label>.f32 and <work>/<clipId>_<label>.frames.tsv; the reel builder uses them.
 * usage: v7_profile_render.rex clipList shard nShards workDir profile [profile ...] */
numeric digits 16
parse arg listF shard nShards w profs
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
profA=.array~new; do pf over profs~space~makeArray(' '); profA~append(.VoiceProfile~load(pf)); end
floors=.directory~new; loop p over profA; floors[p~label]=p~pitchFloor(20); end
flat=w'/flat_'shard'.shape'; q=.stream~new(flat); q~open('WRITE REPLACE'); q~lineout('100'||'09'x||'1'); q~lineout('3800'||'09'x||'1'); q~close
s=.stream~new(listF); s~open('READ'); i=0
do while s~lines>0
  f=s~linein; if f='' then iterate; i+=1; if (i-1)//nShards<>shard-1 then iterate
  id=filespec('name',f)~changestr('.ogg','')
  raw=w'/s'shard'_raw.f32'; pcm=w'/'id'_ch1.f32'
  address system 'ffmpeg -v error -nostdin -y -i "'f'" -af "pan=mono|c0=c0" -ar 8000 -f f32le "'raw'"'
  nb=prov~suppressTonalBursts(raw,pcm,w'/'id'_screech.tsv')
  loop p over profA
    lab=p~label; lo=p~winLo; hi=p~winHi
    ht=w'/s'shard'_h.tsv'; x=prov~harmonicF0(pcm,ht,8000,512,80,lo,hi,20,2000,0.3)
    ft=w'/'id'_'lab'.frames.tsv'; o=.stream~new(ft); o~open('WRITE REPLACE')
    hs=.stream~new(ht); hs~open('READ'); h=hs~linein; lifted=0
    do while hs~lines>0
      parse value hs~linein with t '09'x f0 '09'x con
      wt=0
      if f0>0 then do
        k=.VoiceProfile~bucket(f0)
        if k>0 then if p~pitch[k]>=floors[lab] then wt=1
        if abs(f0/386.8-1)<0.01 | abs(f0/193.4-1)<0.01 then wt=0      /* the device and its half */
      end
      lifted+=wt; o~lineout(t'09'x||wt'09'x||f0'09'x||con)
    end
    hs~close; o~close
    x=prov~voiceMask(pcm,w'/'id'_'lab'.f32',ft,flat,8000,512,128,-14,15,40,100,3800,0)
  end
  call sysFileDelete raw
end
s~close
say 'shard' shard 'done' i
exit 0
::requires 'VoiceProfile.cls'
::requires 'AudioV9SpatialNativeProvider.cls'
