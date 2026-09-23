/* AudioV9EvidenceGraphRenderer.cls
 * Efficient diagnostic SVG renderer for already-semantic MLGraph objects.
 * This class owns only presentation: scaling, projection, stroke/point size,
 * grouped legend and text placement.  It never creates/removes graph evidence.
 */
::options numeric inherit

::class AudioV9EvidenceGraphSvgRenderer subclass MLGraphRenderer public
::method name; return 'AUDIO_V9_SVG'
::method supports
  use strict arg graph
  if \graph~isA(.MLGraph) then return .false
  if graph~coordinateSystem<>'CARTESIAN' then return .false
  if graph~dimensionCount<>3 then return .false
  return graph~metadata('audioView','')<>''
::method render
  use strict arg graph,path
  if \self~supports(graph) then raise syntax 88.900 array('Audio V9 renderer requires a three-dimensional Audio MLGraph')
  view=graph~metadata('audioView','')~upper
  select
    when view='FIELD' then return self~renderField(graph,path)
    when view='RELATIONS' then return self~renderRelations(graph,path)
    when view='DELAY' then return self~renderDelay(graph,path)
    when view='RECONSTRUCTION' then return self~renderReconstruction(graph,path)
    otherwise raise syntax 88.900 array('unknown Audio V9 graph view',view)
  end
::method renderField private
  use strict arg g,path
  s=self~open(path,g~title,'Moving spectral boxes; point size is presentation-only scaling of published residual motion.')
  b=self~bounds(g,'time_ms','frequency_hz'); self~axes(s,b,'time (ms)','frequency (Hz)')
  do series over g~series
    key=series~semanticKey; style=self~style(key)
    do p over series~points
      q=self~xy(p~value('time_ms'),p~value('frequency_hz'),b); m=p~value('motion_db')+0; r=1.5+m*.8; if r>7 then r=7
      s~lineout('<circle cx="'||q[1]||'" cy="'||q[2]||'" r="'||format(r,,2)||'" fill="'||style[1]||'" fill-opacity="0.68"/>')
    end
  end
  self~legend(s,g); self~annotations(s,g); return self~close(s)
::method renderRelations private
  use strict arg g,path
  s=self~open(path,g~title,'Every line is a published inter-box relation; renderer does not decide whether an edge exists.')
  b=self~bounds(g,'time_ms','frequency_hz'); self~axes(s,b,'time (ms)','frequency (Hz)')
  do series over g~series
    pts=series~points; if pts~items<2 then iterate; key=series~semanticKey; st=self~style(key)
    a=self~xy(pts[1]~value('time_ms'),pts[1]~value('frequency_hz'),b); z=self~xy(pts[2]~value('time_ms'),pts[2]~value('frequency_hz'),b)
    s~lineout('<line x1="'||a[1]||'" y1="'||a[2]||'" x2="'||z[1]||'" y2="'||z[2]||'" stroke="'||st[1]||'" stroke-width="'||st[2]||'"'||st[3]||'/>')
  end
  self~legend(s,g); self~annotations(s,g); return self~close(s)
::method renderDelay private
  use strict arg g,path
  s=self~open(path,g~title,'Envelope, direct and refined delay hypotheses remain separate evidence series.')
  b=self~bounds(g,'time_ms','lag_ms'); self~axes(s,b,'time (ms)','lag (ms)')
  do series over g~series
    st=self~style(series~semanticKey); d=''; i=0
    do p over series~points
      i=i+1; q=self~xy(p~value('time_ms'),p~value('lag_ms'),b); if i=1 then d='M '||q[1]||' '||q[2]; else d=d||' L '||q[1]||' '||q[2]
    end
    if d<>'' then s~lineout('<path d="'||d||'" fill="none" stroke="'||st[1]||'" stroke-width="'||st[2]||'"'||st[3]||'/>')
    do p over series~points; q=self~xy(p~value('time_ms'),p~value('lag_ms'),b); score=p~value('score')+0; r=2+score; if r>6 then r=6; s~lineout('<circle cx="'||q[1]||'" cy="'||q[2]||'" r="'||format(r,,2)||'" fill="'||st[1]||'"/>'); end
  end
  self~legend(s,g); self~annotations(s,g); return self~close(s)
::method renderReconstruction private
  use strict arg g,path
  s=self~open(path,g~title,'Rectangles are published source-conditioned TF mask regions; gain is shown as opacity/annotation only.')
  b=self~bounds(g,'time_ms','frequency_hz'); self~axes(s,b,'time (ms)','frequency (Hz)')
  do series over g~series
    pts=series~points; if pts~items<2 then iterate; st=self~style(series~semanticKey)
    a=self~xy(pts[1]~value('time_ms'),pts[1]~value('frequency_hz'),b); z=self~xy(pts[2]~value('time_ms'),pts[2]~value('frequency_hz'),b)
    x=a[1]+0; if z[1]+0<x then x=z[1]+0; y=a[2]+0; if z[2]+0<y then y=z[2]+0; w=abs((z[1]+0)-(a[1]+0)); h=abs((z[2]+0)-(a[2]+0)); if w<1 then w=1; if h<1 then h=1
    gain=pts[1]~value('gain')+0; opacity=.18+.32*self~clamp(gain/1.5,0,1)
    s~lineout('<rect x="'||format(x,,2)||'" y="'||format(y,,2)||'" width="'||format(w,,2)||'" height="'||format(h,,2)||'" fill="'||st[1]||'" fill-opacity="'||format(opacity,,3)||'" stroke="'||st[1]||'" stroke-width="0.45"/>')
  end
  self~legend(s,g); self~annotations(s,g); return self~close(s)
::method open private
  use strict arg path,title,subtitle
  s=.stream~new(path); rc=s~open('write replace'); if rc<>'READY:' then raise syntax 88.900 array('unable to open Audio V9 SVG',path,rc)
  s~lineout('<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="800" viewBox="0 0 1200 800">')
  s~lineout('<rect width="1200" height="800" fill="white"/>')
  s~lineout('<text x="28" y="34" font-family="sans-serif" font-size="22" font-weight="bold">'||self~esc(title)||'</text>')
  s~lineout('<text x="28" y="57" font-family="sans-serif" font-size="12">'||self~esc(subtitle)||'</text>')
  return s
::method close private
  use strict arg s
  s~lineout('<text x="28" y="784" font-family="sans-serif" font-size="10">Audio V9 diagnostic renderer — semantic authority remains in evidence objects / ML Graph.</text>')
  s~lineout('</svg>'); s~close; return .true
::method bounds private
  use strict arg g,xn,yn
  minx=.nil; maxx=.nil; miny=.nil; maxy=.nil
  do series over g~series
    do p over series~points
      x=p~value(xn)+0; y=p~value(yn)+0
      if minx==.nil then minx=x; else if x<minx then minx=x
      if maxx==.nil then maxx=x; else if x>maxx then maxx=x
      if miny==.nil then miny=y; else if y<miny then miny=y
      if maxy==.nil then maxy=y; else if y>maxy then maxy=y
    end
  end
  if minx==.nil then do; minx=0; maxx=1; miny=0; maxy=1; end
  if maxx=minx then maxx=minx+1
  if maxy=miny then maxy=miny+1
  return .array~of(minx,maxx,miny,maxy)
::method xy private
  use strict arg x,y,b
  left=80; right=1140; top=90; bottom=680
  px=left+(x-b[1])/(b[2]-b[1])*(right-left); py=bottom-(y-b[3])/(b[4]-b[3])*(bottom-top)
  return .array~of(format(px,,2),format(py,,2))
::method axes private
  use strict arg s,b,xlabel,ylabel
  s~lineout('<line x1="80" y1="680" x2="1140" y2="680" stroke="#222"/>'); s~lineout('<line x1="80" y1="90" x2="80" y2="680" stroke="#222"/>')
  s~lineout('<text x="610" y="716" font-family="sans-serif" font-size="12" text-anchor="middle">'||self~esc(xlabel)||' '||self~esc(b[1])||'..'||self~esc(b[2])||'</text>')
  s~lineout('<text x="20" y="390" font-family="sans-serif" font-size="12" transform="rotate(-90 20 390)" text-anchor="middle">'||self~esc(ylabel)||' '||self~esc(b[3])||'..'||self~esc(b[4])||'</text>')
  return
::method legend private
  use strict arg s,g
  seen=.directory~new; keys=.array~new
  do series over g~series
    k=series~semanticKey; if k='' then k=series~role
    if \seen~hasIndex(k) then do; seen[k]=1; keys~append(k); end
  end
  keys~sort; x=90; y=742
  do k over keys
    st=self~style(k); s~lineout('<line x1="'||x||'" y1="'||y||'" x2="'||(x+25)||'" y2="'||y||'" stroke="'||st[1]||'" stroke-width="'||st[2]||'"'||st[3]||'/>'); s~lineout('<text x="'||(x+31)||'" y="'||(y+4)||'" font-family="sans-serif" font-size="10">'||self~esc(k)||'</text>'); x=x+145; if x>1050 then do; x=90; y=y+16; end
  end
  return
::method annotations private
  use strict arg s,g
  y=76
  do a over g~annotations
    if a~kind='SUMMARY' then do; s~lineout('<text x="520" y="'||y||'" font-family="sans-serif" font-size="10">'||self~esc(a~text)||'</text>'); y=y+13; end
  end
  return
::method style private
  use strict arg key
  k=key~string~upper
  select
    when k='FC' then return .array~of('#205493','2.0','')
    when k='FD' then return .array~of('#8a3d78','2.0','')
    when k='CONTINUATION' then return .array~of('#305f33','1.3','')
    when k='ADJACENT_BAND' then return .array~of('#2e6f95','1.0',' stroke-dasharray="4 3"')
    when k='DIAGONAL_MIGRATION' then return .array~of('#9b5b22','1.0',' stroke-dasharray="8 3"')
    when k='DELAYED_RECURRENCE' then return .array~of('#7a478d','1.0',' stroke-dasharray="2 4"')
    when k='ENVELOPE' then return .array~of('#7a478d','1.2',' stroke-dasharray="5 3"')
    when k='DIRECT' then return .array~of('#606060','1.2',' stroke-dasharray="2 3"')
    when k='REFINED' then return .array~of('#205493','2.2','')
    when k='SPEAKER_VOICE' then return .array~of('#2f6d3d','1.0','')
    when k='CONFIRMED_ALARM' then return .array~of('#9c3b32','1.0','')
    when k='CONFIRMED_ANIMAL' then return .array~of('#9b5b22','1.0','')
    when k='CONFIRMED_IMPACT' then return .array~of('#6f4a2d','1.0','')
    otherwise return .array~of('#52616b','1.0','')
  end
::method clamp private
  use strict arg x,lo,hi
  if x<lo then return lo
  if x>hi then return hi
  return x
::method esc private
  use strict arg value
  x=value~string; x=x~changeStr('&','&amp;'); x=x~changeStr('<','&lt;'); x=x~changeStr('>','&gt;'); x=x~changeStr('"','&quot;'); return x

::requires 'AudioV9EvidenceGraph.cls'
