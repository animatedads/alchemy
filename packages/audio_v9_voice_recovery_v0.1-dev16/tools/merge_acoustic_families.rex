numeric digits 30
parse arg listFile outPrefix
if listFile='' | outPrefix='' then do
  say 'usage: merge_acoustic_families.rex TRACK_FILE_LIST OUT_PREFIX'
  say 'list format: origin<TAB>path, one immutable per-chunk .tracks.tsv per line'
  exit 2
end
specs=.array~new
tsv=.AudioV9TsvReader~new(listFile,.nil,.false)
do forever
  p=tsv~next; if p==.nil then leave
  if p~items<>2 then do; say 'FAIL malformed track file list row width='p~items; exit 2; end
  d=.directory~new; d~put(p[1],'origin'); d~put(p[2],'path'); specs~append(d)
end
tsv~close
analysis=.AudioV9CampaignAcousticCoordinator~new~fromTrackFiles(specs)
files=analysis~write(outPrefix)
say 'PASS campaign acoustic families tracks='||analysis~tracks~items||' families='||analysis~families~items||' files='||files~items
exit 0
::requires 'AudioV9AcousticCoordinator.cls'
::requires 'AudioV9Tsv.cls'
