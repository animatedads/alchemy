/* Exercise native ODT bridge with injected Alchemy-compatible test providers.
   This validates API wiring, order/method, bounded opening and fail-closed
   rejection; it is NOT a real ZIP/ODT binary interoperability test. */
passed=0; failed=0
p=.directory~new
p['odt.document']=.TestOdtDocument
p['odt.xml']=.TestXml
p['odt.package.reader']=.TestOdtReader
p['odt.package.writer']=.TestOdtWriter
p['archive.zip']=.TestZipArchive
p['archive.writer']=.TestZipWriter
.TestZipArchive~badFirst=.false
.TestZipArchive~badMime=.false
a=.DocyNativeOdtAccess~new(p)
d=a~create('Architecture','Alchemy')
d~addHeading('First heading',1)
d~addParagraph('Test fact 42')
call check d~title=='Architecture','ODT document factory called'
result=a~save(d,'test.odt')
call check result=='test.odt','archive write returns path'
call check .TestZipWriter~capture~items==6,'ODT package has six entries'
first=.TestZipWriter~capture~at(1)
call check first[1]=='mimetype' & first[3]==0,'mimetype is first and Stored'
call check first[2]=='application/vnd.oasis.opendocument.text','ODT mimetype exact'
call check .TestZipWriter~capture~at(2)[1]=='content.xml','content XML preserved'
call check .TestZipWriter~capture~at(6)[1]=='META-INF/manifest.xml','ODT manifest written'
loaded=a~open('test.odt')
call check loaded~title=='Architecture','read title from upstream XML helper'
call check loaded~creator=='Alchemy','read creator from upstream XML helper'
call check loaded~blocks~items==1,'readBlocks is called'
call check loaded~sourcePath=='test.odt','read source path preserved'
call check .TestZipArchive~limits == '2000 67108864 134217728','ZIP expansion bounded'
.TestZipArchive~badFirst=.true
signal on syntax name badZip
bad=a~open('bad.odt')
call check .false,'reject unsafe/misordered mimetype'
signal off syntax
signal afterBadZip
badZip:
  call check .true,'reject unsafe/misordered mimetype'
  signal off syntax
afterBadZip:
.TestZipArchive~badFirst=.false
.TestZipArchive~badMime=.true
signal on syntax name badType
bad=a~open('bad2.odt')
call check .false,'reject wrong MIME'
signal off syntax
signal afterBadType
badType:
  call check .true,'reject wrong MIME'
  signal off syntax
afterBadType:
.TestZipArchive~badMime=.false
say 'DOCY native ODT archive contract:' passed 'PASS,' failed 'FAIL'
if failed>0 then exit 1
exit 0
check: procedure expose passed failed
  use arg good,label
  if good then passed=passed+1
  else do; failed=failed+1; say 'FAIL:' label; end
  return

::class TestOdtDocument public
::method init
  expose title creator blocks sourcePath
  use strict arg title,creator
  blocks=.array~new
  sourcePath=''
::attribute title
::attribute creator
::attribute sourcePath
::attribute blocks get
::method addHeading
  expose blocks
  use arg title, level
  blocks~append(title)
::method addParagraph
  expose blocks
  use arg text
  blocks~append(text)

::class TestOdtWriter public
::method contentXml
  use arg doc
  return '<office:document-content>Test fact 42</office:document-content>'
::method stylesXml
  return '<office:document-styles/>'
::method metaXml
  use arg doc
  return '<dc:title>'||doc~title||'</dc:title><dc:creator>'||doc~creator||'</dc:creator>'
::method settingsXml
  return '<office:document-settings/>'
::method manifestXml
  return '<manifest:manifest/>'

::class TestOdtReader public
::method readBlocks
  use arg content, document
  document~addHeading('Loaded heading',1)

::class TestXml public
::method firstText class
  use arg xml,name
  before='<'||name||'>'; after='</'||name||'>'
  pos1=pos(before,xml)
  if pos1==0 then return ''
  pos1=pos1+length(before)
  pos2=pos(after,xml,pos1)
  return substr(xml,pos1,pos2-pos1)

::class TestZipWriter public
::attribute capture class
::method init
  expose items
  items=.array~new
  .TestZipWriter~capture=items
::method addBytes
  expose items
  use strict arg name,data,method
  items~append(.array~of(name,data,method))
::method writeFile
  use arg path
  return path

::class TestZipEntry public
::method init
  use arg name, method, localOffset=0
  self~name=name
  self~method=method
  self~localOffset=localOffset
::attribute name
::attribute method
::attribute localOffset

::class TestZipArchive public
::attribute badFirst class
::attribute badMime class
::attribute limits class
::method fromFile class
  use strict arg path,maxEntries,maxEntryBytes,maxTotalBytes
  self~limits=maxEntries maxEntryBytes maxTotalBytes
  return self~new
::method entries
  a=.array~new
  if .TestZipArchive~badFirst then a~append(.TestZipEntry~new('other',0))
  else a~append(.TestZipEntry~new('mimetype',0))
  return a
::method entry
  use arg name
  if name=='mimetype' then do
    if .TestZipArchive~badFirst then return .TestZipEntry~new(name,0,42)
    return .TestZipEntry~new(name,0,0)
  end
  return .TestZipEntry~new(name,8)
::method extractBytes
  use arg name
  select
    when name=='mimetype' then do
      if .TestZipArchive~badMime then return 'application/zip'
      return 'application/vnd.oasis.opendocument.text'
    end
    when name=='content.xml' then return '<office:document-content/>'
    when name=='META-INF/manifest.xml' then return '<manifest:manifest/>'
    when name=='meta.xml' then return '<dc:title>Architecture</dc:title><dc:creator>Alchemy</dc:creator>'
    otherwise return ''
  end

::requires 'docy_native_odt.cls'
