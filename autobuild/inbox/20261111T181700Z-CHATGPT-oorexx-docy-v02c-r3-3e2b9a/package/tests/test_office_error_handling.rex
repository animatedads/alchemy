/* Fail-closed native ooRexx DOCY publisher boundary tests. */
passed=0;failed=0
bundle=.DocyStore~open('alchemy_shared_graph_office.docy')
if bundle['report']~hasStops then do
  say bundle['report']~summary
  exit 1
end
g=bundle['graph']
revision=g~revision
p=.directory~new
p['pdf.flow']=.BrokenPdfReport
p['pdf.table']=.DummyPdfTable
x=.DocyOfficePublisher~publishPdf(g,'doc.grid-plan','broken.pdf',p)
call check x['report']~count('STOP')==1,'PDF exception becomes STOP'
call check x['path']=='','PDF failure is not reported as a successful path'
call check pos('PDF.PROVIDER.ERROR',x['report']~summary)>0,'PDF error code retained'
q=.directory~new
q['odt.access']=.BrokenOdtAccess
q['odt.table']=.DummyOdtTable
y=.DocyOfficePublisher~publishOdt(g,'doc.grid-plan','broken.odt',q)
call check y['report']~count('STOP')==1,'ODT exception becomes STOP'
call check y['path']=='','ODT failure is not reported as a successful path'
call check pos('ODT.PROVIDER.ERROR',y['report']~summary)>0,'ODT error code retained'
call check g~revision==revision,'failed publishers did not mutate graph'
say 'DOCY office failure contract:' passed 'PASS,' failed 'FAIL'
if failed>0 then exit 1
exit 0
check: procedure expose passed failed
  use arg condition,label
  if condition then passed=passed+1
  else do; failed=failed+1; say 'FAIL:' label; end
  return

::class BrokenPdfReport public
::attribute title
::method addSection
  use arg title,level
::method addParagraph
  use arg text
::method addTable
  use arg table
::method render
  raise syntax 93.900 array('Deliberate PDF provider failure')
::class DummyPdfTable public
::method init
  use arg headers,widths
::method addRows
  use arg rows

::class BrokenOdtAccess public
::method create class
  use arg title, creator
  return .DummyOdtDocument~new
::method save class
  raise syntax 93.900 array('Deliberate ODT provider failure')
::class DummyOdtDocument public
::method addHeading
  use arg title, level
::method addParagraph
  use arg text
::method addTable
  use arg table
::class DummyOdtTable public
::method init
  use arg name
::method addValues
  use arg values

::requires 'docy_store.cls'
::requires 'docy_office.cls'
