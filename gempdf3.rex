/* ========================================================================= */
/* gempdf3.rex - Complete Multi-Page PDF Document with Dynamic Tables        */
/* ========================================================================= */


doc = .PDFDocument~new()

/* --- PAGE 1: REPORT LAYOUT --- */
p1 = .ContentStream~new()
p1~setFont("F1", 20)
p1~writeTextAt(50, 720, "ooRexx Automatically Formatted Ledger")

p1~setFont("F1", 10)
p1~writeTextAt(50, 695, "Generated cleanly using pure vector data grid matrix mapping rows.")

/* Define structural arrays for column sizing maps */
widths  = .array~of(80, 140, 100, 100)
headers = .array~of("Item Code", "Product Description", "Unit Price", "Stock Level")

/* Assemble multi-row matrix arrays using clean direct object messages */
rows = .array~new()
rows~append(.array~of("TX-101", "Native ooRexx Compiler Shell", "$249.00", "Available"))
rows~append(.array~of("BG-904", "Banish Bit-Order Goblin Patch", "$0.00", "Critical"))
rows~append(.array~of("PDF-42", "Cubic Bezier Node Plotter", "$89.50", "98 Units"))
rows~append(.array~of("ZLB-77", "Fixed-Huffman Core Wrapper", "$15.00", "Out of Stock"))
rows~append(.array~of("SYS-00", "Standard Base14 Helvetica Font", "FREE", "In-Stream"))

/* Invoke table builder method coordinates directly */
p1~drawTable(50, 660, widths, 22, headers, rows)

/* Stamp footer parameters last */
p1~addStandardFooter()
doc~addPage(p1)


/* --- PAGE 2: ISOLATED CANVAS --- */
p2 = .ContentStream~new()
p2~setFont("F1", 20)
p2~writeTextAt(50, 720, "Automated Secondary Document Summary")

art2 = .Canvas~new()
art2~setFillColor(0.2, 0.6, 0.3)
art2~drawCircle(300, 500, 30, "fill")
p2~drawCanvas(art2)

p2~addStandardFooter()
doc~addPage(p2)


/* --- EXECUTE GENERATION --- */
doc~buildDocument()
doc~save("flatedecode_multipage.pdf")

say "SUCCESS: Generated multi-page ledger document! [flatedecode_multipage.pdf]"
exit 0

::requires "ooPdf.cls"
