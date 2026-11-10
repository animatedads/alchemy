/* All values loaded from ooRexx native pixel scan TSV, no Python. */
numeric digits 30
parse arg input
if input='' then input='/mnt/data/moonsault_20261110/all_bright_points.tsv'
source=stream(input,'C','OPEN READ')
if left(source,5)<>'READY' then do
 say 'FAIL cannot open source' source
 exit 3
end
ignore=linein(input)
points=.array~new
aligned=.array~new
clock=.array~of(5,30,60,280,305,335)
do i=1 to 6
 points~append(.array~new)
 aligned~append(.array~of(0,0,0))
end
do while lines(input)>0
 row=linein(input)
 if row='' then iterate
 parse var row clip '09'x sec '09'x xx '09'x yy '09'x contrast '09'x peak
 i=(clip-1)*3
 select
  when sec=5 then i+=1
  when sec=30 then i+=2
  when sec=60 then i+=3
  otherwise do
    say 'INVALID video time' row
    exit 4
  end
 end
 p=.directory~new;p['X']=xx;p['Y']=yy;p['CONTRAST']=contrast;p['PEAK']=peak
 points[i]~append(p)
end
ignore=stream(input,'C','CLOSE')
tracks=.MoonsaultStillPointScan~trackWindow(points,clock,aligned,3.5,0.006,0.12)
unique=.MoonsaultStillPointScan~uniqueTracks(tracks,3)
say 'ALL SIX-FRAME HYPOTHESES' tracks~items 'UNIQUE' unique~items
file='/mnt/data/moonsault_20261110/six_frame_star_tracks.tsv'
ignore=charout(file,'x0'||'09'x||'y0'||'09'x||'x_last'||'09'x||'y_last'||'09'x||'vx'||'09'x||'vy'||'09'x||'fit_rms'||'0a'x,1)
do t over unique
 say 'TRACK' t['START_X'] t['START_Y'] '->' t['END_X'] t['END_Y'] -
   'vx='format(t['VX'],,4) 'vy='format(t['VY'],,4) 'RMS='format(t['RMS'],,3)
 ignore=charout(file,t['START_X']||'09'x||t['START_Y']||'09'x||t['END_X']||'09'x||t['END_Y']||'09'x|| -
 t['VX']||'09'x||t['VY']||'09'x||t['RMS']||'0a'x)
end
ignore=stream(file,'C','CLOSE')
if unique~items<5 then do
 say 'FAIL too few six-epoch tracks'
 exit 5
end
say 'PASS: native ooRexx six-epoch star-like motion tracks; Yale identification still pending'
::requires '../src/MoonsaultStillPointScan.cls'