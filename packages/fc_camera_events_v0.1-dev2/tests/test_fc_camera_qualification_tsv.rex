say 'FC CAMERA QUALIFICATION TSV TEST START'
files=.array~of(,
  '../qualification/sample_474.camera_events.tsv',,
  '../qualification/sample_474.events.tsv',,
  '../qualification/sample_474.samples.tsv',,
  '../qualification/sample_474.scene.tsv',,
  '../qualification/sample_474.window.tsv',,
  '../qualification/sample_474.reflections.tsv',,
  '../qualification/sample_474.run.tsv',,
  '../qualification/sample_quiet_590.camera_events.tsv',,
  '../qualification/sample_quiet_590.events.tsv',,
  '../qualification/sample_quiet_590.samples.tsv',,
  '../qualification/sample_quiet_590.scene.tsv',,
  '../qualification/sample_quiet_590.window.tsv',,
  '../qualification/sample_quiet_590.reflections.tsv',,
  '../qualification/sample_quiet_590.run.tsv',,
  '../qualification/sample_700.camera_events.tsv',,
  '../qualification/sample_700.events.tsv',,
  '../qualification/sample_700.samples.tsv',,
  '../qualification/sample_700.scene.tsv',,
  '../qualification/sample_700.window.tsv',,
  '../qualification/sample_700.reflections.tsv',,
  '../qualification/sample_700.run.tsv',,
  '../qualification/reference_open.scene.tsv',,
  '../qualification/reference_open.window.tsv',,
  '../qualification/reference_open.reflections.tsv',,
  '../qualification/reference_closed.scene.tsv',,
  '../qualification/reference_closed.window.tsv',,
  '../qualification/reference_closed.reflections.tsv')

checked=0
rows=0
do path over files
  if stream(path,'C','QUERY EXISTS') == '' then do
    say 'MISSING:' path
    exit 1
  end
  csv=.CsvStream~new(path,.false)
  csv~delimiter='09'x
  csv~open('read')
  header=csv~csvLineIn
  width=header~items
  if width < 1 then do
    say 'EMPTY HEADER:' path
    exit 1
  end
  do while csv~lines > 0
    row=csv~csvLineIn
    if row == .nil then leave
    if row~items \= width then do
      say 'WIDTH FAILED:' path 'expected='width 'actual='row~items
      csv~close
      exit 1
    end
    rows=rows+1
  end
  csv~close
  checked=checked+1
end
say 'PASS FC camera qualification TSV files='checked 'rows='rows
exit 0

::requires 'csvStream.cls'
