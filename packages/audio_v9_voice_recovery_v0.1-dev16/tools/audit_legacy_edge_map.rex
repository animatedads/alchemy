numeric digits 30
parse arg path
if path='' then do; say 'usage: audit_legacy_edge_map.rex LEGACY_FILE_EDGE_MAP.tsv'; exit 2; end
expected=.array~of('feed','left_file','right_file','edge_serial','boundary_step_samples','cumulative_correction_samples','confidence','evidence_count','status','rms_samples','excluded_count','tdoa_before_samples','tdoa_after_samples')
tsv=.AudioV9TsvReader~new(path,expected)
rows=0; measured=0; single=0; excluded=0; zeroTdoa=0
do forever
  f=tsv~next; if f==.nil then leave; if f~items<>13 then do; say 'FAIL malformed legacy row'; exit 2; end; rows=rows+1
  if f[9]='MEASURED' then do
    measured=measured+1; if f[8]+0<2 then single=single+1; if f[11]+0>0 then excluded=excluded+1; if f[12]+0=0 & f[13]+0=0 then zeroTdoa=zeroTdoa+1
  end
end
tsv~close
say 'UNSAFE legacy-dev4-map rows='rows' measured='measured' measured_with_lt2_support='single' measured_after_exclusion='excluded' measured_zero_tdoa_model='zeroTdoa
say 'FAIL legacy FILE_EDGE_MAP.tsv is diagnostic evidence only; dev6 refuses it as clock authority'
exit 1
::requires 'AudioV9Tsv.cls'
