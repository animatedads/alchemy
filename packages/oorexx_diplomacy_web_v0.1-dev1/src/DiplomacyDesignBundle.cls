/* Equal-source release. Construct once at game admission, then use exactly
   the same immutable byte string for every designer. No user-supplied paths. */
::class DiplomacyDesignBundle public
::attribute bytes get
::attribute digest get
::method init
  expose bytes digest
  use strict arg engineRoot, manifest
  bytes='DIPLOMACY-DESIGN-SOURCE/1'||'0a'x
  seen=.set~new
  input=.stream~new(manifest)
  if input~open('READ')\=='READY:' then raise syntax 93.900 array('Missing trusted source manifest')
  do while input~lines>0
    parse value input~linein with hash member
    member=member~strip
    if member='' then iterate
    if hash~length\=64 | \hash~datatype('X') | member~pos('..')>0 | member~left(2)\=='./' then raise syntax 93.900 array('Bad manifest entry')
    if member~left(6)\=='./src/' & member~left(7)\=='./data/' then raise syntax 93.900 array('Unexpected bundle file')
    if seen~hasIndex(member) then raise syntax 93.900 array('Duplicate bundle member')
    seen~put(member)
    f=.stream~new(engineRoot'/'member)
    if f~open('READ')\=='READY:' then raise syntax 93.900 array('Missing source member')
    size=f~query('SIZE')
    if size>1000000 then raise syntax 93.900 array('Oversize source member')
    content=f~charin(1,size)
    f~close
    if .SHA256~new(content)~digest~upper\==hash~upper then raise syntax 93.900 array('Source hash mismatch:' member)
    bytes||='FILE|'member'|'size'|'hash||'0a'x||content||'0a'x
  end
  input~close
  if \seen~hasIndex('./data/rules.conf') | \seen~hasIndex('./src/DiplomacyGame.cls') then raise syntax 93.900 array('Incomplete source bundle')
  digest=.SHA512~new(bytes)~digest
::requires 'crypto.cls'
