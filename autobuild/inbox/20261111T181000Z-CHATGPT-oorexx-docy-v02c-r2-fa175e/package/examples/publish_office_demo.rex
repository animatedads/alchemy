/* Use native Alchemy providers. Invocation example:
   rexx publish_office_demo.rex alchemy_shared_graph_office.docy
   Set REXX_PATH to include the DOCY, ooRexx PDF/src, ODT/src and ooRexx JSON bins.
   PDF/ODT are generated with the existing ooRexx providers, not LibreOffice.
   For a qualified run, inspect returned diagnostics and validate the binaries.
*/
parse arg inputPath
if inputPath == '' then inputPath='alchemy_shared_graph_office.docy'
loaded=.DocyStore~open(inputPath)
if loaded['report']~hasStops then do
  say loaded['report']~summary
  exit 2
end
graph=loaded['graph']
document=graph~document('doc.grid-plan')
pdfPath=''
odtPath=''
do output over document~outputs
  if right(output~lower,4)=='.pdf' then pdfPath=output
  if right(output~lower,4)=='.odt' then odtPath=output
end
if pdfPath=='' | odtPath=='' then do
  say 'STOP: PDF and ODT output paths must be registered in the DOCY graph'
  exit 5
end
providers=.directory~new
providers['pdf.flow']=.PdfFlowReport
providers['pdf.table']=.PdfTable
providers['odt.access']=.OdtAccess
providers['odt.table']=.OdtTable
pdf=.DocyOfficePublisher~publishPdf(graph,'doc.grid-plan',pdfPath,providers)
say 'PDF DIAGNOSTICS:'
say pdf['report']~summary
if pdf['report']~hasStops then exit 3
say 'PDF:' pdf['path']
odt=.DocyOfficePublisher~publishOdt(graph,'doc.grid-plan',odtPath,providers)
say 'ODT DIAGNOSTICS:'
say odt['report']~summary
if odt['report']~hasStops then exit 4
say 'ODT:' odt['path']
exit 0

::requires 'docy_store.cls'
::requires 'docy_office.cls'
::requires 'PdfCore.cls'
::requires 'OdtAccess.cls'
