/* FeedChain.cls -- SPASH 3D: a camera's consecutive original recordings as one wall-clock timeline.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 31 Oct 2026.
 * Decoded PCM is mono 8 kHz float32 little-endian, produced with the Audio V9
 * decode convention (ffmpeg -ac 1 -ar 8000 -f f32le), one .f32 per original file.
 * The nominal clock is the camera filename time; seams are < 1 s (a couple of frames).
 */
::options numeric inherit

::class FeedChain public
::method init
  expose name files sr
  use strict arg name, sr=8000
  files=.array~new
::method name; expose name; return name
::method sampleRate; expose sr; return sr
/* add a file: path, nominal start as seconds after midnight */
::method add
  expose files sr
  use strict arg path, startSec
  bytes=stream(path,'C','QUERY SIZE')
  if bytes='' | bytes//4<>0 then raise syntax 88.900 array('not an f32 file',path)
  d=.directory~new; d['PATH']=path; d['START']=startSec; d['SAMPLES']=bytes%4
  d['END']=startSec+d['SAMPLES']/sr
  files~append(d)
  return d
::method files; expose files; return files
::method startSec; expose files; return files[1]['START']
::method endSec; expose files; return files[files~items]['END']
/* file containing wall-clock second t (nominal), or .nil */
::method fileAt
  expose files
  use strict arg t
  do f over files
    if t>=f['START'] & t<f['END'] then return f
  end
  return .nil
/* read n samples starting at nominal wall-clock second t; returns raw f32 string (zero-padded if outside) */
::method window
  expose files sr
  use strict arg t, n
  out=.mutablebuffer~new
  need=n; cur=t
  do while need>0
    f=self~fileAt(cur)
    if f=.nil then do                     /* gap or outside chain: explicit zero-pad */
      nxt=.nil
      do g over files; if g['START']>cur then do; nxt=g; leave; end; end
      if nxt=.nil then pad=need; else pad=min(need,max(1,trunc((nxt['START']-cur)*sr+0.5)))
      out~append(copies('00000000'x,pad)); need-=pad; cur+=pad/sr; iterate
    end
    s=trunc((cur-f['START'])*sr+0.5)
    take=min(need,f['SAMPLES']-s)
    if take<=0 then do; cur=f['END']; iterate; end
    st=.stream~new(f['PATH']); st~open('READ')
    out~append(st~charin(s*4+1,take*4)); st~close
    need-=take; cur+=take/sr
  end
  return out~string
::method writeWindow
  use strict arg t, n, path
  call sysFileDelete path
  st=.stream~new(path); st~open('WRITE REPLACE'); st~charout(self~window(t,n)); st~close
  return path

::routine hms2sec public
  use strict arg hms   /* "hh:mm:ss" or "hhmmss" */
  h=hms~changestr(':','')
  return h~substr(1,2)*3600+h~substr(3,2)*60+h~substr(5,2)
::routine sec2hms public
  use strict arg s
  neg=''; if s<0 then do; neg='-'; s=-s; end
  ms=trunc((s-trunc(s))*1000+0.5); w=trunc(s)
  if ms=1000 then do; ms=0; w+=1; end
  return neg||right(w%3600,2,'0')':'right(w//3600%60,2,'0')':'right(w//60,2,'0')'.'right(ms,3,'0')

/* mode 'NAME': each file at its filename time (1 s resolution).
 * mode 'CONTINUOUS': first file at its filename time, each later file at previous end + seamGap
 *   (cameras seal files with a gap of a couple of frames, per Tom Dyer). fcOffset shifts the whole FC
 *   chain onto the FD clock (seconds to ADD to FC times), measured by clock_envelope/clock_refine. */
::routine fcfdChains public
  use strict arg pcmDir, mode='NAME', seamGap=0.08, fcOffset=0
  fd=.FeedChain~new('FD'); fc=.FeedChain~new('FC')
  call build fd, .array~of('tp07 111449','tp08 125918'), pcmDir, mode, seamGap, 0
  call build fc, .array~of('tp28 113950','tp29 120920','tp30 123846','tp31 130704','tp32 133521','tp33 140344','tp34 143200'), pcmDir, mode, seamGap, fcOffset
  r=.directory~new; r['FD']=fd; r['FC']=fc
  return r
::routine build
  use arg chain, list, pcmDir, mode, gap, shift
  prev=.nil
  do p over list
    parse var p f t
    if mode~upper='CONTINUOUS' & prev<>.nil then st=prev['END']+gap
    else st=hms2sec(t)+shift
    prev=chain~add(pcmDir'/'f'.f32',st)
  end
