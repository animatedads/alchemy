/* finish_union.rex -- last stage of full_union.rex on a saved union render: cut the logged cat calls by catDb,
 * final speech AGC (-18 dBFS, up to +48 dB), Ogg Opus 16 kHz mono 32 kb/s.  Lets a long run finish without
 * redoing the voice stage.  Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 6 Nov 2026.
 * usage: finish_union.rex uni.f32 removedTsv workBase catDb outOgg */
numeric digits 16
parse arg uni rem base catDb outOgg
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
n=stream(uni,'C','QUERY SIZE')/4
cm=.stream~new(base'_catmute.tsv'); cm~open('WRITE REPLACE'); cm~lineout('start'||'09'x||'end'||'09'x||'lo'||'09'x||'hi'||'09'x||'w')
g=RxCalcPower(10,catDb/20,16); pos=0; nCat=0
r=.stream~new(rem); r~open('READ'); h=r~linein
do while r~lines>0
  parse value r~linein with kind '09'x xa '09'x xb '09'x .
  if kind<>'cat' then iterate
  sa=trunc(xa*8000); sb=min(n,trunc(xb*8000)); nCat+=1
  if sa>pos then cm~lineout(pos'09'x||sa'09'x||'0'||'09'x||'4000'||'09'x||'1')
  cm~lineout(sa'09'x||sb'09'x||'0'||'09'x||'4000'||'09'x||g); pos=sb
end
r~close
if pos<n then cm~lineout(pos'09'x||n'09'x||'0'||'09'x||'4000'||'09'x||'1')
cm~close
x=prov~renderSelection(uni,base'_catmute.tsv',base'_unc.f32',8000,256,64)
x=prov~speechAgc(base'_unc.f32',base'_out.f32',8000,-18,48,10,400,6,-1)
call sysFileDelete base'_unc.f32'
address system 'ffmpeg -v error -nostdin -y -f f32le -ar 8000 -ac 1 -i "'base'_out.f32" -c:a libopus -b:a 32k -application voip -ar 16000 "'outOgg'"'
call sysFileDelete base'_out.f32'
say filespec('name',outOgg) 'written,' nCat 'cat calls cut by' catDb 'dB'
::requires 'AudioV9SpatialNativeProvider.cls'
::requires 'rxmath' LIBRARY
