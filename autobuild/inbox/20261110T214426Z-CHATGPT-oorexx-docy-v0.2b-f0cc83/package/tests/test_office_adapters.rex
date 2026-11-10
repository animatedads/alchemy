/* Contract test doubles for the published Alchemy APIs.
   These are NOT PDF/ODT document generators; the run verifies DOCY dispatch
   against documented PdfFlowReport / OdtAccess APIs, not the real packages.
*/
failures=0
passed=0
loaded=.DocyStore~open('alchemy_shared_graph.docy')
call check loaded['report']~count('STOP')==0,'DOCY graph loaded'
g=loaded['graph']
providers=.directory~new
providers['pdf.flow']=.PdfFlowReport
providers['pdf.table']=.PdfTable
providers['odt.access']=.OdtAccess
providers['odt.table']=.OdtTable
pdf=.DocyOfficePublisher~publishPdf(g,'doc.grid-plan','adapter_pdf_calls.txt',providers)
call check pdf['report']~count('STOP')==0,'PDF adapter accepts graph'
call check pdf['report']~count('WARN')>0,'PDF warns on unsupported SVG'
call check pos('adapter_pdf_calls.txt',pdf['path'])>0,'PDF output receipt path'
odt=.DocyOfficePublisher~publishOdt(g,'doc.grid-plan','adapter_odt_calls.txt',providers)
call check odt['report']~count('STOP')==0,'ODT adapter accepts graph'
call check odt['report']~count('WARN')>0,'ODT warns on unsupported SVG'
call check pos('adapter_odt_calls.txt',odt['path'])>0,'ODT output receipt path'
call check pos('213.255.246.45',selfread('adapter_odt_calls.txt'))>0,'ODT table fact reference resolved'
call check pos('213.255.246.45',selfread('adapter_pdf_calls.txt'))>0,'PDF table fact reference resolved'
call check pos('Before you install',selfread('adapter_pdf_calls.txt'))>0,'PDF heading resolved'
call check pos('Before you install',selfread('adapter_odt_calls.txt'))>0,'ODT heading resolved'
call check pos('Architecture: Tom Dyer',selfread('adapter_pdf_calls.txt'))>0,'PDF credits generated'
call check pos('Architecture: Tom Dyer',selfread('adapter_odt_calls.txt'))>0,'ODT credits generated'
call check pos('[Figure not embedded:',selfread('adapter_pdf_calls.txt'))>0,'SVG is not silently dropped'
call check pos('[Figure not embedded:',selfread('adapter_odt_calls.txt'))>0,'ODT SVG is not silently dropped'
call check g~revision==4,'Publishing does not mutate graph revision'
empty=.directory~new
missing=.DocyOfficePublisher~publishPdf(g,'doc.grid-plan','should_not_exist.pdf',empty)
call check missing['report']~count('STOP')==1,'missing PDF provider STOP'
call check missing['path']=='','missing provider does not claim published output'
bad=.DocyOfficePublisher~publishOdt(g,'doc.unknown','should_not_exist.odt',providers)
call check bad['report']~count('STOP')>=1,'unknown document rejected before provider'
call check bad['path']=='','invalid document does not claim published output'
p=g~planFactChange('grid.ed209f.address','213.255.246.47','tool:fixture','new source revision')
call check p~impactCount==4,'change plan retains multi-document reach'
call check g~apply(p),'new fact value applied once'
updated=.DocyOfficePublisher~publishOdt(g,'doc.grid-plan','adapter_odt_after_change.txt',providers)
call check pos('213.255.246.47',selfread(updated['path']))>0,'ODT output reflects shared event'
call check pos('213.255.246.45',selfread(updated['path']))==0,'ODT output does not retain old fact'
say 'DOCY office adapter contract:' passed 'PASS;' failures 'FAIL'
if failures>0 then exit 1
exit 0
check:
 procedure expose passed failures
 use arg assertion, description
 if assertion then passed=passed+1
 else do
   failures=failures+1
   say 'FAIL:' description
 end
 return
selfread:
 procedure
 use arg path
 s=.stream~new(path)
 s~open('read')
 data=s~charin(,s~query('size'))
 s~close
 return data

::class PdfFlowReport public
::method init
  expose text
  text=''
::attribute title
::method addSection
  expose text
  use arg value,level
  text=text||'SECTION:'||value||'0a'x
::method addParagraph
  expose text
  use arg value
  text=text||value||'0a'x
::method addTable
  expose text
  use arg table
  do row over table~rows
    do v over row
      text=text||v||' '
    end
    text=text||'0a'x
  end
::method render
  expose text
  use arg path
  stream=.stream~new(path)
  stream~open('write replace')
  stream~charout(text)
  stream~close

::class PdfTable public
::method init
  expose rows
  use arg headers,widths
  rows=.array~new
::attribute rows get
::method addRows
  expose rows
  use arg newRows
  do row over newRows
    rows~append(row)
  end

::class OdtAccess public
::method create class
  use arg title,creator
  return .FakeOdtDocument~new
::method save class
  use arg document,path
  stream=.stream~new(path)
  stream~open('write replace')
  stream~charout(document~text)
  stream~close

::class FakeOdtDocument public
::method init
  expose text
  text=''
::attribute text get
::method addHeading
  expose text
  use arg value,level
  text=text||'HEADING:'||value||'0a'x
::method addParagraph
  expose text
  use arg value
  text=text||value||'0a'x
::method addTable
  expose text
  use arg table
  do row over table~rows
    do v over row
      text=text||v||' '
    end
    text=text||'0a'x
  end

::class OdtTable public
::method init
  expose rows
  use arg name
  rows=.array~new
::attribute rows get
::method addValues
  expose rows
  use arg values
  rows~append(values)

::requires 'docy_store.cls'
::requires 'docy_office.cls'
