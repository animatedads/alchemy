headless=.CliUiHeadlessRenderer~new(12,72)
table=.CliUiTableModel~new(.array~of('Key','Type','Status'))
table~viewport(1,5)
table~append('PR-1001',.array~of('PR-1001','Purchase Request','APPROVED'))
table~append('PR-1002',.array~of('PR-1002','Purchase Request','PENDING'))
table~append('REL-3001',.array~of('REL-3001','Release Authorization','BLOCKED'))
table~append('TASK-4',.array~of('TASK-4','Task','OPEN'))
table~append('TASK-5',.array~of('TASK-5','Task','OPEN'))
table~select(1)
trace=.CliUiSemanticTrace~new
controller=.FixtureController~new(table,trace)
controller~command('TABLE_NEXT')
if table~selectedIdentity<>'PR-1002' then raise syntax 93.900 array ('stable identity navigation failed')
controller~command('OPEN_SELECTED')
detail=controller~detail
if detail~title<>'PR-1002' then raise syntax 93.900 array ('detail identity failed')
controller~command('APPROVE')
if table~row(2)[2][3]<>'APPROVED' then raise syntax 93.900 array ('action refresh failed')
controller~command('RETURN')
headless~beginFrame
.CliUiTableProjection~new(headless)~render(table,1,5)
headless~endFrame
if headless~cell(3,1)=.nil then raise syntax 93.900 array ('table projection missing selected row')
expected='SelectionChanged|list|PR-1002|command|TABLE_NEXT|selected' || '0a'x || -
         'Open|list|PR-1002|command|OPEN_SELECTED|detail' || '0a'x || -
         'Action|detail|PR-1002|command|APPROVE|APPROVED' || '0a'x || -
         'Return|detail|PR-1002|command|RETURN|list'
if trace~text<>expected then raise syntax 93.900 array ('semantic trace mismatch:' trace~text)
say 'PASS list detail action stable identity semantic trace'

::class FixtureController
::method init
  expose table trace detail current
  use strict arg table,trace
  detail=.nil; current=.nil
::attribute detail get
::method command
  expose table trace detail current
  use strict arg command
  select
    when command='TABLE_NEXT' then do
      table~move(1); current=table~selectedIdentity
      trace~record(.CliUiSemanticEvent~new('SelectionChanged','list',current,'command',command),'selected')
    end
    when command='OPEN_SELECTED' then do
      current=table~selectedIdentity
      detail=.CliUiDetailModel~new(current)
      detail~addField('Type',table~row(table~selected)[2][2])
      detail~addField('Status',table~row(table~selected)[2][3])
      trace~record(.CliUiSemanticEvent~new('Open','list',current,'command',command),'detail')
    end
    when command='APPROVE' then do
      row=table~row(table~selected)
      row[2][3]='APPROVED'
      trace~record(.CliUiSemanticEvent~new('Action','detail',current,'command',command),'APPROVED')
    end
    when command='RETURN' then trace~record(.CliUiSemanticEvent~new('Return','detail',current,'command',command),'list')
    otherwise raise syntax 93.900 array ('unknown command' command)
  end
  return self

::requires 'CliUiTable.cls'
::requires 'CliUiModels.cls'
::requires 'CliUiProjection.cls'
::requires 'CliUiHeadlessRenderer.cls'
::requires 'CliUiSemantic.cls'
