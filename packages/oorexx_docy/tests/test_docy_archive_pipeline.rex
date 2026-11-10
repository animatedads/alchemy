/* DOCY -> ODT native archive seam, end-to-end with API-compatible doubles.
   Exercised with real DOCY graph and event plan, but fake ZIP/XML providers.
   No claim about binary OpenDocument interoperability from these tests.
*/
passed=0; failed=0
loaded=.DocyStore~open('alchemy_shared_graph_office.docy')
call check loaded['report']~count('STOP')==0,'DOCY graph loads'
g=loaded['graph']
p=.directory~new
p['odt.document']=.PipelineOdtDocument
p['odt.xml']=.PipelineOdtXml
p['odt.package.reader']=.PipelineOdtReader
p['odt.package.writer']=.PipelineOdtWriter
p['archive.zip']=.PipelineZipArchive
p['archive.writer']=.PipelineZipWriter
odtAccess=.DocyNativeOdtAccess~new(p)
providers=.directory~new
providers['odt.access']=odtAccess
providers['odt.table']=.PipelineOdtTable
receipt=.DocyOfficePublisher~publishOdt(g,'doc.grid-plan','grid.odt',providers)
call check receipt['report']~count('STOP')==0,'DOCY -> archive bridge preflight'
call check receipt['path']=='grid.odt','publication path'
call check receipt['report']~count('WARN')>0,'SVG omission is reported'
call check .PipelineZipWriter~capture~at(1)[1]=='mimetype','mimetype first'
content=.PipelineZipWriter~content
call check pos('213.255.246.45',content)>0,'shared address fact present in ODT XML payload'
call check pos('Before you install',content)>0,'inherited section heading present'
call check pos('Architecture: Tom Dyer',content)>0,'DOCY credits present'
call check pos('Figure not embedded:',content)>0,'unsupported SVG visibly identified'
call check g~revision==4,'publish does not mutate graph'
plan=g~planFactChange('grid.ed209f.address','213.255.246.49','tool:test','address changed')
call check plan~impactCount==6,'plan reaches six registered outputs'
call check g~apply(plan),'apply is accepted at matching revision'
updated=.DocyOfficePublisher~publishOdt(g,'doc.grid-plan','grid-updated.odt',providers)
content=.PipelineZipWriter~content
call check updated['path']=='grid-updated.odt','second publish returns path'
call check pos('213.255.246.49',content)>0,'new shared address reflected in package'
call check pos('213.255.246.45',content)==0,'old address not retained'
call check g~revision==5,'only event changes graph revision'
say 'DOCY -> ODT Archive pipeline:' passed 'PASS,' failed 'FAIL'
if failed>0 then exit 1
exit 0
check: procedure expose passed failed
  use arg good,label
  if good then passed=passed+1
  else do; failed=failed+1; say 'FAIL:' label; end
  return

::class PipelineOdtDocument public
::method init
  expose title creator blocks sourcePath
  use strict arg title,creator
  blocks=.array~new
  sourcePath=''
::attribute title get
::attribute creator get
::attribute blocks get
::attribute sourcePath
::method addHeading
  expose blocks
  use arg caption,level
  blocks~append('H'||level||':'||caption)
::method addParagraph
  expose blocks
  use arg value
  blocks~append('P:'||value)
::method addTable
  expose blocks
  use arg table
  do row over table~rows
    values=''
    do value over row
      values=values||value||' '
    end
    blocks~append('T:'||values)
  end

::class PipelineOdtTable public
::method init
  expose rows
  use arg name
  rows=.array~new
::attribute rows get
::method addValues
  expose rows
  use arg values
  rows~append(values)

::class PipelineOdtWriter public
::method contentXml
  use arg doc
  out='<office:document-content>'||'0a'x
  do block over doc~blocks
    out=out||block||'0a'x
  end
  return out||'</office:document-content>'
::method stylesXml
  return '<office:document-styles/>'
::method metaXml
  use arg doc
  return '<dc:title>'||doc~title||'</dc:title><dc:creator>'||doc~creator||'</dc:creator>'
::method settingsXml
  return '<office:document-settings/>'
::method manifestXml
  return '<manifest:manifest/>'

::class PipelineZipWriter public
::attribute capture class
::attribute content class
::method init
  expose entries
  entries=.array~new
  .PipelineZipWriter~capture=entries
::method addBytes
  expose entries
  use strict arg name,data,method
  entries~append(.array~of(name,data,method))
  if name=='content.xml' then .PipelineZipWriter~content=data
::method writeFile
  use arg path
  return path

::class PipelineZipArchive public
::method fromFile class
  use arg path,maxEntries,maxEntryBytes,maxTotalBytes
  return self~new
::class PipelineOdtXml public
::method firstText class
  use arg xml,name
  return ''
::class PipelineOdtReader public
::method readBlocks
  use arg content,doc
  return

::requires 'docy_store.cls'
::requires 'docy_office.cls'
::requires 'docy_native_odt.cls'
