/* XML fact */
xmlDoc = .XmlDocumentContext~new("fixtures/orders.xml")
xmlDoc~registerNamespace("o", "urn:example:orders")
xmlDoc~registerNamespace("c", "urn:example:common")
xmlProvider = .XmlRelationProvider~new(.CrossResult)
xmlDef = xmlProvider~defineRelation("xml_lines", xmlDoc, "/o:Orders/o:Order/o:Line")
xmlDef~columnMap("business_id", "../@id")
xmlFact = xmlProvider~table("xml_lines")~readRows[1]~fact("business_id")

/* EDIFACT fact */
ediDoc = .EdiFactDocumentContext~new("fixtures/orders.edi")
ediProvider = .EdiFactRelationProvider~new(.CrossResult)
ediDef = ediProvider~defineRelation("edi_orders", ediDoc, "MESSAGE:ORDERS")
ediDef~columnMap("business_id", "BGM/2")
ediFact = ediProvider~table("edi_orders")~readRows[1]~fact("business_id")

/* X12 fact */
x12Doc = .X12DocumentContext~new("fixtures/purchase_order.x12")
x12Provider = .X12RelationProvider~new(.CrossResult)
x12Def = x12Provider~defineRelation("x12_orders", x12Doc, "TRANSACTION:850")
x12Def~columnMap("business_id", "BEG/3")
x12Fact = x12Provider~table("x12_orders")~readRows[1]~fact("business_id")

call assert xmlFact~isA(.RichBusinessFact), "XML fact shares RichBusinessFact contract"
call assert ediFact~isA(.RichBusinessFact), "EDIFACT fact shares RichBusinessFact contract"
call assert x12Fact~isA(.RichBusinessFact), "X12 fact shares RichBusinessFact contract"
call assert xmlFact~isEvidenceBearing, "XML fact evidence-bearing"
call assert ediFact~isEvidenceBearing, "EDIFACT fact evidence-bearing"
call assert x12Fact~isEvidenceBearing, "X12 fact evidence-bearing"

call assert xmlFact~sourceProvenance["kind"] = "ATTRIBUTE", "XML provenance remains native XML"
call assert ediFact~sourceProvenance["kind"] = "EDIFACT_ELEMENT", "EDIFACT provenance remains native EDIFACT"
call assert x12Fact~sourceProvenance["kind"] = "X12_ELEMENT", "X12 provenance remains native X12"
call assert xmlFact~sourceDocument == xmlDoc, "XML common sourceDocument"
call assert ediFact~sourceDocument == ediDoc, "EDIFACT common sourceDocument"
call assert x12Fact~sourceDocument == x12Doc, "X12 common sourceDocument"
call assert xmlFact~lexicalValue = "PO-1001", "XML lexical value"
call assert ediFact~lexicalValue = "PO12345", "EDIFACT lexical value"
call assert x12Fact~lexicalValue = "PO12345", "X12 lexical value"

/* HardWorld asks the same questions; the native evidence underneath stays intact. */
do fact over .array~of(xmlFact, ediFact, x12Fact)
  call assert fact~name = "business_id", "common semantic fact name"
  call assert fact~state = "PRESENT", "common evidence state"
  call assert fact~sourcePath <> "", "common source path"
  call assert fact~processingHistory~items > 0, "common processing history"
  evidence = fact~evidence
  call assert evidence["source"] == fact~source, "evidence preserves source identity"
  call assert evidence["sourceDocument"] == fact~sourceDocument, "evidence preserves document identity"
  call assert evidence["sourcePath"] = fact~sourcePath, "evidence preserves path"
  call assert evidence["processingHistory"] == fact~processingHistory, "evidence preserves history object"
end

say "CROSS FORMAT BUSINESS FACT SMOKE: OK"
exit 0

assert: procedure
  use arg conditionValue, message
  if \conditionValue then do
    say "ASSERT FAILED:" message
    exit 1
  end
  return .true

::class CrossResult public
::method init
  use arg operation = "SELECT"

::requires "../src/XmlRelationAdapter.cls"
::requires "../src/EdiFactRelationAdapter.cls"
::requires "../src/X12RelationAdapter.cls"
