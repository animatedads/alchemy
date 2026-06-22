/* ========================================================================= */
/* gempdf4.rex - Multi-Page PDF Document with Multi-Column Text Parsing      */
/* ========================================================================= */


doc = .PDFDocument~new()

/* --- PAGE 1: LEDGER TABLE --- */
p1 = .ContentStream~new()
p1~setFont("F1", 20)
p1~writeTextAt(50, 720, "ooRexx Automatically Formatted Ledger")
p1~setFont("F1", 10)
p1~writeTextAt(50, 695, "Generated cleanly using pure vector data grid matrix mapping rows.")

widths  = .array~of(80, 140, 100, 100)
headers = .array~of("Item Code", "Product Description", "Unit Price", "Stock Level")

rows = .array~new()
rows~append(.array~of("TX-101", "Native ooRexx Compiler Shell", "$249.00", "Available"))
rows~append(.array~of("BG-904", "Banish Bit-Order Goblin Patch", "$0.00", "Critical"))
rows~append(.array~of("PDF-42", "Cubic Bezier Node Plotter", "$89.50", "98 Units"))

p1~drawTable(50, 660, widths, 22, headers, rows)
p1~addStandardFooter()
doc~addPage(p1)


/* --- PAGE 2: GAZETTE WITH GRADIENT BACKGROUND --- */
p2 = .ContentStream~new()
p2~setFont("F1", 22)
p2~writeTextAt(50, 720, "The ooRexx Systems Gazette")

p2~setFont("F1", 10)
p2~writeTextAt(50, 700, "Volume 1, Issue 42 - Native Layout Special Edition")

/* Layout bounds setup */
columnXCoords = .array~of(50, 320)
columnWidth   = 242
columnGap     = 28
topY          = 660
bottomLimit   = 350
rowSpacing    = 14

articleText = "Open Object REXX continues to surprise developers with its elegant " || ,
              "blend of classic structural execution and deep object-oriented syntax. " || ,
              "By bypassing complex external dependencies and native binaries, we have " || ,
              "constructed a highly modular document composition workflow from scratch. " || ,
              "When compiling multi-column text structures, managing the raw PDF matrix " || ,
              "coordinates can be a true structural nightmare. However, wrapping our relative " || ,
              "displacements cleanly inside specialized class methods allows the application " || ,
              "layer to remain beautifully decoupled from line endings and line terminators. " || ,
              "Text wraps seamlessly on precise word boundaries, flowing beautifully from " || ,
              "the bottom baseline of the first column straight back up to the top header " || ,
              "boundary of the secondary layout grid channel."

p2~setFont("F1", 11)
leftoverText = p2~writeMultiColumnText(topY, bottomLimit, columnWidth, columnGap, columnXCoords, rowSpacing, articleText)

/* --- EXECUTE GRADIENT CANVAS OPERATIONS --- */
art2 = .Canvas~new()

/* 1. Thin grey column separator line */
art2~setLineWidth(0.5)
art2~setStrokeColor(0.7, 0.7, 0.7)
art2~drawLine(296, 660, 296, 350)

/* 2. Compute a gorgeous emulated gradient card in Column 2 */
/* Target Coordinates: X=320, Y=500, Width=242, Height=110 */
/* Color bounds: Blend from Midnight Navy (0.1, 0.2, 0.4) down to Teal Slate (0.3, 0.5, 0.6) */
art2~drawLinearGradient(320, 500, 242, 110, 0.1, 0.2, 0.4, 0.3, 0.5, 0.6)

/* 3. Add a clean, unshaded frame border over the top of our gradient slice stack */
art2~setLineWidth(1.5)
art2~setStrokeColor(0.05, 0.1, 0.25)
art2~drawRectangle(320, 390, 242, 110, "stroke")

/* Push our emulated slice vectors into the content stream memory */
p2~drawCanvas(art2)

/* --- OVERLAY TEXT CREATING CONTRAST GRAPHICS --- */
/* Switch text color directly inside the page command buffer using white text (1 1 1 rg) */
p2~setFont("F1", 10)
p2~writeTextAt(332, 475, "NOTE FROM THE EDITOR:")
p2~setFont("F1", 9)
p2~writeTextAt(332, 455, "This callout card uses a 73-step math LERP")
p2~writeTextAt(332, 440, "loop executing completely natively in ooRexx.")
p2~writeTextAt(332, 425, "Thin overlapping polygon slices simulate a")
p2~writeTextAt(332, 410, "perfectly seamless vertical background blend.")

p2~addStandardFooter()
doc~addPage(p2)


/* --- COMPILE AND WRITE --- */
doc~buildDocument()
doc~save("flatedecode_multipage.pdf")

say "SUCCESS: Gradient fill layout successfully rendered via LERP matrix arrays!"
exit 0


::requires "ooPdf.cls"
