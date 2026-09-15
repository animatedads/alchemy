doc = .XmlDocumentContext~new('fixtures/orders.xml')
doc~registerNamespace('o','urn:example:orders')
doc~registerNamespace('c','urn:example:common')
style = .XmlDocumentContext~new('fixtures/orders_parameterized.xsl')
params = .table~new
params['label'] = 'HardWorld provenance'
out = doc~transform(style, params)
if out~parentDocument \== doc then call fail 'parent provenance'
if out~transformParameters['label'] \= 'HardWorld provenance' then call fail 'parameter provenance'
if out~xpath('/Summary/Label')~scalar \= 'HardWorld provenance' then call fail 'parameter value'
if out~xpath('/Summary/OrderCount')~scalar \= '2' then call fail 'count value' out~xpath('/Summary/OrderCount')~scalar
if out~xpath('/Summary/FirstBuyer')~scalar \= 'Acme Manufacturing' then call fail 'buyer'
labelNode = out~xpath('/Summary/Label')~firstNode
if labelNode~derivedFrom~items < 1 then call fail 'derived-from links'
countText = out~xpath('/Summary/OrderCount/text()')~firstNode
if countText~derivedFrom~items < 3 then call fail 'count source lineage' countText~derivedFrom~items
buyerText = out~xpath('/Summary/FirstBuyer/text()')~firstNode
foundBuyerSource = .false
do sourceObject over buyerText~derivedFrom
  if sourceObject~isA(.XmlNodeRef) then if sourceObject~qName = 'c:Buyer' then foundBuyerSource = .true
end
if \foundBuyerSource then call fail 'buyer exact-source lineage'
say 'XML NATIVE TRANSFORM SMOKE: OK'
exit 0
fail:
  use arg label, detail=''
  say 'FAIL:' label detail
  exit 1
::requires '../src/RichSourceCore.cls'
::requires '../src/XmlNativeSource.cls'
