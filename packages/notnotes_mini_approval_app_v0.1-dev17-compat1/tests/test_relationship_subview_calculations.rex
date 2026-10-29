root = value("MININOTES_TEST_ROOT",, "ENVIRONMENT")
app = .MiniNotesApp~new(root)
ui = .MiniNotesCliUi~new(app)

/* Customer */
ui~executeCommand("create a new document format called Customer")
ui~executeCommand("I need a field for the Name")
ui~executeCommand("I need a field for the Company")
ui~executeCommand("I need a field for the Phone")
ui~executeCommand("I need a field for the Address")
ui~executeCommand("SAVE")

/* Product */
ui~executeCommand("create a new document format called Product")
ui~executeCommand("I need a field for the Name")
ui~executeCommand("I need a field for the Price")
ui~executeCommand("SAVE")

/* Sales line: references are the default when the field name is a known document format. */
ui~executeCommand("create a new document format called Sales Line")
ui~executeCommand("I need a Product")
ui~executeCommand("I need an Order")
ui~executeCommand("I need a field for the Quantity")
ui~executeCommand("SAVE")

/* Order: linked customer plus embedded sales-line subview and calculations. */
ui~executeCommand("create a new document format called Order")
ui~executeCommand("I need a Customer")
ui~executeCommand("insert subview Sales Lines from Sales Line linked by Order")
ui~executeCommand("subview column Product")
ui~executeCommand("subview column Product.Price as Price")
ui~executeCommand("subview column Quantity")
ui~executeCommand("row calculated Total = Product.Price * Quantity")
ui~executeCommand("column calculated Order Total = SUM(Total)")
ui~executeCommand("SAVE")

call assertEqual "DOCUMENT_REFERENCE", app~node~documentDefinition("Order/1")~fieldDefinition("Customer")~semanticType, "Customer reference type"
call assertEqual "Customer", app~relationshipTarget("Order", "Customer"), "Customer target"
call assertEqual "Product", app~relationshipTarget("Sales Line", "Product"), "Product target"
call assertEqual "Order", app~relationshipTarget("Sales Line", "Order"), "Order target"

customerValues = .Directory~new
customerValues["Name"] = "Alice Morgan"
customerValues["Company"] = "Initech"
customerValues["Phone"] = "0161 555 0100"
customerValues["Address"] = "Rochdale"
customer = app~createUserDocument("Customer", app~userFormatFields("Customer"), customerValues)

productValues = .Directory~new
productValues["Name"] = "Red Stapler"
productValues["Price"] = "12.50"
product = app~createUserDocument("Product", app~userFormatFields("Product"), productValues)

orderValues = .Directory~new
orderValues["Customer"] = customer~DocKey
order = app~createUserDocument("Order", app~userFormatFields("Order"), orderValues)

line1Values = .Directory~new
line1Values["Product"] = product~DocKey
line1Values["Order"] = order~DocKey
line1Values["Quantity"] = "3"
line1 = app~createUserDocument("Sales Line", app~userFormatFields("Sales Line"), line1Values)
line2Values = .Directory~new
line2Values["Product"] = product~DocKey
line2Values["Order"] = order~DocKey
line2Values["Quantity"] = "2"
line2 = app~createUserDocument("Sales Line", app~userFormatFields("Sales Line"), line2Values)

call assertEqual customer~DocKey, order~Customer, "reference stores stable document key"
call assertEqual customer~documentId, app~referencedDocument(order, "Customer")~documentId, "reference resolves target"

subviews = app~subviewDefinitionsFor("Order")
call assertEqual 1, subviews~items, "one order subview"
rows = app~subviewRows(order, subviews[1])
call assertEqual 2, rows~items, "two sales lines"
call assertEqual "37.5", rows[1]["Total"]~string, "row calculated total line 1"
call assertEqual "25.0", rows[2]["Total"]~string, "row calculated total line 2"
call assertEqual "62.5", app~subviewColumnValue(rows, subviews[1], "OrderTotal")~string, "column calculated order total"

referenceText = app~renderReferencesFor(order)
call assertContains referenceText, "Alice Morgan", "customer name projected"
call assertContains referenceText, "Initech", "customer company projected"
subviewText = app~renderSubviewsFor(order)
call assertContains subviewText, "12.50", "product price traversed"
call assertContains subviewText, "Order Total: 62.5", "aggregate displayed"

ignore = app~persistNow

/* Fresh-process-equivalent reload over the same durable store. */
app2 = .MiniNotesApp~new(root)
order2 = app2~byKey(order~DocKey)
call assertTrue order2 \== .nil, "order survives reload"
call assertEqual customer~DocKey, order2~Customer, "reference key survives reload"
call assertEqual customer~DocKey, app2~referencedDocument(order2, "Customer")~DocKey, "reference resolves after reload"
subviews2 = app2~subviewDefinitionsFor("Order")
call assertEqual 1, subviews2~items, "subview definition survives reload"
rows2 = app2~subviewRows(order2, subviews2[1])
call assertEqual 2, rows2~items, "subview rows survive reload"
call assertEqual "62.5", app2~subviewColumnValue(rows2, subviews2[1], "OrderTotal")~string, "aggregate survives reload"
call assertContains app2~renderReferencesFor(order2), "Alice Morgan", "reference projection survives reload"
call assertContains app2~renderSubviewsFor(order2), "Order Total: 62.5", "subview projection survives reload"

say "PASS linked documents / subview / row calculation / column calculation / reload"
exit 0

assertTrue: procedure
  use arg condition, label
  if \condition then do
    say "FAIL" label
    exit 1
  end
  return

assertEqual: procedure
  use arg expected, actual, label
  if expected \= actual then do
    say "FAIL" label "expected="expected "actual="actual
    exit 1
  end
  return

assertContains: procedure
  use arg haystack, needle, label
  if haystack~pos(needle) = 0 then do
    say "FAIL" label "needle="needle
    say haystack
    exit 1
  end
  return

::requires 'src/MiniNotesCliUi.cls'
