doc = .XmlDocumentContext~new('fixtures/orders.xml')
style = .XmlDocumentContext~new('fixtures/xslt_external_read.xsl')
if \blocked(doc,style) then call fail 'external document() was not blocked'
say 'XML NATIVE TRANSFORM SECURITY SMOKE: OK'
exit 0
blocked: procedure
  use arg doc, style
  signal on syntax name caught
  result = doc~transform(style)
  signal off syntax
  return .false
caught:
  signal off syntax
  return .true
fail:
  use arg label
  say 'FAIL:' label
  exit 1
::requires '../src/RichSourceCore.cls'
::requires '../src/XmlNativeSource.cls'
