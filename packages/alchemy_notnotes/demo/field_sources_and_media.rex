/* field_sources_and_media.rex
 * Small notNotes demonstration of FromReference and FromExternalDocument.
 */

fieldNode = .AlchemyNotNotesNode~new("FIELD")
officeNode = .AlchemyNotNotesNode~new("OFFICE")

acme = fieldNode~createDocument("Customer")
acme~CompanyName = "Acme Engineering"
acme~Phone = "0161 555 0100"
fieldNode~save(acme)

central = fieldNode~createDocument("Customer")
central~CompanyName = "Central Hydraulics"
central~Phone = "0161 555 0200"
fieldNode~save(central)

fieldNode~connect(officeNode)~replicate

order = officeNode~createDocument("Sales Order")
order~OrderNumber = "SO-2001"
order~TotalSales = 12500
customerField = order~defineField("Customer", .FromReference~new(.Document~type("Customer")))
customerReferences = customerField~references(officeNode)

say "Customer references offered:" customerReferences~items
do reference over customerReferences
  customer = reference~resolve(officeNode)
  say " " reference~documentId customer~CompanyName
end

/* Choose Acme for the demo. */
do reference over customerReferences
  customer = reference~resolve(officeNode)
  if customer~CompanyName = "Acme Engineering" then do
    order~setReferenceField("Customer", reference)
    leave
  end
end
officeNode~save(order)

customer = order~Customer
headShotField = customer~defineField("HeadShot", .FromExternalDocument~new("image/"))
headShot = officeNode~pasteExternalDocument("alice-headshot.jpg", "image/jpeg", "JPEG-DEMO-PAYLOAD")
customer~setExternalField("HeadShot", headShotField~linkExternal(headShot))

videoField = customer~defineField("VisitVideo", .FromExternalDocument~new("video/"))
video = officeNode~pasteExternalDocument("visit.mp4", "video/mp4", "MP4-DEMO-PAYLOAD")
customer~setExternalField("VisitVideo", videoField~linkExternal(video))
officeNode~save(customer)

officeNode~connect(fieldNode)~replicate

returnedCustomer = fieldNode~document(acme~documentId)
returnedHeadShot = returnedCustomer~HeadShot~resolve(fieldNode)
returnedVideo = returnedCustomer~VisitVideo~resolve(fieldNode)
orders = returnedCustomer~linkedDocuments(.Document~type("Sales Order"))

say
say "After replication back to FIELD:"
say " Customer:" returnedCustomer~CompanyName
say " Head shot:" returnedHeadShot~displayName returnedHeadShot~mediaType "bytes="returnedHeadShot~size
say " Video:" returnedVideo~displayName returnedVideo~mediaType "bytes="returnedVideo~size
say " Linked sales orders:" orders~items
if orders~items > 0 then say " Order:" orders~at(1)~OrderNumber "customer="orders~at(1)~Customer~CompanyName

::requires 'src/AlchemyNotNotes.cls'
