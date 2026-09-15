/* v0.22.3 managed struct pointer graph + exact buffer slices. */
lib=.foreign~load('../examples/test.bridge.json')

buf=.foreign~buffer(10)
payload='00610062ff'x
call ok buf~putBytes(2,payload)=5, 'putBytes reports exact binary byte count'
call ok buf~getBytes(2,5)==payload, 'getBytes preserves embedded NUL and 0xff exactly'
call ok buf~getBytes(0,2)=='0000'x, 'unwritten buffer prefix remains zero'
call ok buf~putBytes(0,payload)=5, 'payload rewritten at base for graph fixture'

control=.foreign~buffer(3)
call ok control~putBytes(0,'010203'x)=3, 'control buffer binary write'

iov=lib~struct('foreign_graph_iovec')
iov~set('iov_base',buf)
iov~set('iov_len',5)
msg=lib~struct('foreign_graph_msg')
msg~set('msg_iov',iov)
msg~set('msg_control',control)
msg~set('msg_controllen',3)

/* payload bytes sum: 0 + 97 + 0 + 98 + 255 = 450; control=6. */
call ok lib~graph_sum(msg)=456, 'managed struct graph reaches nested payload and control buffers'
msgNull=lib~struct('foreign_graph_msg')
msgNull~set('msg_iov',iov)
msgNull~set('msg_control',.nil)
msgNull~set('msg_controllen',0)
call ok lib~graph_sum(msgNull)=450, 'ForeignStruct pointer field accepts .nil as a real null pointer'
msgNull~close

/* Managed struct graphs must remain acyclic. */
cycleMsg=lib~struct('foreign_graph_msg')
cycleIov=lib~struct('foreign_graph_iovec')
cycleMsg~set('msg_iov',cycleIov)
cycleRejected=0
signal on syntax name cycleBlocked
cycleIov~set('iov_base',cycleMsg)
signal off syntax
call ok 0, 'managed struct pointer cycle must be rejected'
signal cycleDone
cycleBlocked:
  signal off syntax
  cycleRejected=1
  call ok 1, 'managed struct pointer cycle rejected'
cycleDone:
call ok cycleRejected=1, 'cycle rejection condition observed'
cycleMsg~close; cycleIov~close

msg~close
iov~close
control~close
buf~close
lib~close
say 'PASS managed struct pointer graph and binary buffer slices'
exit 0

ok: procedure
  use arg truth,label
  if \truth then do
    say 'FAIL:' label
    exit 1
  end
  return

::requires '../rexx/foreign.cls'
