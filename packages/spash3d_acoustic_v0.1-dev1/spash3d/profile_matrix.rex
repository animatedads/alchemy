/* profile_matrix.rex -- overlap patterns between every saved voice profile (groundwork for fix points).
 * Architecture: Tom Dyer (6 Nov 2026: collect overlap patterns, then make fix points).  Coding: Claude (Opus 5.5).
 * From the saved profiles only (statistics, no samples):
 *   pitch   shared pitch mass = sum over 1/24-octave buckets of min(P_a, P_b)  (1 = same pitch distribution)
 *   window  overlap of the p5-p95 pitch windows in semitones
 *   timbre  RMS over the 32 bands of (mu_a - mu_b) / sqrt((sd_a^2 + sd_b^2)/2)  (0 = same average spectrum)
 * A pair is SEPARABLE by the renderer only through pitch (it cuts by pitch window); timbre separates in the scan.
 * Writes outPrefix_pitch.tsv, outPrefix_timbre.tsv, outPrefix_window.tsv and prints them.
 * usage: profile_matrix.rex outPrefix profile [profile ...] */
numeric digits 16
parse arg outP profs
pa=.array~new; loop pf over profs~space~makeArray(' '); pa~append(.VoiceProfile~load(pf)); end
names=.array~new; loop vp over pa; names~append(vp~label~changestr('VOICE_','')); end
pm=.array~new(pa~items, pa~items); tm=.array~new(pa~items, pa~items); wm=.array~new(pa~items, pa~items)
loop i=1 to pa~items
  a=pa[i]; ta=0; loop v over a~pitch; ta+=v; end
  loop j=1 to pa~items
    b=pa[j]; tb=0; loop v over b~pitch; tb+=v; end
    s=0; loop k=1 to a~pitch~items; s+=min(a~pitch[k]/ta, b~pitch[k]/tb); end
    pm[i,j]=format(s,,2)
    z=0; loop k=1 to a~nb; q=(a~mu[k]-b~mu[k])/RxCalcSqrt((a~sd[k]**2+b~sd[k]**2)/2,16); z+=q*q; end
    tm[i,j]=format(RxCalcSqrt(z/a~nb,16),,2)
    lo=max(a~winLo,b~winLo); hi=min(a~winHi,b~winHi)
    if hi>lo then wm[i,j]=format(12*RxCalcLog(hi/lo,16)/RxCalcLog(2,16),,1); else wm[i,j]='0'
  end
end
call emit 'pitch', pm, 'shared pitch mass (1 = same)'
call emit 'timbre', tm, 'timbre distance (0 = same)'
call emit 'window', wm, 'pitch-window overlap, semitones'
say ''; say 'windows:'; loop vp over pa; say '  '||vp~label~left(10) format(vp~winLo,,1)'-'format(vp~winHi,,1) 'Hz,' vp~frames 'voiced frames'; end
exit 0
emit:
  use arg emitName, emitM, emitTitle
  o=.stream~new(outP'_'emitName'.tsv'); o~open('WRITE REPLACE')
  hdr=''~left(5); line='profile'; loop nm over names; hdr=hdr||nm~right(6); line=line||'09'x||nm; end
  o~lineout(line); say ''; say emitTitle; say hdr
  loop i=1 to names~items
    row=names[i]~left(5); line=names[i]
    loop j=1 to names~items; row=row||emitM[i,j]~right(6); line=line||'09'x||emitM[i,j]; end
    say row; o~lineout(line)
  end
  o~close
  return
::requires 'VoiceProfile.cls'
::requires 'rxmath' LIBRARY
