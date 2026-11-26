/* ColumnDisplay.cls -- fixed-width column output for reports (cloudctl machines, accounts, ...).
 *
 * Architecture: Tom Dyer.  Original class: Gemini (Google), supplied by Tom, 7 Nov 2026.
 * Fixes and tests: Claude (Opus 5.5).  Seven of the eight faults below ran without an error; only the first one crashed.
 *
 * Faults found in the original, and what this version does instead:
 *   1. char~copied(...)        no such method (Error 97 on the first separator)       -> copies
 *   2. i <= items~items        items counts filled slots, not positions: in
 *                              .array~of('P1005', , '9.99') the price is dropped     -> items[i] (.nil past the end)
 *   3. number~right(width)     cuts the leading digits off a wide number:
 *                              1234567.89 in 6 prints 567.89                          -> '******' (never a wrong value)
 *   4. text~left(width)        cuts text silently                                     -> last kept character becomes '~'
 *   5. no gap between columns  a full-width name runs into the price                  -> gap (default 1 space)
 *   6. items[i] \== .nil       compares text: a cell reading "The NIL object" counted
 *                              as missing                                             -> ~isNil
 *   7. use arg char            printSeparator() with no argument prints CHARCHAR...  -> use strict arg char='-'
 *   8. & in the number test    house rule: comma form; widths are checked on init    -> rules up front
 */
::class ColumnDisplay public
::attribute widths     get
::attribute gap        get
::attribute totalWidth get
::method init
  expose widths gap totalWidth
  use strict arg widths, gap=1
  if \gap~datatype('W') then raise syntax 40.900 array('ColumnDisplay: gap' gap 'is not a whole number')
  totalWidth=0
  do w over widths
    if \w~datatype('W') then raise syntax 40.900 array('ColumnDisplay: width' w 'is not a whole number')
    if w<1 then raise syntax 40.900 array('ColumnDisplay: width' w 'is below 1')
    totalWidth=totalWidth+w
  end
  if widths~items>1 then totalWidth=totalWidth+gap*(widths~items-1)
/* The text of cell i: '' when the slot is empty, .nil or past the end of the row. */
::method cell
  use strict arg row, i
  v=row[i]
  if v~isNil then return ''
  return v~string
/* One cell fitted to its width: numbers right-aligned and never cut, text left-aligned and cut visibly. */
::method fit
  use strict arg text, width
  if text<>'', text~datatype('N') then do
    if text~length>width then return '*'~copies(width)
    return text~right(width)
  end
  if text~length>width then return text~left(width-1)'~'
  return text~left(width)
::method format
  expose widths gap
  use strict arg row
  cells=.array~new
  do i=1 to widths~items
    cells~append(self~fit(self~cell(row, i), widths[i]))
  end
  return cells~makeString('L', ' '~copies(gap))~strip('T')
::method printRow
  use strict arg row
  say self~format(row)
::method separator
  expose totalWidth
  use strict arg char='-'
  if char=='' then char='-'
  return char~left(1)~copies(totalWidth)
::method printSeparator
  use strict arg char='-'
  say self~separator(char)
