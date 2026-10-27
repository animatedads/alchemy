/* Normalize retained s3270 ReadBuffer(Ascii) evidence for differential work.
 * This tool is read-only and never connects to or mutates a host.
 *
 * Usage:
 *   rexx s3270_differential_compare.rex readbuffer.txt rows cols cursorRow0 cursorCol0
 *
 * The cursor coordinates use s3270's documented zero-origin convention.
 */
parse arg readFile rows cols cursorRow0 cursorCol0
if readFile=="" then do
  say "usage: rexx s3270_differential_compare.rex readbuffer.txt rows cols cursorRow0 cursorCol0"
  exit 2
end
if stream(readFile,"c","query exists")=="" then do; say "FAIL readbuffer missing:" readFile; exit 2; end
raw=charin(readFile,1,chars(readFile)); call stream readFile,"c","close"
ref=.S3270ReferenceParser~parse(raw,rows,cols,cursorRow0,cursorCol0)
if \ref~ok then do; say "FAIL reference parse" ref~code ref~detail; exit 1; end
s=ref~value
say "S3270_REFERENCE rows="s~rows "cols="s~columns "cursor="s~cursorRow||","||s~cursorColumn "fields="s~fields~items
do f over s~fields
  say "FIELD" "A"||right(d2x(f~address),4,"0") "r"||f~row||"c"||f~column "len="||f~length "protected="||f~protected "numeric="||f~numeric "mdt="||f~modified "nondisplay="||f~nonDisplay
end
say "VISIBLE_BEGIN"
do r=1 to s~rows; say s~rowText(r); end
say "VISIBLE_END"
exit 0
::requires "S3270Reference.cls"
