doc = .XmlDocumentContext~new('fixtures/orders.xml')
doc~registerNamespace('o','urn:example:orders')
doc~registerNamespace('c','urn:example:common')
if doc~root == .nil then call fail 'root missing'
if doc~root~qName \= 'o:Orders' then call fail 'wrong root' doc~root~qName
orders = doc~xpath('/o:Orders/o:Order')
if orders~count \= 2 then call fail 'order count' orders~count
first = orders~nodes[1]
if first~attribute('id')~value \= 'PO-1001' then call fail 'id'
qty = doc~xpath('o:Line[2]/c:Quantity', first)
if qty~count \= 1 then call fail 'qty count' qty~count
if qty~nodes[1]~text \= '50' then call fail 'qty text' qty~nodes[1]~text
if qty~nodes[1]~line <= 0 then call fail 'line missing'
if qty~nodes[1]~path~pos('Quantity') = 0 then call fail 'path missing' qty~nodes[1]~path
say 'XML NATIVE MODEL SMOKE: OK'
exit 0
fail:
  use arg label, detail=''
  say 'FAIL:' label detail
  exit 1
::requires '../src/RichSourceCore.cls'
::requires '../src/XmlNativeSource.cls'
