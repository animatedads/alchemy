/* Normalize a complete retained s3270 ReadBuffer(Ascii) action response.
 * This tool is read-only and never connects to or mutates a host.
 *
 * Usage:
 *   rexx s3270_differential_compare.rex readbuffer-response.txt
 *
 * The response must contain data: lines, the 12-field s3270 status line and the
 * final ok/error completion line. Dimensions, cursor and keyboard state are
 * therefore derived from the same reference response rather than separate args.
 */
parse arg readFile
if readFile=="" then do
  say "usage: rexx s3270_differential_compare.rex readbuffer-response.txt"
  exit 2
end
if stream(readFile,"c","query exists")=="" then do; say "FAIL response missing:" readFile; exit 2; end
raw=charin(readFile,1,chars(readFile)); call stream readFile,"c","close"
ref=.S3270ReferenceParser~parseActionResponse(raw)
if \ref~ok then do; say "FAIL reference parse" ref~code ref~detail; exit 1; end
s=ref~value
say "S3270_REFERENCE rows="s~rows "cols="s~columns "cursor="s~cursorRow||","||s~cursorColumn "keyboard="s~keyboardState "fields="s~fields~items
if s~status\==.nil then say "STATUS mode="s~status~emulatorMode "connection="s~status~connectionState "model="s~status~modelNumber "formatted="s~status~formatted
do f over s~fields
  say "FIELD" "A"||right(d2x(f~address),4,"0") "r"||f~row||"c"||f~column "len="||f~length "protected="||f~protected "numeric="||f~numeric "mdt="||f~modified "nondisplay="||f~nonDisplay
end
say "VISIBLE_BEGIN"
do r=1 to s~rows; say s~rowText(r); end
say "VISIBLE_END"
exit 0
::requires "S3270Reference.cls"
