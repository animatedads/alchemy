/* Real-provider DOCY office qualification driver.
   Requires the actual published Alchemy PDF dev6, ODT dev1, Archive dev1
   and Compress module level 4 on REXX_PATH. No shell conversions.
   Run after the exact upstream source revisions have been staged. */
parse arg graphPath
if graphPath=='' then graphPath='alchemy_shared_graph_office.docy'
loaded=.DocyStore~open(graphPath)
if loaded['report']~hasStops then do
  say loaded['report']~summary
  exit 2
end
graph=loaded['graph']
archiveProviders=.directory~new
archiveProviders['odt.document']=.OdtDocument
archiveProviders['odt.xml']=.OdtXml
archiveProviders['odt.package.reader']=.OdtPackageReader
archiveProviders['odt.package.writer']=.OdtPackageWriter
archiveProviders['archive.zip']=.ZipArchive
archiveProviders['archive.writer']=.ZipWriter
odtArchive=.DocyNativeOdtAccess~new(archiveProviders)
formatProviders=.directory~new
formatProviders['pdf.flow']=.PdfFlowReport
formatProviders['pdf.table']=.PdfTable
formatProviders['odt.access']=odtArchive
formatProviders['odt.table']=.OdtTable
pdf=.DocyOfficePublisher~publishPdf(graph,'doc.grid-plan','alchemy_grid_plan.pdf',formatProviders)
say 'PDF:' pdf['report']~summary
if pdf['report']~hasStops then exit 3
odt=.DocyOfficePublisher~publishOdt(graph,'doc.grid-plan','alchemy_grid_plan.odt',formatProviders)
say 'ODT:' odt['report']~summary
if odt['report']~hasStops then exit 4
readBack=odtArchive~open(odt['path'])
if readBack~headings~items==0 | readBack~tables~items==0 then do
  say 'STOP: Native ODT readback lost headings or tables'
  exit 5
end
say 'PROVIDERS PASS: native PDF and ODT emitted; ODT readback headings=' readBack~headings~items 'tables=' readBack~tables~items
exit 0

::requires 'docy_store.cls'
::requires 'docy_office.cls'
::requires 'docy_native_odt.cls'
::requires 'PdfCore.cls'
::requires 'OdtAccess.cls'
::requires 'Archive.cls'
