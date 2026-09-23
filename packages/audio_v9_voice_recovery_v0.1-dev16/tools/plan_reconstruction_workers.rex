numeric digits 30
parse arg selector
root=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT'); if root='' then root='.'
reader=.AudioV9TsvReader~new(root||'/campaign/WORKERS.tsv',.array~of('worker','core_start','core_end','halo_seconds','provider','address','login'))
rows=.array~new
do forever
  row=reader~next
  if row==.nil then leave
  if row~items<>7 then do; say 'FAIL worker TSV width'; exit 2; end
  s=.AudioV9VoiceClock~parse(row[2]); e=.AudioV9VoiceClock~parse(row[3])
  if e<=s then do; say 'FAIL worker interval'; exit 2; end
  d=.directory~new; d['worker']=row[1]; d['start']=s; d['end']=e; d['samples']=(e-s)*8000; rows~append(d)
end
reader~close
if selector='' then do
  say 'worker'||'09'x||'core_start_serial'||'09'x||'core_end_serial'||'09'x||'expected_samples'
  do d over rows; say d['worker']||'09'x||d['start']||'09'x||d['end']||'09'x||d['samples']; end
  exit 0
end
if selector='--shell' then do
  do d over rows; say 'WORKER' d['worker'] d['start'] d['end'] d['samples']; end
  exit 0
end
do d over rows
  if d['worker']=selector then do
    say 'CORE' d['start'] d['end'] d['samples']
    exit 0
  end
end
say 'FAIL unknown worker' selector
exit 2
::requires 'AudioV9Tsv.cls'
::requires 'AudioV9VoiceCampaign.cls'
