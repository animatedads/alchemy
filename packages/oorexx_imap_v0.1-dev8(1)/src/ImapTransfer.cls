/* ooRexx IMAP v0.1-dev8 transfer/move semantics.
 *
 * This module deliberately separates three operations that are often blurred:
 *   1. server-native UID MOVE;
 *   2. same-server COPY + exact source removal;
 *   3. cross-server APPEND, verify, then explicit source-removal COMMIT.
 *
 * It never issues plain EXPUNGE as a fallback because that can expunge unrelated
 * messages which were already marked \\Deleted by another actor.
 */

::class ImapCopyUidResult public
::attribute commandResult get
::attribute uidValidity get
::attribute sourceUidSet get
::attribute destinationUidSet get
::attribute hasCopyUid get
::attribute mappingCountMatches get
::method init
  expose commandResult uidValidity sourceUidSet destinationUidSet hasCopyUid mappingCountMatches
  use strict arg commandResultArg, uidValidityArg="", sourceArg=.nil, destinationArg=.nil
  commandResult=commandResultArg
  uidValidity=uidValidityArg~string
  sourceUidSet=sourceArg; destinationUidSet=destinationArg
  hasCopyUid=(uidValidity<>"" & sourceUidSet\==.nil & destinationUidSet\==.nil)
  mappingCountMatches=.false
  if hasCopyUid then do
    a=sourceUidSet~count; b=destinationUidSet~count
    mappingCountMatches=(a>=0 & a=b)
  end
::method ok
  expose commandResult
  return commandResult~ok
::method destinationUidFor
  expose sourceUidSet destinationUidSet hasCopyUid mappingCountMatches
  use strict arg sourceUid
  if \hasCopyUid | \mappingCountMatches then return 0
  ordinal=sourceUidSet~ordinalOf(sourceUid)
  if ordinal<1 then return 0
  return destinationUidSet~uidAtOrdinal(ordinal)

::class ImapMovePlan public
::attribute strategy get
::attribute executable get
::attribute completeOnSuccess get
::attribute reason get
::method init
  expose strategy executable completeOnSuccess reason
  use strict arg strategyArg, executableArg, completeArg, reasonArg=""
  strategy=strategyArg~string
  executable=(executableArg==.true)
  completeOnSuccess=(completeArg==.true)
  reason=reasonArg~string

::class ImapSourceRemovalResult public
::attribute strategy get
::attribute markDeletedResult get
::attribute expungeResult get
::attribute markedDeleted get
::attribute sourceRemovalComplete get
::attribute pendingExpunge get
::attribute reason get
::method init
  expose strategy markDeletedResult expungeResult markedDeleted sourceRemovalComplete pendingExpunge reason
  use strict arg strategyArg, markArg=.nil, expungeArg=.nil, markedArg=.false, completeArg=.false, pendingArg=.false, reasonArg=""
  strategy=strategyArg~string; markDeletedResult=markArg; expungeResult=expungeArg
  markedDeleted=(markedArg==.true); sourceRemovalComplete=(completeArg==.true); pendingExpunge=(pendingArg==.true); reason=reasonArg~string
::method ok
  expose sourceRemovalComplete
  return sourceRemovalComplete

::class ImapMoveResult public
::attribute strategy get
::attribute destinationResult get
::attribute sourceRemoval get
::attribute destinationAccepted get
::attribute complete get
::attribute pendingExpunge get
::attribute reason get
::method init
  expose strategy destinationResult sourceRemoval destinationAccepted complete pendingExpunge reason
  use strict arg strategyArg, destinationArg=.nil, removalArg=.nil, acceptedArg=.false, completeArg=.false, pendingArg=.false, reasonArg=""
  strategy=strategyArg~string; destinationResult=destinationArg; sourceRemoval=removalArg
  destinationAccepted=(acceptedArg==.true); complete=(completeArg==.true); pendingExpunge=(pendingArg==.true); reason=reasonArg~string
::method ok
  expose complete
  return complete

::class ImapTransferMetadata public
::attribute uid get
::attribute flags get
::attribute internalDate get
::attribute size get
::method init
  expose uid flags internalDate size
  use strict arg uidArg, flagsArg="", internalDateArg="", sizeArg=0
  uid=uidArg~string; flags=flagsArg~string; internalDate=internalDateArg~string; size=sizeArg+0

::class ImapTransferOps public
::method parseCopyUid class
  use strict arg cmdResult
  uidValidity=""; source=.nil; destination=.nil
  if cmdResult~ok then do
    text=cmdResult~text; upper=text~upper; p=upper~pos("[COPYUID ")
    if p>0 then do
      rest=text~substr(p+9); e=rest~pos("]")
      if e>0 then rest=rest~left(e-1)
      if rest~words>=3 then do
        uv=rest~word(1); src=rest~word(2); dst=rest~word(3)
        if datatype(uv,"W") then do
          uidValidity=uv
          source=.ImapUidSet~parse(src)
          destination=.ImapUidSet~parse(dst)
        end
      end
    end
  end
  return .ImapCopyUidResult~new(cmdResult,uidValidity,source,destination)

::method planSameSessionMove class
  use strict arg session, allowPendingExpunge=.false, preferNative=.true
  if preferNative & session~capabilities~has("MOVE") then return .ImapMovePlan~new("UID_MOVE",.true,.true,"")
  if session~capabilities~has("UIDPLUS") then return .ImapMovePlan~new("UID_COPY_UID_EXPUNGE",.true,.true,"")
  if allowPendingExpunge then return .ImapMovePlan~new("UID_COPY_MARK_DELETED",.true,.false,"PENDING_SAFE_EXPUNGE")
  return .ImapMovePlan~new("BLOCKED",.false,.false,"NO_EXACT_EXPUNGE_CAPABILITY")

::method moveSameSession class
  use strict arg session, uidSet, destinationMailbox, allowPendingExpunge=.false, preferNative=.true, destinationRole=""
  selected=self~requireWritableSelection(session)
  if destinationRole~string~strip="" then raise syntax 88.900 array("IMAP_MOVE_DESTINATION_ROLE_REQUIRED")
  role=.ImapMailboxRole~canonical(destinationRole)
  if role<>"ORDINARY" then raise syntax 88.900 array("IMAP_SPECIAL_USE_MOVE_NOT_AUTHORIZED",role,"use raw UID MOVE/COPY only with explicit server policy")
  if self~sameMailbox(selected~mailbox,destinationMailbox) then raise syntax 88.900 array("IMAP_MOVE_DESTINATION_EQUALS_SOURCE",destinationMailbox)
  plan=self~planSameSessionMove(session,allowPendingExpunge,preferNative)
  if \plan~executable then raise syntax 88.900 array("IMAP_SAFE_MOVE_UNAVAILABLE",plan~reason)

  if plan~strategy="UID_MOVE" then do
    raw=session~uidMove(uidSet,destinationMailbox)
    mapped=self~parseCopyUid(raw)
    return .ImapMoveResult~new("UID_MOVE",mapped,.nil,raw~ok,raw~ok,.false,"")
  end

  rawCopy=session~uidCopy(uidSet,destinationMailbox)
  copied=self~parseCopyUid(rawCopy)
  if \rawCopy~ok then return .ImapMoveResult~new(plan~strategy,copied,.nil,.false,.false,.false,"COPY_FAILED")

  removal=self~commitSourceRemoval(session,uidSet,allowPendingExpunge)
  reason=removal~reason
  return .ImapMoveResult~new(plan~strategy,copied,removal,.true,removal~sourceRemovalComplete,removal~pendingExpunge,reason)

::method commitSourceRemoval class
  use strict arg session, uidSet, allowPendingExpunge=.false
  self~requireWritableSelection(session)
  hasUidPlus=session~capabilities~has("UIDPLUS")
  if \hasUidPlus & \allowPendingExpunge then raise syntax 88.900 array("IMAP_SAFE_EXPUNGE_UNAVAILABLE","UIDPLUS required for exact UID EXPUNGE")

  marked=session~uidMarkDeleted(uidSet)
  if \marked~ok then return .ImapSourceRemovalResult~new("MARK_DELETED_FAILED",marked,.nil,.false,.false,.false,"MARK_DELETED_FAILED")

  if hasUidPlus then do
    expunged=session~uidExpunge(uidSet)
    if expunged~ok then return .ImapSourceRemovalResult~new("UID_EXPUNGE",marked,expunged,.true,.true,.false,"")
    return .ImapSourceRemovalResult~new("UID_EXPUNGE",marked,expunged,.true,.false,.true,"UID_EXPUNGE_FAILED")
  end
  return .ImapSourceRemovalResult~new("MARK_DELETED_ONLY",marked,.nil,.true,.false,.true,"PENDING_SAFE_EXPUNGE")

::method appendableFlags class
  use strict arg flagsArg, preserveDeleted=.false
  flags=flagsArg~string~strip
  if flags="" then return ""
  out=""
  do i=1 to flags~words
    flag=flags~word(i)
    upper=flag~upper
    if upper="\RECENT" then iterate
    if upper="\DELETED" & \preserveDeleted then iterate
    if out<>"" then out=out||" "
    out=out||flag
  end
  return out

::method fetchTransferMetadata class
  use strict arg session, uidSet
  pair=session~uidFetchPeek(uidSet,"UID FLAGS INTERNALDATE RFC822.SIZE")
  if \pair~ok then return .array~of(pair,.nil)
  metadata=self~parseTransferMetadata(pair)
  return .array~of(pair,metadata)

::method parseTransferMetadata class
  use strict arg commandResult
  do record over commandResult~untagged
    line=record~firstLine
    upper=line~upper
    if upper~pos(" FETCH ")=0 then iterate
    uid=self~numberAfter(line,"UID")
    size=self~numberAfter(line,"RFC822.SIZE")
    flags=self~flagsAfter(line)
    internalDate=self~quotedAfter(line,"INTERNALDATE")
    if uid<>"" then return .ImapTransferMetadata~new(uid,flags,internalDate,size)
  end
  return .nil

::method numberAfter class private
  use strict arg line, name
  upper=line~upper; marker=name~upper||" "; p=upper~pos(marker)
  if p=0 then return ""
  rest=line~substr(p+marker~length)~strip
  token=rest~word(1)
  do while token~length>0 & (token~right(1)=")" | token~right(1)="]")
    token=token~left(token~length-1)
  end
  if datatype(token,"W") then return token
  return ""
::method flagsAfter class private
  use strict arg line
  upper=line~upper; marker="FLAGS ("; p=upper~pos(marker)
  if p=0 then return ""
  rest=line~substr(p+marker~length); e=rest~pos(")")
  if e=0 then return ""
  return rest~left(e-1)
::method quotedAfter class private
  use strict arg line, name
  upper=line~upper; marker=name~upper||' "'; p=upper~pos(marker)
  if p=0 then return ""
  rest=line~substr(p+marker~length); e=rest~pos('"')
  if e=0 then return ""
  return rest~left(e-1)
::method sameMailbox class private
  use strict arg aArg,bArg
  a=aArg~string; b=bArg~string
  if a~upper="INBOX" | b~upper="INBOX" then return a~upper=b~upper
  return a==b
::method requireWritableSelection class private
  use strict arg session
  selected=session~selectedState
  if selected==.nil then raise syntax 88.900 array("IMAP_SOURCE_MAILBOX_NOT_SELECTED")
  if selected~readOnly then raise syntax 88.900 array("IMAP_SOURCE_MAILBOX_READ_ONLY",selected~mailbox)
  return selected

::requires "ImapSession.cls"
