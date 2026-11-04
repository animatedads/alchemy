/* Screenshot cyan class 80x45 -- never an admitted camera water mask. */
numeric digits 18
parse arg maskFile
if maskFile=='' then exit 2
source='sha256:97ff5a02e63f6a9b72b44cd3e13d4a879f60d56bd3be38f07b11162ef6008d6b'
if stream(maskFile,'c','query exists')=='' then call bad 'missing mask'
call stream maskFile,'c','open read'
if linein(maskFile)\=='row|cyan_class_bits|source_ref|coordinate_system|evidence_state' then call bad 'schema'
count=0;positive=0
 do while lines(maskFile)>0
  row=linein(maskFile)
  parse var row y '|' bits '|' ref '|' space '|' authority
  if \datatype(y,'W') | y<>count then call bad 'row order'
  if length(bits)<>80 | verify(bits,'01')<>0 then call bad 'binary row width'
  if ref\==source then call bad 'source hash'
  if space\=='SCREEN_RASTER_UNREGISTERED' | authority\=='CLASS_SEMANTICS_UNVERIFIED' then call bad 'unapproved registration'
  do i=1 to 80
   if substr(bits,i,1)=='1' then positive=positive+1
  end
  count=count+1
 end
call stream maskFile,'c','close'
if count<>45 then call bad 'missing rows'
if positive<>1650 then call bad 'mask class count unexpected'
say 'MASK80_SOURCE_LINEAGE_PASS rows='count 'cyan_cells='positive 'CAMERA_REGISTRATION=BLOCKED'
exit 0
bad: procedure
 use arg why
 say 'MASK80_SOURCE_LINEAGE_REJECT:'why
 exit 3
