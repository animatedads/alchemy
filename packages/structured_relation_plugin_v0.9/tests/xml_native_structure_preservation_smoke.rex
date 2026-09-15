doc = .XmlDocumentContext~new('fixtures/structure.xml')
doc~registerNamespace('r','urn:root')
if doc~validationFindings~items < 1 then call fail 'doctype evidence absent'
if doc~validationFindings[1]~code \= 'XML.DOCTYPE.PRESERVED' then call fail 'doctype finding code'
items = doc~xpath('/r:Root/r:Item')
if items~count \= 2 then call fail 'item count' items~count
first = items~nodes[1]
if first~attribute('id')~value \= 'A&B' then call fail 'attribute entity decode' first~attribute('id')~value
if first~attribute('id')~lexicalValue \= 'A&amp;B' then call fail 'attribute lexical lost'
if first~children~items < 2 then call fail 'mixed content structure lost'
foundCdata = .false
do child over first~children
  if child~kind = 'CDATA' then do
    foundCdata = .true
    if child~value~pos('raw <xml>') = 0 then call fail 'cdata value'
    if child~span~startLine <= 0 then call fail 'cdata span'
  end
end
if \foundCdata then call fail 'cdata node absent'
second = items~nodes[2]
if second~text \= 'AB' then call fail 'numeric entities' second~text
if doc~sourceText~pos('definitely-not-read.dtd') = 0 then call fail 'source text not retained'
if doc~root~span~source \= 'fixtures/structure.xml' then call fail 'source span source'
say 'XML NATIVE STRUCTURE PRESERVATION SMOKE: OK'
exit 0
fail:
  use arg label, detail=''
  say 'FAIL:' label detail
  exit 1
::requires '../src/RichSourceCore.cls'
::requires '../src/XmlNativeSource.cls'
