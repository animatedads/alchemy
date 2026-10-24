/* test_field_sources_external_documents.rex
 * Contract probe for typed internal reference fields and pasted external
 * image/video documents travelling with their owning document revision.
 */

fieldNode = .AlchemyNotNotesNode~new("FIELD")
officeNode = .AlchemyNotNotesNode~new("OFFICE")
fieldToOffice = fieldNode~connect(officeNode)

customer1 = fieldNode~createDocument("Customer")
customer1~CompanyName = "Acme Engineering"
customer1~Phone = "0161 555 0100"
fieldNode~save(customer1)

customer2 = fieldNode~createDocument("Customer")
customer2~CompanyName = "Central Hydraulics"
customer2~Phone = "0161 555 0200"
fieldNode~save(customer2)

customer3 = fieldNode~createDocument("Customer")
customer3~CompanyName = "North Works"
customer3~Phone = "0161 555 0300"
fieldNode~save(customer3)

batch = fieldToOffice~replicate
call assertEqual 3, batch~count("CREATED"), "customer population replicated"

officeCustomer = officeNode~document(customer1~documentId)

/* A FromReference field exposes typed local document references. */
salesOrder = officeNode~createDocument("Sales Order")
salesOrder~OrderNumber = "SO-2001"
customerField = salesOrder~defineField("Customer", .FromReference~new(.Document~type("Customer")))
references = customerField~references(officeNode)
call assertEqual 3, references~items, "customer reference choices"

selected = .nil
do reference over references
  candidate = reference~resolve(officeNode)
  if candidate~CompanyName = "Acme Engineering" then do
    selected = reference
    leave
  end
end
call assertTrue selected \== .nil, "customer reference selected"
salesOrder~setReferenceField("Customer", selected)
call assertEqual customer1~documentId, salesOrder~Customer~documentId, "typed reference bound as relation"
officeNode~save(salesOrder)

/* Pasting rich media creates external documents; fields carry durable links. */
headShotField = officeCustomer~defineField("HeadShot", .FromExternalDocument~new("image/"))
headShot = officeNode~pasteExternalDocument("alice-headshot.jpg", "image/jpeg", "JPEG-DEMO-PAYLOAD")
headShotLink = headShotField~linkExternal(headShot)
officeCustomer~setExternalField("HeadShot", headShotLink)

videoField = officeCustomer~defineField("VisitVideo", .FromExternalDocument~new("video/"))
visitVideo = officeNode~pasteExternalDocument("visit-2026-09-29.mp4", "video/mp4", "MP4-DEMO-PAYLOAD")
videoLink = videoField~linkExternal(visitVideo)
officeCustomer~setExternalField("VisitVideo", videoLink)
officeNode~save(officeCustomer)

/* Replication must carry the external-document dependency closure first. */
officeToField = fieldToOffice~reverse
batch = officeToField~replicate
call assertEqual 1, batch~count("CREATED"), "sales order created on field node"
call assertEqual 1, batch~count("UPDATED"), "customer with media updated on field node"

returnedCustomer = fieldNode~document(customer1~documentId)
returnedHeadShotLink = returnedCustomer~HeadShot
returnedHeadShot = returnedHeadShotLink~resolve(fieldNode)
call assertTrue returnedHeadShot \== .nil, "headshot external document resolved"
call assertEqual "alice-headshot.jpg", returnedHeadShot~displayName, "headshot name"
call assertEqual "image/jpeg", returnedHeadShot~mediaType, "headshot media type"
call assertEqual "JPEG-DEMO-PAYLOAD", returnedHeadShot~content, "headshot payload"
call assertEqual "PASTE", returnedHeadShot~sourceKind, "headshot paste provenance"
call assertTrue returnedHeadShot \== headShot, "headshot replica object independence"

returnedVideo = returnedCustomer~VisitVideo~resolve(fieldNode)
call assertTrue returnedVideo \== .nil, "video external document resolved"
call assertEqual "video/mp4", returnedVideo~mediaType, "video media type"
call assertEqual "MP4-DEMO-PAYLOAD", returnedVideo~content, "video payload"

/* Field source definitions travel with the document revision too. */
returnedHeadShotField = returnedCustomer~fieldObject("HeadShot")
call assertEqual "image/", returnedHeadShotField~source~mediaTypePrefix, "headshot field source replicated"

orders = returnedCustomer~linkedDocuments(.Document~type("Sales Order"))
call assertEqual 1, orders~items, "linked sales order count"
returnedOrder = orders~at(1)
call assertEqual "SO-2001", returnedOrder~OrderNumber, "returned order number"
call assertEqual returnedCustomer~documentId, returnedOrder~Customer~documentId, "returned typed relation"
returnedCustomerField = returnedOrder~fieldObject("Customer")
call assertEqual "Customer", returnedCustomerField~source~typeFilter~formName, "reference field source replicated"

say "PASS test_field_sources_external_documents"
exit 0

assertEqual: procedure
  use arg expected, actual, label
  if expected == actual then return
  say "FAIL" label "expected="expected "actual="actual
  exit 1

assertTrue: procedure
  use arg actual, label
  if actual then return
  say "FAIL" label
  exit 1

::requires 'src/AlchemyNotNotes.cls'
