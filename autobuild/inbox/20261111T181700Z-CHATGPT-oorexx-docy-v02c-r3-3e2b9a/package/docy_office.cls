/* DOCY format adapters. No duplicate type switch and no shell conversion.
   The caller supplies Alchemy's public provider class objects: PdfFlowReport,
   PdfTable, OdtAccess and OdtTable. DOCY objects retain authority.
   Export fidelity warnings are accumulated in the same DOCY report buckets.
*/
::class DocyPdfSink public
::method init
  expose report tableFactory
  use strict arg report,tableFactory
::method addSection
  expose report
  use strict arg caption,level
  report~addSection(caption,level)
::method addParagraph
  expose report
  use strict arg text
  report~addParagraph(text)
::method addDataTable
  expose report tableFactory
  use strict arg headers,rows,key
  widths=.array~new
  do header over headers
    widths~append(1)
  end
  table=tableFactory~new(headers,widths)
  table~addRows(rows)
  report~addTable(table)
::method finish
  expose report
  use strict arg outputPath
  report~render(outputPath)

::class DocyOdtSink public
::method init
  expose document tableFactory accessFactory
  use strict arg document,tableFactory,accessFactory
::method addHeading
  expose document
  use strict arg caption,level
  document~addHeading(caption,level)
::method addParagraph
  expose document
  use strict arg text
  document~addParagraph(text)
::method addDataTable
  expose document tableFactory
  use strict arg headers,rows,key
  table=tableFactory~new(key)
  table~addValues(headers)
  do cells over rows
    table~addValues(cells)
  end
  document~addTable(table)
::method finish
  expose document accessFactory
  use strict arg outputPath
  accessFactory~save(document,outputPath)

::class DocyOfficePublisher public
::method publishPdf class
  use strict arg graph, documentKey, outputPath, providers
  bundle=self~preflight(graph,documentKey,'pdf')
  diagnosis=bundle['report']
  if diagnosis~hasStops then return bundle
  reportFactory=providers['pdf.flow']
  tableFactory=providers['pdf.table']
  if reportFactory == .nil | tableFactory == .nil then do
    diagnosis~add('STOP','PDF.PROVIDER.MISSING','PdfFlowReport/PdfTable classes not registered')
    return bundle
  end
  /* A failed publisher must return a diagnostic, not abort the entire
     document operation with an uncaught ooRexx condition. */
  signal on syntax name pdfProviderFailure
  signal on error name pdfProviderFailure
  signal on failure name pdfProviderFailure
  doc=graph~document(documentKey)
  raw=reportFactory~new
  raw~title=doc~title
  sink=.DocyPdfSink~new(raw,tableFactory)
  do placement over doc~effectivePlacements(graph)
    node=graph~node(placement~nodeKey)
    if node == .nil then iterate
    node~renderPdf(sink,graph,doc,placement,diagnosis)
  end
  if diagnosis~hasStops then return bundle
  sink~finish(outputPath)
  bundle['path']=outputPath
  return bundle
pdfProviderFailure:
  diagnosis~add('STOP','PDF.PROVIDER.ERROR',condition('D'))
  bundle['path']=''
  return bundle

::method publishOdt class
  use strict arg graph, documentKey, outputPath, providers, creator='Alchemy DOCY'
  bundle=self~preflight(graph,documentKey,'odt')
  diagnosis=bundle['report']
  if diagnosis~hasStops then return bundle
  accessFactory=providers['odt.access']
  tableFactory=providers['odt.table']
  if accessFactory == .nil | tableFactory == .nil then do
    diagnosis~add('STOP','ODT.PROVIDER.MISSING','OdtAccess/OdtTable classes not registered')
    return bundle
  end
  signal on syntax name odtProviderFailure
  signal on error name odtProviderFailure
  signal on failure name odtProviderFailure
  doc=graph~document(documentKey)
  raw=accessFactory~create(doc~title,creator)
  sink=.DocyOdtSink~new(raw,tableFactory,accessFactory)
  sink~addHeading(doc~title,1)
  do placement over doc~effectivePlacements(graph)
    node=graph~node(placement~nodeKey)
    if node == .nil then iterate
    node~renderOdt(sink,graph,doc,placement,diagnosis)
  end
  if diagnosis~hasStops then return bundle
  sink~finish(outputPath)
  bundle['path']=outputPath
  return bundle
odtProviderFailure:
  diagnosis~add('STOP','ODT.PROVIDER.ERROR',condition('D'))
  bundle['path']=''
  return bundle

::method preflight class
  use strict arg graph,documentKey,format
  bundle=.directory~new
  bundle['format']=format
  bundle['report']=graph~validate(documentKey)
  bundle['path']=''
  return bundle

::requires 'docy_v02.cls'
