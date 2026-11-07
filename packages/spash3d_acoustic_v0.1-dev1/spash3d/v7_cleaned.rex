/* v7_cleaned.rex -- h_cleaned for the FC (V7) moments: amp, filter, amp, no voice profile (no harmonic comb,
 * so no robotic edge).  Architecture: Tom Dyer (5 Nov 2026).  Coding: Claude (Opus 5.5).
 * Source: the per-clip V7 channel-1 decode (FC) already through screech suppression (v7_profile_render).
 * amp: native speech AGC (-20 dBFS, up to +36 dB); filter: native enhancer (90-3600 Hz) + speech tilt (as
 * moment_render.rex); amp: moment cut, native speech AGC (-18 dBFS, up to +48 dB); 16 kHz MP3.
 * usage: v7_cleaned.rex momentsIndex workDir renderDir outDir pad */
numeric digits 16
parse arg mix w rd outD pad
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
m=.stream~new(mix); m~open('READ'); h=m~linein; done=0
do while m~lines>0
  parse value m~linein with nn '09'x fct '09'x id '09'x a '09'x len '09'x .
  src=rd'/'id'_ch1.f32'; clipS=stream(src,'C','QUERY SIZE')/4/8000
  s0=max(0,a-pad); s1=min(clipS,a+len+pad); n=trunc((s1-s0)*8000)
  st=.stream~new(src); st~open('READ'); d=st~charin(trunc(s0*8000)*4+1,n*4); st~close
  raw=w'/vc_raw.f32'; o=.stream~new(raw); o~open('WRITE REPLACE'); o~charout(d); o~close
  x=prov~speechAgc(raw,w'/vc_amp.f32',8000,-20,36,10,400,6,-1)
  x=prov~enhance(w'/vc_amp.f32',w'/vc_enh.f32',8000,256,64,1.5,0.98,1.0,0.1,90,3600)
  tm=.stream~new(w'/vc_tilt.tsv'); tm~open('WRITE REPLACE'); tm~lineout('start'||'09'x||'end'||'09'x||'lo'||'09'x||'hi'||'09'x||'w')
  loop row over .array~of('90 3600 0.15','250 3600 0.4','600 3600 0.8','1200 3600 1')
    parse var row tlo thi tw; tm~lineout('0'||'09'x||n||'09'x||tlo||'09'x||thi||'09'x||tw)
  end
  tm~close
  x=prov~renderSelection(w'/vc_enh.f32',w'/vc_tilt.tsv',w'/vc_cln.f32',8000,256,64)
  cs=.stream~new(w'/vc_cln.f32'); cs~open('READ'); d=cs~charin(trunc((a-s0)*8000)*4+1,trunc(len*8000)*4); cs~close
  c=.stream~new(w'/vc_cut.f32'); c~open('WRITE REPLACE'); c~charout(d); c~close
  x=prov~speechAgc(w'/vc_cut.f32',w'/vc_out.f32',8000,-18,48,10,400,6,-1)
  parse var fct hh ':' mm ':' ss .; tag=nn'_FC_'hh'-'mm'-'right(trunc(ss),2,'0')
  address system 'ffmpeg -v error -nostdin -y -f f32le -ar 8000 -ac 1 -i "'w'/vc_out.f32" -c:a libmp3lame -b:a 48k -ar 16000 "'outD'/'tag'_h_cleaned.mp3"'
  done+=1
end
m~close
say done 'V7 h_cleaned moments written to' outD
::requires 'AudioV9SpatialNativeProvider.cls'
