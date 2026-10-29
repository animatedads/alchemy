base=.CliUiHeadlessRenderer~new(12,30)
clip=.CliUiBoundedRenderer~new(base,12,30,2)
clip~beginFrame
clip~region(4,6)
clip~drawText(6,1,'TABLE','default')
clip~drawText(7,1,'INVALID','default')
clip~region(7,9)
clip~drawText(7,1,'DETAIL','default')
clip~drawText(6,1,'INVALID','default')
clip~drawFooter(11,1,'READY','status')
clip~endFrame
if base~cell(6,1) <> 'default:TABLE' then raise syntax 93.900 array('Table region overwritten')
if base~cell(7,1) <> 'default:DETAIL' then raise syntax 93.900 array('Detail region overwritten')
if base~cell(11,1) <> 'status:READY' then raise syntax 93.900 array('Footer overwritten')
say 'PASS disjoint content regions'
::requires 'CliUiBoundedRenderer.cls'
::requires 'CliUiHeadlessRenderer.cls'
