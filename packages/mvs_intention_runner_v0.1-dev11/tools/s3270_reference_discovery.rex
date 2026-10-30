/* Normalize retained candidate16 s3270 reference evidence into the
 * MVS Intention provider-neutral feed.  This tool never connects to a host.
 *
 * Usage:
 *   rexx s3270_reference_discovery.rex RESPONSE TARGET HOST LU
 */
parse arg responseFile target host lu
responseFile=responseFile~strip
target=translate(target~strip)
host=host~strip
lu=translate(lu~strip)
if responseFile=="" | target=="" | host=="" | lu=="" then do
  say "ERROR S3270_REFERENCE_ARGUMENTS"
  exit 2
end
if stream(responseFile,"c","query exists")=="" then do
  say "ERROR S3270_REFERENCE_RESPONSE_MISSING"
  exit 2
end

raw=charin(responseFile,1,chars(responseFile))
call stream responseFile,"c","close"
parsed=.S3270ReferenceParser~parseActionResponse(raw)
if \parsed~ok then do
  say "ERROR S3270_REFERENCE_PARSE" parsed~code parsed~detail
  exit 3
end

snap=parsed~value
ref="s3270:"||target||":"||lu||"@"||host
call fact "SESSION","TARGET",target,100,ref
call fact "SESSION","HOST",host,100,ref
call fact "SESSION","LU",lu,100,ref
call fact "SCREEN","ROWS",snap~rows,100,ref
call fact "SCREEN","COLUMNS",snap~columns,100,ref
call fact "CURSOR","ROW",snap~cursorRow,100,ref
call fact "CURSOR","COLUMN",snap~cursorColumn,100,ref
call fact "KEYBOARD","STATE",snap~keyboardState,100,ref
call fact "FIELD","COUNT",snap~fields~items,100,ref
call fact "CHARACTER_ATTRIBUTES","DIGEST",snap~characterAttributeDigest,100,ref
if snap~status\==.nil then do
  call fact "SESSION","MODE",snap~status~emulatorMode,100,ref
  call fact "SESSION","CONNECTION_STATE",snap~status~connectionState,100,ref
  call fact "SESSION","MODEL",snap~status~modelNumber,100,ref
  call fact "SCREEN","FORMATTED",snap~status~formatted,100,ref
end

do f over snap~fields
  id="A"||right(d2x(f~address),4,"0")
  call fact "FIELD."||id,"ROW",f~row,100,ref
  call fact "FIELD."||id,"COLUMN",f~column,100,ref
  call fact "FIELD."||id,"LENGTH",f~length,100,ref
  call fact "FIELD."||id,"PROTECTED",f~protected,100,ref
  call fact "FIELD."||id,"NUMERIC",f~numeric,100,ref
  call fact "FIELD."||id,"MDT",f~modified,100,ref
  call fact "FIELD."||id,"NONDISPLAY",f~nonDisplay,100,ref
  attrs=f~attributes
  do key over .array~of("x41","x42","x43","x45")
    value=attrs~at(key)
    if value\==.nil then call fact "FIELD."||id,translate(key),value,100,ref
  end
end

say "PROBE"||"09"x||"S3270_REFERENCE"||"09"x||"candidate16 detached semantic reference parsed"
exit 0

fact: procedure
  use arg subject,predicate,value,quality,evidence
  say "FACT"||"09"x||subject||"09"x||predicate||"09"x||value||"09"x||quality||"09"x||evidence
  return

::requires "S3270Reference.cls"
