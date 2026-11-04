/* Check native PTS-window/geometry/clock continuity and trailing partial. */
tab='09'x
input=.stream~new('tests/stream_GOOD.windows.tsv')
call chk input~open('READ')>=0,'window output available'
header=input~linein
call chk pos('audio_clock_authority',header)>0,'unaligned clock explicit in schema'
observed=.directory~new
count=0
sum=.directory~new
sum['250']=0;sum['500']=0;sum['1000']=0;sum['2000']=0
do while input~lines>0
  line=input~linein
  if line=='' then iterate
  f=line~makeArray(tab)
  key=f[3]||':'||f[4]
  observed[key]=f
  count=count+1
  sum[f[3]]=sum[f[3]]+1
  call chk f[20]=='NOT_ALIGNED','no synthetic audio/video clock'
  call chk f[2]=='synthetic.mp4','window retains source identity'
  call chk f[1]=='spash.visual.raw-window/0.2','stream schema version'
end
input~close
call chk count==23,'four PTS widths retain 22 complete plus trailing partial window'
call chk sum['250']==12 & sum['500']==6 & sum['1000']==3 & sum['2000']==2,'per-width partition counts include final partial'
a=observed['250:0']
call chk a[21]=='VALID_RAW_PTS_WINDOW','early stable 250ms interval valid'
call chk abs(a[7]-250)<.01 & abs(a[8]-250)<.01,'full stable coverage'
call chk abs(a[12]-2*a[11])<.001,'door travel follows actual interval fractions'
b=observed['1000:0']
call chk b[21]=='VALID_RAW_PTS_WINDOW','first 1000ms stable'
c=observed['2000:0']
call chk c[21]=='INVALID_GEOMETRY_OR_GAP','mixed epoch never admitted'
tail=observed['2000:2000']
call chk tail[21]=='PARTIAL_COVERAGE','final 2000ms partial survives EOF'
call chk abs(tail[7]-1000)<.01,'trailing partial is exactly 1000ms observed'
d=observed['1000:2000']
call chk d[21]=='INVALID_GEOMETRY_OR_GAP','long PTS gap not imputed as stable'
call chk d[19]>=360,'actual 360ms gap retained'
call chk d[8]<d[7],'unstable coverage lower than measured time span'
say 'SPASH_PTS_STREAM_QUALIFICATION_PASS' count 'windows'
exit 0
::routine chk
 use strict arg assertion,label
 if \assertion then do
  say 'FAIL' label
  exit 1
 end