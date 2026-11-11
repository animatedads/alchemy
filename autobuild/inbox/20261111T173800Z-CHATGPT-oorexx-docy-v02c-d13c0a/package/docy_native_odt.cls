/* DOCY OpenDocument archive bridge v0.2b.
   Reuse Alchemy OdtDocument, OdtPackageReader/Writer and ZipArchive/ZipWriter.
   There is no shell, zip/unzip command, independent XML writer or extraction.
   Provider directory permits qualified version pinning and tests without
   replacing the authoritative ODT package. No private methods.
*/
::class DocyNativeOdtAccess public
::constant MIME 'application/vnd.oasis.opendocument.text'

::method init
  expose providers
  use strict arg providers
  names=.array~of('odt.document','odt.xml','odt.package.reader','odt.package.writer','archive.zip','archive.writer')
  do name over names
    if providers[name] == .nil then raise syntax 93.900 array('DOCY ODT missing provider '||name)
  end

::method create
  expose providers
  use strict arg title='',creator=''
  return providers['odt.document']~new(title,creator)

::method save
  expose providers
  use strict arg document,path
  writer=providers['odt.package.writer']~new
  zip=providers['archive.writer']~new
  /* OpenDocument package rule: mimetype must be first, method 0 (Stored). */
  zip~addBytes('mimetype',self~MIME,0)
  /* This calls upstream OdtPackageWriter XML generators, not duplicated code. */
  zip~addBytes('content.xml',writer~contentXml(document),8)
  zip~addBytes('styles.xml',writer~stylesXml,8)
  zip~addBytes('meta.xml',writer~metaXml(document),8)
  zip~addBytes('settings.xml',writer~settingsXml,8)
  zip~addBytes('META-INF/manifest.xml',writer~manifestXml,8)
  return zip~writeFile(path)

::method open
  expose providers
  use strict arg path
  /* ZIP32 only; fail closed on malformed archives and unsupported methods.
     2000 entries; 64 MiB/entry; 128 MiB total declared expansion.
     ZipArchive validates central records, names, CRC and expanded size. */
  zip=providers['archive.zip']~fromFile(path,2000,67108864,134217728)
  /* Central-directory ordering need not equal the physical local-header
     ordering. Only offset zero proves that 'mimetype' is actually first. */
  first=zip~entry('mimetype')
  if first == .nil then raise syntax 93.900 array('ODT missing mimetype entry')
  if first~localOffset \== 0 | first~method \== 0 then -
    raise syntax 93.900 array('ODT mimetype must begin at byte zero and be Stored')
  mimetype=zip~extractBytes('mimetype')
  if mimetype \== self~MIME then raise syntax 93.900 array('Not an OpenDocument Text file')
  if zip~entry('content.xml') == .nil then -
    raise syntax 93.900 array('ODT missing content.xml')
  if zip~entry('META-INF/manifest.xml') == .nil then -
    raise syntax 93.900 array('ODT missing manifest')
  content=zip~extractBytes('content.xml')
  manifest=zip~extractBytes('META-INF/manifest.xml')
  if pos('<manifest:manifest',manifest) == 0 then -
    raise syntax 93.900 array('ODT manifest structure missing')
  meta=''
  if zip~entry('meta.xml') \== .nil then meta=zip~extractBytes('meta.xml')
  xml=providers['odt.xml']
  title=xml~firstText(meta,'dc:title')
  creator=xml~firstText(meta,'dc:creator')
  document=self~create(title,creator)
  document~sourcePath=path
  reader=providers['odt.package.reader']~new
  reader~readBlocks(content,document)
  return document
