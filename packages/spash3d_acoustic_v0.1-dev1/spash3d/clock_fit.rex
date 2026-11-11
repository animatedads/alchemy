/* clock_fit.rex -- weighted linear clock model FC->FD from per-file-pair measurements.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 31 Oct 2026.
 * Input: clock_refine TSV (continuous chains). Rows with env_z < minZ are excluded and listed.
 * Model: offset(t) = a + b*(t - tRef), weights = env_z^2 * minutes. Reports residual RMS.
 * usage: clock_fit.rex inTsv outTsv [minZ]
 */
numeric digits 20
parse arg inTsv outTsv minZ .
if minZ='' then minZ=2.5
s=.stream~new(inTsv); s~open('READ'); hdr=s~linein
rows=.array~new
do while s~lines>0
  l=s~linein; if l='' then iterate
  parse var l fdf '09'x fcf '09'x st '09'x mins '09'x envOff '09'x envSc '09'x z '09'x waveOff '09'x waveSc
  d=.directory~new; d['FD']=fdf; d['FC']=fcf; d['T']=hms2sec(st~left(8))+(mins*60)/2; d['OFF']=envOff+0
  d['Z']=z+0; d['W']=(z**2)*mins; d['MINS']=mins; rows~append(d)
end
s~close
tRef=hms2sec('120000')
sw=0; sx=0; sy=0; sxx=0; sxy=0
do d over rows
  if d['Z']<minZ then iterate
  x=(d['T']-tRef)/3600; w=d['W']; y=d['OFF']
  sw+=w; sx+=w*x; sy+=w*y; sxx+=w*x*x; sxy+=w*x*y
end
b=(sw*sxy-sx*sy)/(sw*sxx-sx*sx); a=(sy-b*sx)/sw
o=.stream~new(outTsv); o~open('WRITE REPLACE')
o~lineout('# FC->FD clock model: fc_minus_fd_s = a + b*hours_since_12:00:00 (continuous chains, seam gap 0.08 s)')
o~lineout('a_s'||'09'x||format(a,,4)); o~lineout('b_s_per_hour'||'09'x||format(b,,4))
o~lineout('fd_file'||'09'x||'fc_file'||'09'x||'mid_time'||'09'x||'measured_s'||'09'x||'model_s'||'09'x||'residual_ms'||'09'x||'env_z'||'09'x||'used')
ss=0; sww=0
do d over rows
  x=(d['T']-tRef)/3600; m=a+b*x; r=(d['OFF']-m)*1000; used=d['Z']>=minZ
  if used then do; ss+=d['W']*r*r; sww+=d['W']; end
  line=d['FD']'09'x||d['FC']'09'x||sec2hms(d['T'])'09'x||format(d['OFF'],,3)'09'x||format(m,,3)'09'x||format(r,,0)'09'x||format(d['Z'],,1)'09'x||used~?('YES','NO (z<'minZ')')
  o~lineout(line); say line
end
rms=sqrt(ss/sww)
o~lineout('weighted_residual_rms_ms'||'09'x||format(rms,,1))
o~close
say 'a='format(a,,4)'s b='format(b,,4)'s/h residual_rms='format(rms,,1)'ms'
exit 0
::routine sqrt
  use arg v; if v<=0 then return 0; r=v; do 60; r=(r+v/r)/2; end; return r
::requires 'FeedChain.cls'
