/* ========================================================================= */
/* ooPdf.cls - Multi-Page Native PDF Engine with zlib /FlateDecode           */
/* ========================================================================= */

::class PDFDocument public
::method init
  expose pages objCount
  pages = .Array~new()
  objCount = 0

::method addPage public
  expose pages
  use arg contentStreamObj
  pages~append(contentStreamObj)

::method nextObjNum private
  expose objCount
  objCount = objCount + 1
  return objCount

::method buildDocument public
  expose pages objects. objCount
  use arg /* No arguments needed now, reads from addPage queue */

  catNum   = self~nextObjNum()
  pagesNum = self~nextObjNum()

  nl = "0A"x
  pageCount = pages~items()

  pageIds = .Array~new(pageCount)
  contentIds = .Array~new(pageCount)
  do i = 1 to pageCount
    pageIds[i] = self~nextObjNum()
    contentIds[i] = self~nextObjNum()
  end
  fontNum = self~nextObjNum()

  kidsStr = ""
  do i = 1 to pageCount; kidsStr = kidsStr || pageIds[i] "0 R "; end

  objects.[catNum]  = catNum "0 obj" || nl || "<< /Type /Catalog /Pages" pagesNum "0 R >>" || nl || "endobj" || nl
  objects.[pagesNum] = pagesNum "0 obj" || nl || "<< /Type /Pages /Kids ["strip(kidsStr)"] /Count" pageCount ">>" || nl || "endobj" || nl

  do i = 1 to pageCount
    pObj = pageIds[i]
    cObj = contentIds[i]
    cStream = pages[i]

    objects.[pObj] = pObj "0 obj" || nl || ,
                     "<< /Type /Page /Parent" pagesNum "0 R /MediaBox [0 0 612 792] /Contents" cObj "0 R /Resources << /Font << /F1" fontNum "0 R >> >> >>" || nl || "endobj" || nl

    /* Fetch the raw stream data from the page object */
    rawTextStream = cStream~getRawStream()

    /* DYNAMIC MACRO PASS: Replace the tokens with exact execution counts */
    rawTextStream = changestr("{{PAGE_NUM}}", rawTextStream, i)
    rawTextStream = changestr("{{TOTAL_PAGES}}", rawTextStream, pageCount)

    compressedPayload = self~zlibCompress(rawTextStream)

    objects.[cObj] = cObj "0 obj" || nl || ,
                     "<< /Length" length(compressedPayload) "/Filter /FlateDecode >>" || nl || ,
                     "stream" || nl || compressedPayload || nl || "endstream" || nl || "endobj" || nl
  end

  objects.[fontNum] = fontNum "0 obj" || nl || "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>" || nl || "endobj" || nl


::method save public
  expose objects. objCount
  use arg outPath

  nl = "0A"x
  offsets. = 0

  /* Compile the physical file stream buffer map */
  pdf = "%PDF-1.4" || nl || "%" || "E2E3C4D5"x || nl

  do i = 1 to objCount
    offsets.i = length(pdf)
    pdf = pdf || objects.[i]
  end

  xrefOffset = length(pdf)
  pdf = pdf || "xref" || nl || "0" (objCount + 1) || nl || "0000000000 65535 f" || nl
  do i = 1 to objCount
    pdf = pdf || right(offsets.i, 10, "0") "00000 n" || nl
  end

  pdf = pdf || "trailer" || nl || "<< /Size" (objCount + 1) "/Root 1 0 R >>" || nl || ,
               "startxref" || nl || xrefOffset || nl || "%%EOF" || nl

  s = .Stream~new(outPath)
  s~open("write replace")
  s~charout(pdf)
  s~close
  return 0

/* Encapsulates raw DEFLATE into a strict, compliant zlib pipeline container */
::method zlibCompress private
  use arg rawData
  /* 0x789C = Default Compression, 32KB window, no preset dictionary */
  zlibHeader = "789C"x

  deflateBody = self~deflateFixed(rawData)
  adlerTrailer = self~calcAdler32(rawData)

  return zlibHeader || deflateBody || adlerTrailer

::method deflateFixed private
  /* FIX 1: Expose these variables to the object level so writeBits can see them */
  expose outBytes currentByte bitCount
  numeric digits 30
  use arg rawData

  outBytes = ""; currentByte = 0; bitCount = 0

  /* FIX 2: Call as an explicit object message send */
  self~writeBits(3, 3) /* BFINAL=1, BTYPE=01 */

  cursor = 1; dataLen = length(rawData)
  do while cursor <= dataLen
    ch = c2d(substr(rawData, cursor, 1))
    if ch <= 143 then do; code = ch + 48;  bits = 8; end
    else do;              code = ch + 256; bits = 9; end

    self~writeBits(self~bitReverse(code, bits), bits)
    cursor = cursor + 1
  end

  self~writeBits(self~bitReverse(256 - 256, 7), 7)

  if bitCount > 0 then outBytes = outBytes || d2c(currentByte)
  return outBytes

::method writeBits private
  expose outBytes currentByte bitCount
  numeric digits 30
  use arg value, count
  v = value

  do k = 1 to count
    if (v // 2) = 1 then currentByte = currentByte + (2 ** bitCount)
    v = v % 2
    bitCount = bitCount + 1
    if bitCount = 8 then do
      outBytes = outBytes || d2c(currentByte)
      currentByte = 0
      bitCount = 0
    end
  end
  return /* ooRexx allows an empty return for methods modifying exposed state */


::method bitReverse private
  numeric digits 30; use arg value, count; v = value; out = 0
  do k = 1 to count; out = out * 2 + (v // 2); v = v % 2; end
  return out

/* Pure Big-Endian Fletcher-based Adler-32 algorithm bypassing casting hazards */
::method calcAdler32 private
  numeric digits 30
  use arg data
  s1 = 1
  s2 = 0
  len = length(data)
  do i = 1 to len
    b = c2d(substr(data, i, 1))
    s1 = (s1 + b) // 65521
    s2 = (s2 + s1) // 65521
  end
  return d2c(s2, 2) || d2c(s1, 2)



/* ========================================================================= */

::class ContentStream public
::method init
  expose streamData nl
  streamData = ""
  nl = "0A"x

::method setFont public
  expose streamData nl
  use arg fontAlias, fontSize
  streamData = streamData || "/"fontAlias fontSize "Tf" || nl

::method writeTextAt public
  expose streamData nl
  use arg x, y, textString
  escapedText = self~escapePDFString(textString)
  streamData = streamData || "BT" || nl || x y "Td ("escapedText") Tj" || nl || "ET" || nl

::method drawCanvas public
  expose streamData
  use arg canvasObject
  streamData = streamData || canvasObject~getCommands()

::method addStandardFooter public
  expose streamData
  /* Anchors the dynamic macro text string to the bottom of the canvas */
  self~setFont("F1", 10)
  self~writeTextAt(270, 30, "Page {{PAGE_NUM}} of {{TOTAL_PAGES}}")
  return

::method drawTable public
  expose streamData nl
  /* use arg strictly maps individual object and array references */
  use arg startX, startY, colWidthsArray, rowHeight, headersArray, matrixRowsArray

  currentY = startY
  numCols = colWidthsArray~items()
  numRows = matrixRowsArray~items()

  /* Calculate total table pixel width across the requested columns */
  totalWidth = 0
  do c = 1 to numCols
    totalWidth = totalWidth + colWidthsArray[c]
  end

  /* ----------------------------------------------------------------- */
  /* 1. DRAW HEADER ROW                                                */
  /* ----------------------------------------------------------------- */
  /* Dark slate background tint for headers */
  streamData = streamData || "0.2 0.3 0.4 rg" || nl
  streamData = streamData || startX (currentY - rowHeight) totalWidth rowHeight "re f" || nl

  /* Render header text cell elements with padding adjustments */
  streamData = streamData || "1 1 1 rg" || nl /* White text */
  streamData = streamData || "/F1 10 Tf" || nl

  currentX = startX
  do c = 1 to numCols
    /* Apply horizontal padding (+6) and vertical spacing (-rowHeight + 6) */
    textX = currentX + 6
    textY = currentY - rowHeight + 5
    escapedText = self~escapePDFString(headersArray[c])
    streamData = streamData || "BT" || nl || textX textY "Td ("escapedText") Tj" || nl || "ET" || nl
    currentX = currentX + colWidthsArray[c]
  end

  currentY = currentY - rowHeight

  /* ----------------------------------------------------------------- */
  /* 2. DRAW DATA ROWS WITH ALTERNATING BACKGROUNDS                    */
  /* ----------------------------------------------------------------- */
  streamData = streamData || "0 0 0 rg" || nl /* Reset text color to black */

  do r = 1 to numRows
    currentRowData = matrixRowsArray[r]

    /* Alternate background color fills every other row */
    if r // 2 == 1 then do
      streamData = streamData || "0.95 0.97 1.0 rg" || nl /* Very soft blue-tint */
    end
    else do
      streamData = streamData || "1 1 1 rg" || nl         /* Pure solid white */
    end
    streamData = streamData || startX (currentY - rowHeight) totalWidth rowHeight "re f" || nl

    /* Render row cell data values */
    streamData = streamData || "0 0 0 rg" || nl
    currentX = startX
    do c = 1 to numCols
      textX = currentX + 6
      textY = currentY - rowHeight + 5
      escapedText = self~escapePDFString(currentRowData[c])
      streamData = streamData || "BT" || nl || textX textY "Td ("escapedText") Tj" || nl || "ET" || nl
      currentX = currentX + colWidthsArray[c]
    end

    currentY = currentY - rowHeight
  end

  /* ----------------------------------------------------------------- */
  /* 3. OVERLAY GRID FRAME BORDER LINES                                */
  /* ----------------------------------------------------------------- */
  streamData = streamData || "0.5 w 0.7 0.7 0.7 RG" || nl /* Subtle grey borders */
  tableTotalHeight = rowHeight * (numRows + 1)
  bottomY = startY - tableTotalHeight

  /* Draw horizontal dividing border segments */
  do r = 0 to numRows + 1
    lineY = startY - (r * rowHeight)
    streamData = streamData || startX lineY "m" (startX + totalWidth) lineY "l S" || nl
  end

  /* Draw vertical dividing column border segments */
  currentX = startX
  streamData = streamData || currentX startY "m" currentX bottomY "l S" || nl
  do c = 1 to numCols
    currentX = currentX + colWidthsArray[c]
    streamData = streamData || currentX startY "m" currentX bottomY "l S" || nl
  end

  return

::method writeMultiColumnText public
  expose streamData nl
  /* use arg strictly preserves our structural object references */
  use arg startY, bottomMargin, colWidth, colGap, colXArray, lineHeight, longTextString

  numCols = colXArray~items()
  currentColIdx = 1

  /* Set initial text cursor position to the first column */
  currentX = colXArray[currentColIdx]
  currentY = startY

  streamData = streamData || "BT" || nl || currentX currentY "Td" || nl

  currentLineWidth = 0
  currentLineText  = ""

  /* Word-tokenization loop */
  do while longTextString \= ""
    parse var longTextString nextWord longTextString

    /* Approximation metric: assuming average character width of 6 points for 12pt font */
    wordWidth = length(nextWord) * 6

    /* Case A: Word fits on the current line */
    if currentLineWidth + wordWidth <= colWidth then do
      currentLineText = currentLineText || nextWord " "
      currentLineWidth = currentLineWidth + wordWidth + 6
    end
    /* Case B: Line is full, must push down or wrap to next column */
    else do
      /* Flush the completed line out to the PDF stream layer */
      escapedText = self~escapePDFString(strip(currentLineText))
      streamData = streamData || "("escapedText") Tj" || nl

      /* Advance vertical text cursor downward */
      nextY = currentY - lineHeight

      /* Check for column overflow boundary */
      if nextY < bottomMargin then do
        /* Move to the next column if available */
        if currentColIdx < numCols then do
          currentColIdx = currentColIdx + 1
          oldX = colXArray[currentColIdx - 1]
          newX = colXArray[currentColIdx]

          /* Calculate relative text matrix coordinate shifts */
          shiftX = newX - oldX
          shiftY = startY - currentY

          streamData = streamData || shiftX shiftY "Td" || nl
          currentY = startY
        end
        else do
          /* All columns on this page are exhausted */
          /* Flush remaining unparsed words back to indicate layout overflow */
          longTextString = nextWord longTextString
          leave
        end
      end
      else do
        /* Stay in same column, just move down to the next line line */
        streamData = streamData || "0 -"lineHeight "Td" || nl
        currentY = nextY
      end

      /* Initialize the next line with our wrapped word */
      currentLineText = nextWord " "
      currentLineWidth = wordWidth + 6
    end
  end

  /* Flush any remaining trailing text string snippet */
  if strip(currentLineText) \= "" then do
    escapedText = self~escapePDFString(strip(currentLineText))
    streamData = streamData || "("escapedText") Tj" || nl
  end

  streamData = streamData || "ET" || nl

  /* Return any leftover text that didn't fit on this page */
  return longTextString



::method escapePDFString private
  use arg txt
  out = ""
  len = length(txt)
  do i = 1 to len
    c = substr(txt, i, 1)
    /* Strict character escaping protection for target delimiter arrays */
    if c == "(" | c == ")" | c == "\" then out = out || "\" || c
    else out = out || c
  end
  return out

::method getRawStream public
  expose streamData
  return streamData

/* ========================================================================= */

::class Canvas public
::method init
  expose commands nl
  commands = ""
  nl = "0A"x

::method setStrokeColor public
  expose commands nl
  use arg r, g, b
  commands = commands || r g b "RG" || nl

::method setFillColor public
  expose commands nl
  use arg r, g, b
  commands = commands || r g b "rg" || nl

::method setLineWidth public
  expose commands nl
  use arg pointsWidth
  commands = commands || pointsWidth "w" || nl

::method drawLine public
  expose commands nl
  use arg x1, y1, x2, y2
  commands = commands || x1 y1 "m" x2 y2 "l S" || nl

::method drawRectangle public
  expose commands nl
  use arg x, y, width, height, fillType
  op = "S"
  if fillType == "fill" then op = "f"
  if fillType == "both" then op = "B"
  commands = commands || x y width height "re" op || nl

::method drawCircle public
  expose commands nl
  use arg cx, cy, r, fillType
  k = r * 0.552284749831
  op = "S"
  if fillType == "fill" then op = "f"
  if fillType == "both" then op = "B"

  commands = commands || (cx + r) cy "m" || ,
    (cx + r) (cy + k) (cx + k) (cy + r) cx (cy + r) "c" || nl || ,
    (cx - k) (cy + r) (cx - r) (cy + k) (cx - r) cy "c" || nl || ,
    (cx - r) (cy - k) (cx - k) (cy - r) cx (cy - r) "c" || nl || ,
    (cx + k) (cy - r) (cx + r) (cy - k) (cx + r) cy "c h" op || nl

/* Draws an explicitly shaded container box card structure */
::method drawShadedBox public
  expose commands nl
  use arg x, y, width, height, strokeR, strokeG, strokeB, fillR, fillG, fillB, lineWidth, fillType

  /* Set background shading color parameters */
  commands = commands || fillR fillG fillB "rg" || nl

  /* Set boundary line stroke color parameters */
  commands = commands || strokeR strokeG strokeB "RG" || nl
  commands = commands || lineWidth "w" || nl

  /* Map path execution type: 'fill' (f), 'stroke' (S), or 'both' (B) */
  op = "B"
  if fillType == "fill" then op = "f"
  if fillType == "stroke" then op = "S"

  commands = commands || x y width height "re" op || nl
  return

/* Draws a shaded circle node using our Bézier approximations */
::method drawShadedCircle public
  expose commands nl
  use arg cx, cy, r, strokeR, strokeG, strokeB, fillR, fillG, fillB, lineWidth, fillType

  commands = commands || fillR fillG fillB "rg" || nl
  commands = commands || strokeR strokeG strokeB "RG" || nl
  commands = commands || lineWidth "w" || nl

  k = r * 0.552284749831
  op = "B"
  if fillType == "fill" then op = "f"
  if fillType == "stroke" then op = "S"

  commands = commands || (cx + r) cy "m" || ,
    (cx + r) (cy + k) (cx + k) (cy + r) cx (cy + r) "c" || nl || ,
    (cx - k) (cy + r) (cx - r) (cy + k) (cx - r) cy "c" || nl || ,
    (cx - r) (cy - k) (cx - k) (cy - r) cx (cy - r) "c" || nl || ,
    (cx + k) (cy - r) (cx + r) (cy - k) (cx + r) cy "c h" op || nl
  return

/* Draws a smooth horizontal or vertical linear gradient box using LERP slicing */
::method drawLinearGradient public
  expose commands nl
  /* use arg strictly protects our floating point decimal numbers */
  use arg x, y, width, height, startR, startG, startB, endR, endG, endB

  /* We set our slice thickness to 1.5 points for a perfect balance between */
  /* rendering smoothness and stream file efficiency.                      */
  sliceHeight = 1.5
  steps = height / sliceHeight

  /* Retain previous stroke/fill states to avoid messing up other elements */
  commands = commands || "0.5 w" || nl

  currentY = y

  do i = 0 to steps - 1
    /* Compute Linear Interpolation (LERP) ratio between 0.0 and 1.0 */
    ratio = i / (steps - 1)

    /* Calculate the precise color intersection step */
    r = startR + (ratio * (endR - startR))
    g = startG + (ratio * (endG - startG))
    b = startB + (ratio * (endB - startB))

    /* Round to 3 decimal places to keep the PDF stream file size tight */
    r = format(r, , 3)
    g = format(g, , 3)
    b = format(b, , 3)

    /* Set color and fill this tiny thin slice strip */
    commands = commands || r g b "rg" || nl
    commands = commands || x currentY width sliceHeight "re f" || nl

    /* Step down vertically for a top-to-bottom gradient blend */
    currentY = currentY - sliceHeight
  end
  return


::method getCommands public
  expose commands
  return commands
