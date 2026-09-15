/*
 * Test server: structured_relation_plugin v0.5 native XML/EDIFACT/X12 facts
 * -> v0.16 RichEvidence -> Algorithm Relation -> NoSQLServer v0.71 -> msqlshim v0.10.
 */
parse arg port root
if port == '' then port = 3676
if root == '' then root = '/tmp/msql_structured_rich_v016'

fed=.FederatedDatabaseEngine~new(root)

xmlDoc=.XmlDocumentContext~new('fixtures/orders.xml')
xmlDoc~registerNamespace('o','urn:example:orders'); xmlDoc~registerNamespace('c','urn:example:common')
xmlProvider=.XmlRelationProvider~new(.DatabaseResult)
xmlDef=xmlProvider~defineRelation('xml_lines',xmlDoc,'/o:Orders/o:Order/o:Line')
xmlDef~columnMap('business_id','../@id')
xmlFact=xmlProvider~table('xml_lines')~readRows[1]~fact('business_id')

ediDoc=.EdiFactDocumentContext~new('fixtures/orders.edi')
ediProvider=.EdiFactRelationProvider~new(.DatabaseResult)
ediDef=ediProvider~defineRelation('edi_orders',ediDoc,'MESSAGE:ORDERS')
ediDef~columnMap('business_id','BGM/2')
ediFact=ediProvider~table('edi_orders')~readRows[1]~fact('business_id')

x12Doc=.X12DocumentContext~new('fixtures/purchase_order.x12')
x12Provider=.X12RelationProvider~new(.DatabaseResult)
x12Def=x12Provider~defineRelation('x12_orders',x12Doc,'TRANSACTION:850')
x12Def~columnMap('business_id','BEG/3')
x12Fact=x12Provider~table('x12_orders')~readRows[1]~fact('business_id')

xmlQtyProvider=.XmlRelationProvider~new(.DatabaseResult)
xmlQtyDef=xmlQtyProvider~defineRelation('xml_qty',xmlDoc,'/o:Orders/o:Order/o:Line')
xmlQtyDef~columnMap('quantity','c:Quantity','INTEGER')
xmlQtyFact=xmlQtyProvider~table('xml_qty')~readRows[2]~fact('quantity')
x12QtyProvider=.X12RelationProvider~new(.DatabaseResult)
x12QtyDef=x12QtyProvider~defineRelation('x12_qty',x12Doc,'TRANSACTION:850')
x12QtyDef~columnMap('quantity','PO1/2','INTEGER')
x12QtyFact=x12QtyProvider~table('x12_qty')~readRows[1]~fact('quantity')
qtyEvidence=.StructuredRelationRichEvidenceAdapter~combineFacts('ORDER_QUANTITY',.array~of(xmlQtyFact,x12QtyFact),'FROZEN_OBSERVATION','STRUCTURED-V05-WIRE-QTY')

schema=.AlgorithmSchema~new('STRUCTURED_RICH_INPUT')
schema~add('FACT_ID','TEXT',.false); schema~add('RICH_VALUE','RICH_OBJECT',.false)
builder=.AlgorithmInputRelationBuilder~new(schema,'STRUCTURED_RICH_INPUT')
items=.array~of(.array~of('XML_BUSINESS_ID',.StructuredRelationRichEvidenceAdapter~adaptFact(xmlFact)), -
                .array~of('EDI_BUSINESS_ID',.StructuredRelationRichEvidenceAdapter~adaptFact(ediFact)), -
                .array~of('X12_BUSINESS_ID',.StructuredRelationRichEvidenceAdapter~adaptFact(x12Fact)), -
                .array~of('ORDER_QUANTITY',qtyEvidence))
do item over items
  vals=.directory~new; vals['FACT_ID']=item[1]; vals['RICH_VALUE']=item[2]
  if \builder~addValues(vals) then raise syntax 93.900 additional('structured rich input row rejected')
end
snapshot=builder~freeze('STRUCTURED-V05-WIRE')

provider=.RichBusinessFactAlgorithmProvider~new('..')
algorithmEngine=.AlgorithmRelationEngine~new
if \algorithmEngine~addProvider(provider) then raise syntax 93.900 additional('provider registration failed')
ctx=.AlgorithmExecutionContext~new('STRUCTURED-V05-WIRE-INV',snapshot~sourceOid,snapshot~sourceOid)
classes=.directory~new
classes['TABLE_DEFINITION']=.TableDefinition
classes['DATABASE_ROW']=.DatabaseRow
classes['DATABASE_RESULT']=.DatabaseResult
bindings=.directory~new
bindings['RICH_FACT_SUMMARY']='structured_fact_summary'
bindings['RICH_FACT_SOURCES']='structured_fact_sources'
bindings['RICH_FACT_TRACE']='structured_fact_trace'
external=.NoSQLAlgorithmRelationExternalEngine~new(algorithmEngine,'RICH_BUSINESS_FACTS',snapshot,ctx,classes,bindings)
if \external~isReady then raise syntax 93.900 additional('external engine failed:' external~lastError)
ignore=fed~addEngine(external)

stats=.array~of(.StructuredRichStats~new(provider))
sm=.ObjectTableMapping~new('structured_provider_stats')
ignore=sm~column('invocations','INTEGER','invocationCount')
if \fed~register('structured_provider_stats',stats,sm) then raise syntax 93.900 additional('stats registration failed')

server=.MySQLWireServer~new(root,'127.0.0.1',port)
server~engine=fed
say 'MSQL V010 STRUCTURED RICH V016 READY port=' || port || ' invocations=' || provider~invocationCount
server~serve

::class StructuredRichStats
::attribute provider get
::method init
  expose provider
  use arg provider
::method invocationCount
  return self~provider~invocationCount

::requires 'src/MySQLWireServer.cls'
::requires 'XmlRelationAdapter.cls'
::requires 'EdiFactRelationAdapter.cls'
::requires 'X12RelationAdapter.cls'
::requires '../integration/NoSQLServerAlgorithmRelationExternalEngine.cls'
::requires '../integration/RichBusinessFactAlgorithmProvider.cls'
::requires '../integration/StructuredRelationRichEvidenceAdapter.cls'
::requires '../algorithm/AlgorithmRelation.cls'
::requires '../algorithm/AlgorithmInputRelation.cls'
::requires '../algorithm/AlgorithmIntegrity.cls'
::requires '../algorithm/RichEvidence.cls'
