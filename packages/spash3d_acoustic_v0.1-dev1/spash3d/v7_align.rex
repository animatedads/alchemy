/* v7_align.rex -- place V7 Tier A clips on the FD and FC timelines (speech-band envelope template scan).
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 31 Oct 2026.
 * Long signals: continuous-chain 10 Hz speech-band envelopes (log, 3 s detrend) of FD and FC.
 * Template: each clip channel (ch1, ch2) -> 8 kHz -> 300-3400 Hz native band selection -> same envelope.
 * usage: v7_align.rex pcmDir envDir v7Dir clipListFile outTsv
 */
numeric digits 20
parse arg pcmDir envDir v7Dir listFile outTsv .
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
ch=fcfdChains(pcmDir,'CONTINUOUS')
longs=.directory~new; starts=.directory~new
do feed over .array~of('FD','FC')
  ec=.FeedChain~new(feed,10)
  do f over ch[feed]~files
    ec~add(envDir'/'filespec('name',f['PATH'])~changestr('.f32','')'_SPEECH.env.f32',f['START'])
  end
  path=envDir'/ALL_'feed'_SPEECH.env.f32'
  ec~writeWindow(ec~startSec,trunc((ec~endSec-ec~startSec)*10),path)
  longs[feed]=path; starts[feed]=ec~startSec
end
tmp=envDir'/v7tmp'
o=.stream~new(outTsv); o~open('WRITE REPLACE')
o~lineout('clip'||'09'x||'v7_start_s'||'09'x||'channel'||'09'x||'feed'||'09'x||'wall_clock'||'09'x||'v7_to_wall_offset_s'||'09'x||'score'||'09'x||'z'||'09'x||'second_z')
s=.stream~new(listFile); s~open('READ')
do while s~lines>0
  l=s~linein; if l='' then iterate
  parse var l clip v7start rel
  do chn=0 to 1
    wav=tmp'_c'chn'.f32'
    address system 'ffmpeg -v error -nostdin -y -i "'v7Dir'/'rel'" -af "pan=mono|c0=c'chn'" -ar 8000 -f f32le "'wav'"'
    n=stream(wav,'C','QUERY SIZE')%4
    if n<8000*8 then iterate
    mask=tmp'.mask.tsv'
    m=.stream~new(mask); m~open('WRITE REPLACE'); m~lineout('s'||'09'x||'e'||'09'x||'lo'||'09'x||'hi'||'09'x||'w'); m~lineout('0'||'09'x||n||'09'x||'300'||'09'x||'3400'||'09'x||'1'); m~close
    sel=tmp'_sel.f32'; x=prov~renderSelection(wav,mask,sel,8000,256,64)
    env=tmp'_env.f32'; x=prov~envelope(sel,env,800,1,31)
    do feed over .array~of('FD','FC')
      r=prov~templateScan(longs[feed],env,1,2)
      if r~items=0 then iterate
      wall=starts[feed]+r[1]['OFFSET']/10
      z2='NA'; if r~items>1 then z2=format(r[2]['Z'],,1)
      line=clip'09'x||v7start'09'x||'ch'chn+1'09'x||feed'09'x||sec2hms(wall)'09'x||format(wall-v7start,,1)'09'x||format(r[1]['SCORE'],,3)'09'x||format(r[1]['Z'],,1)'09'x||z2
      o~lineout(line); say line
    end
  end
end
s~close; o~close
exit 0
::requires 'FeedChain.cls'
::requires 'AudioV9SpatialNativeProvider.cls'
