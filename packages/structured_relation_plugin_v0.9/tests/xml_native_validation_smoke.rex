doc = .XmlDocumentContext~new('fixtures/orders.xml')
doc~registerNamespace('o','urn:example:orders')
doc~registerNamespace('c','urn:example:common')
rules = .XmlRuleSet~new('ORDER_LINE_INPUT')
rules~require('/o:Orders/o:Order/o:Line','c:SKU','ORDER.SKU.REQUIRED','SKU is required')
rules~notEmpty('/o:Orders/o:Order/o:Line','c:Quantity','ORDER.QTY.EMPTY','Quantity must not be empty')
rules~type('/o:Orders/o:Order/o:Line','c:Quantity','INTEGER','ORDER.QTY.TYPE','Quantity must be an integer')
rules~cardinality('/o:Orders/o:Order/o:Line','c:Quantity',1,1,'ORDER.QTY.CARD','Exactly one quantity is required')
report = doc~validate(rules)
if report~valid then call fail 'expected invalid report'
if report~findings~items < 2 then call fail 'expected findings' report~findings~items
foundEmpty = .false
foundType = .false
do f over report~findings
  if f~code = 'ORDER.QTY.EMPTY' then do
    foundEmpty = .true
    if \f~source~isA(.XmlNodeRef) then call fail 'empty source object'
    if f~source~path~pos('Quantity') = 0 then call fail 'empty source path' f~source~path
    if f~details['state'] \= 'PRESENT_EMPTY' then call fail 'empty state' f~details['state']
  end
  if f~code = 'ORDER.QTY.TYPE' then do
    foundType = .true
    if f~source~text \= '' then call fail 'type source lexical'
  end
end
if \foundEmpty then call fail 'empty finding absent'
if \foundType then call fail 'type finding absent'
if doc~validationReports~items \= 1 then call fail 'report retained'
if doc~validationFindings~items < report~findings~items then call fail 'document findings retained'
say 'XML NATIVE VALIDATION SMOKE: OK'
exit 0
fail:
  use arg label, detail=''
  say 'FAIL:' label detail
  exit 1
::requires '../src/RichSourceCore.cls'
::requires '../src/XmlNativeSource.cls'
