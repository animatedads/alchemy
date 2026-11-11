/* Real NoSQLServer integration smoke for selected columnar top-level path.
 * Run under ooRexx 5.3 r13196 with Alchemy dependencies in include path.
 */

raw=.table~new
raw['name']='observations'
raw['columns']=.array~new
names=.array~of('id','station','temperature','notes')
types=.array~of('INTEGER','INTEGER','DECIMAL','TEXT')
do i=1 to names~items
  col=.table~new
  col['name']=names[i]
  col['type']=types[i]
  col['nullable']=.true
  raw['columns']~append(col)
end
definition=.TableDefinition~new(raw)
rows=.array~new
do i=1 to 12
  vals=.table~new
  vals['id']=i
  if i // 2 = 0 then vals['station']='17'
  else vals['station']='21'
  vals['temperature']=i * 1.5
  vals['notes']='content ' || i || '|' || x2c('00FF')
  if i=4 then vals['notes']=.nil
  rows~append(.DatabaseRow~new(vals))
end
port=.NoSQLColumnarMemoryPort~new
engine=.NoSQLColumnarEngine~new(port)
call require engine~register('observations',definition,rows,4) = 1,'publish'
t=engine~table('observations')
call require t~rowCount=12,'cardinality'
call require t~readRows[4]['notes']==.nil,'NULL fidelity'
call require t~readRows[1]['notes']==rows[1]['notes'],'octet fidelity'
scan=engine~selectColumnar('observations',.SQLComparisonPredicate~new('station','=','17'),'temperature','')
call require scan~rows~items=6,'column filter'
call require scan~accessPath='COLUMNAR_PROJECT_LATE','physical route'
call require t~lastColumnsRead~items=1,'late materialisation only measure'
call require t~lastColumnsRead[1]='temperature','unreferenced notes untouched'

-- Top-level NoSQLServerSQL optimisation hook must preserve the SQL result.
sql=.NoSQLServerSQL~new(engine)
r=sql~execute('SELECT temperature FROM observations WHERE station = 17')
call require r~status=.Error~SUCCESS,'SQL status'
call require r~rowCount=6,'SQL cardinality'
call require r~accessPath='COLUMNAR_PROJECT_LATE','SQL selected columnar route'

-- Fail staging before active pointer publication; old generation survives.
port~failWriteAt=port~writeCount+2
failed=.false
signal on syntax name publishFailure
ignore=t~publishRows(rows)
signal off syntax
signal afterFailure
publishFailure:
  failed=.true
  signal off syntax
afterFailure:
call require failed,'failure injected'
call require t~generation=1,'active generation stable'
call require t~rowCount=12,'published row count stable'
say 'PASS v0.93 columnar virtual table, SQL pushdown, rollback boundary'
exit 0

require: procedure
  use strict arg okay, message
  if \okay then do
    say 'FAIL:' message
    exit 1
  end
  return

::requires "../src/NoSQLServerColumnar.cls"
