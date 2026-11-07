/* FdChain.cls -- the FD recording chain on the clock the FD/FC fit was made on (31 Oct).
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 6 Nov 2026.
 * TP7 at its filename time 11:14:49 (the anchor); later files at the previous end + 0.08 s seam; earlier files
 * (TP6 back to TP1) end 0.08 s before the next one starts.  Files that are not decoded are skipped, but the
 * chain stops at the first missing file on each side (no gaps).
 * fdChainFull(pcmDir) returns a FeedChain.  Same placement as moment_render / fd_scan for TP6-TP9. */
::routine fdChainFull public
  use strict arg pcm
  seam=0.08; ch=.FeedChain~new('FD')
  dur=.directory~new
  loop i=1 to 9
    f=pcm'/tp0'i'.f32'
    if stream(f,'C','QUERY EXISTS')<>'' then dur[i]=stream(f,'C','QUERY SIZE')/4/8000
  end
  if \dur~hasIndex(7) then raise syntax 88.900 array('FD chain needs tp07 (the clock anchor)')
  starts=.directory~new; starts[7]=hms2sec('111449')
  loop i=8 to 9; if \dur~hasIndex(i) then leave; starts[i]=starts[i-1]+dur[i-1]+seam; end
  loop i=6 to 1 by -1; if \dur~hasIndex(i) then leave; starts[i]=starts[i+1]-seam-dur[i]; end
  loop i=1 to 9; if starts~hasIndex(i) then x=ch~add(pcm'/tp0'i'.f32',starts[i]); end
  return ch
::requires 'FeedChain.cls'
