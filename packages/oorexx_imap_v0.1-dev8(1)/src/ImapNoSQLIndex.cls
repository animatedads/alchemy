/* NoSQLServer-backed IMAP catalogue and inverted full-text projection.
 *
 * NoSQLServer tables are local derived state, never mailbox authority.  A
 * partially rebuilt message remains BUILDING and is excluded from searches.
 * This gives fail-closed search visibility without pretending the index is an
 * immutable copy of remote mail.
 */

::class ImapNoSQLIndex public
::attribute root get
::attribute database get
::attribute maximumTermsPerMessage
::method init
  expose root database sql maximumTermsPerMessage
  use strict arg rootArg
  root=rootArg~string~strip
  if root="" then raise syntax 88.900 array("IMAP_NOSQL_ROOT_REQUIRED")
  call SysMkDir root
  database=.FileDatabaseEngine~new(root)
  sql=.NoSQLServerSQL~new(database)
  maximumTermsPerMessage=20000
  self~ensureSchema
::method ensureSchema
  expose database sql
  if database~table("imap_messages")==.nil then ignore=self~must(sql~execute("CREATE TABLE imap_messages (message_key VARCHAR PRIMARY KEY, account_key VARCHAR, mailbox VARCHAR, uidvalidity INTEGER, uid INTEGER, internal_date VARCHAR, from_address VARCHAR, from_key VARCHAR, subject VARCHAR, message_id VARCHAR, flags VARCHAR, size_bytes INTEGER, body_indexed INTEGER, index_complete INTEGER, index_truncated INTEGER, display_name VARCHAR)"), "create imap_messages")
  if database~table("imap_terms")==.nil then ignore=self~must(sql~execute("CREATE TABLE imap_terms (term_key VARCHAR PRIMARY KEY, token VARCHAR, message_key VARCHAR, source VARCHAR)"), "create imap_terms")
  if database~table("imap_mailboxes")==.nil then ignore=self~must(sql~execute("CREATE TABLE imap_mailboxes (mailbox_key VARCHAR PRIMARY KEY, account_key VARCHAR, mailbox VARCHAR, uidvalidity INTEGER, uidnext INTEGER, highestmodseq VARCHAR, metadata_complete INTEGER, last_seen_uid INTEGER, body_indexed_uid INTEGER, updated_at VARCHAR)"), "create imap_mailboxes")
  return self
::method indexMessage
  expose database maximumTermsPerMessage
  use strict arg record, bodyText=.nil
  if record==.nil then raise syntax 88.900 array("IMAP_NOSQL_RECORD_REQUIRED")
  key=record~key
  existing=database~selectWhereEquals("imap_messages","message_key",key)
  if existing~rows~items=0 then do
    row=self~messageRow(record,0,0,0)
    ignore=self~must(database~insert("imap_messages",row), "insert BUILDING message")
  end
  else do
    changes=self~messageAssignments(record,0,0,0)
    ignore=self~must(database~updateWhereEquals("imap_messages","message_key",key,changes), "mark message BUILDING")
  end
  /* Stale terms are harmless while index_complete=0, but remove them before
   * publishing the replacement projection. */
  ignore=self~must(database~deleteWhereEquals("imap_terms","message_key",key), "remove old terms")

  terms=.array~new
  count=0
  count+=self~appendTerms(terms,key,"SUBJECT",record~subject,maximumTermsPerMessage-count)
  if count<maximumTermsPerMessage then count+=self~appendTerms(terms,key,"FROM",record~fromAddress,maximumTermsPerMessage-count)
  if count<maximumTermsPerMessage then count+=self~appendTerms(terms,key,"MESSAGE_ID",record~messageId,maximumTermsPerMessage-count)
  bodyIndexed=0
  if bodyText<>.nil & count<maximumTermsPerMessage then do
    count+=self~appendTerms(terms,key,"BODY",bodyText,maximumTermsPerMessage-count)
    bodyIndexed=1
  end
  if terms~items>0 then ignore=self~must(database~insertMany("imap_terms",terms), "insert message terms")
  truncated=0; if count>=maximumTermsPerMessage then truncated=1
  changes=self~messageAssignments(record,bodyIndexed,1,truncated)
  ignore=self~must(database~updateWhereEquals("imap_messages","message_key",key,changes), "publish indexed message")
  return key
::method removeMessage
  expose database
  use strict arg messageKeyArg
  key=messageKeyArg~string
  ignore=self~must(database~deleteWhereEquals("imap_terms","message_key",key), "remove message terms")
  ignore=self~must(database~deleteWhereEquals("imap_messages","message_key",key), "remove message")
  return .true
::method searchFrom
  expose database
  use strict arg addressArg, limitArg=100, accountArg="", mailboxArg=""
  wanted=.ImapIndexText~addressKey(addressArg)
  limit=self~checkedLimit(limitArg)
  rows=database~selectWhereEquals("imap_messages","from_key",wanted)
  return self~messageRowsToResult("from:"||wanted,.array~of(wanted),rows~rows,limit,accountArg,mailboxArg)
::method searchText
  expose database
  use strict arg queryArg, limitArg=100, accountArg="", mailboxArg=""
  limit=self~checkedLimit(limitArg)
  terms=.ImapIndexText~tokens(queryArg)
  if terms~items=0 then return .ImapIndexSearchResult~new(queryArg,terms,.array~new,.false,.false)
  candidates=.directory~new
  first=.true
  do token over terms
    rs=database~selectWhereEquals("imap_terms","token",token)
    present=.directory~new
    do row over rs~rows
      present[row["message_key"]]=.true
    end
    if first then do
      do key over present; candidates[key]=.true; end
      first=.false
    end
    else do
      gone=.array~new
      do key over candidates
        if present[key]==.nil then gone~append(key)
      end
      do key over gone; candidates~remove(key); end
    end
    if candidates~items=0 then leave
  end
  hits=.array~new
  truncated=.false
  bodyComplete=.true
  do key over candidates
    rs=database~selectWhereEquals("imap_messages","message_key",key)
    if rs~rows~items=0 then iterate
    row=rs~rows[1]
    if row["index_complete"]<>"1" & row["index_complete"]<>1 then iterate
    if accountArg<>"" then if row["account_key"]<>accountArg then iterate
    if mailboxArg<>"" then if row["mailbox"]<>mailboxArg then iterate
    if row["body_indexed"]<>"1" & row["body_indexed"]<>1 then bodyComplete=.false
    if row["index_truncated"]="1" | row["index_truncated"]=1 then bodyComplete=.false
    if hits~items>=limit then do; truncated=.true; leave; end
    hits~append(self~recordFromRow(row))
  end
  return .ImapIndexSearchResult~new(queryArg,terms,hits,truncated,bodyComplete)
::method checkpointMailbox
  expose database
  use strict arg accountArg, mailboxArg, uidValidityArg, uidNextArg=0, highestModSeqArg="", metadataCompleteArg=.false, lastSeenUidArg=0, bodyIndexedUidArg=0, updatedAtArg=""
  key=.ImapIndexIdentity~mailboxKey(accountArg,mailboxArg)
  row=.table~new
  row["mailbox_key"]=key; row["account_key"]=accountArg; row["mailbox"]=mailboxArg
  row["uidvalidity"]=uidValidityArg+0; row["uidnext"]=uidNextArg+0; row["highestmodseq"]=highestModSeqArg~string
  if metadataCompleteArg==.true then row["metadata_complete"]=1; else row["metadata_complete"]=0
  row["last_seen_uid"]=lastSeenUidArg+0; row["body_indexed_uid"]=bodyIndexedUidArg+0; row["updated_at"]=updatedAtArg~string
  rs=database~selectWhereEquals("imap_mailboxes","mailbox_key",key)
  if rs~rows~items=0 then ignore=self~must(database~insert("imap_mailboxes",row), "insert mailbox checkpoint")
  else do
    changes=row~copy; changes~remove("mailbox_key")
    ignore=self~must(database~updateWhereEquals("imap_mailboxes","mailbox_key",key,changes), "update mailbox checkpoint")
  end
  return key
::method mailboxCheckpoint
  expose database
  use strict arg accountArg, mailboxArg
  key=.ImapIndexIdentity~mailboxKey(accountArg,mailboxArg)
  rs=database~selectWhereEquals("imap_mailboxes","mailbox_key",key)
  if rs~rows~items=0 then return .nil
  return rs~rows[1]
::method buildSearchIndexes
  expose database
  specs=.array~of(.array~of("imap_terms","token"),.array~of("imap_terms","message_key"),.array~of("imap_messages","from_key"),.array~of("imap_messages","mailbox"),.array~of("imap_messages","account_key"))
  built=.array~new
  do spec over specs
    msg=database~startIndexBuild(spec[1],spec[2])
    if msg==.nil then iterate
    msg~wait
    if msg~errorCondition<>.nil then raise syntax 88.900 array("IMAP_NOSQL_INDEX_BUILD_FAILED",spec[1],spec[2])
    if msg~result<>.nil then built~append(msg~result)
  end
  return built
::method messageRow private
  use strict arg record, bodyIndexed, complete, truncated
  row=self~messageAssignments(record,bodyIndexed,complete,truncated)
  row["message_key"]=record~key
  return row
::method messageAssignments private
  use strict arg record, bodyIndexed, complete, truncated
  row=.table~new
  row["account_key"]=record~accountKey; row["mailbox"]=record~mailbox
  row["uidvalidity"]=record~uidValidity+0; row["uid"]=record~uid+0
  row["internal_date"]=record~internalDate; row["from_address"]=record~fromAddress; row["from_key"]=record~fromKey
  row["subject"]=record~subject; row["message_id"]=record~messageId; row["flags"]=record~flags; row["size_bytes"]=record~sizeBytes+0
  row["body_indexed"]=bodyIndexed+0; row["index_complete"]=complete+0; row["index_truncated"]=truncated+0
  row["display_name"]="IDX"||record~uid||" "||record~subject||" <"||record~fromAddress||">"
  return row
::method appendTerms private
  use strict arg out, messageKey, source, text, remaining
  if remaining<1 then return 0
  tokens=.ImapIndexText~tokens(text,2,128,remaining)
  added=0
  do token over tokens
    row=.table~new
    row["term_key"]=messageKey||"|"||source||"|"||token
    row["token"]=token; row["message_key"]=messageKey; row["source"]=source
    out~append(row); added+=1
  end
  return added
::method recordFromRow private
  use strict arg row
  return .ImapIndexRecord~new(row["account_key"],row["mailbox"],row["uidvalidity"],row["uid"],row["size_bytes"],row["subject"],row["from_address"],row["internal_date"],row["flags"],row["message_id"])
::method messageRowsToResult private
  use strict arg query, terms, rows, limit, accountArg, mailboxArg
  hits=.array~new; truncated=.false; bodyComplete=.true
  do row over rows
    if row["index_complete"]<>"1" & row["index_complete"]<>1 then iterate
    if accountArg<>"" then if row["account_key"]<>accountArg then iterate
    if mailboxArg<>"" then if row["mailbox"]<>mailboxArg then iterate
    if row["body_indexed"]<>"1" & row["body_indexed"]<>1 then bodyComplete=.false
    if row["index_truncated"]="1" | row["index_truncated"]=1 then bodyComplete=.false
    if hits~items>=limit then do; truncated=.true; leave; end
    hits~append(self~recordFromRow(row))
  end
  return .ImapIndexSearchResult~new(query,terms,hits,truncated,bodyComplete)
::method checkedLimit private
  use strict arg value
  n=value+0
  if n<1 | n>10000 then raise syntax 88.900 array("IMAP_NOSQL_SEARCH_LIMIT_INVALID",value)
  return n
::method must private
  use strict arg result, context
  if result==.nil then raise syntax 88.900 array("IMAP_NOSQL_OPERATION_FAILED",context,"nil result")
  if result~status<>.Error~SUCCESS then raise syntax 88.900 array("IMAP_NOSQL_OPERATION_FAILED",context,result~status,result~message)
  return result

::requires "ImapIndexCore.cls"
::requires "NoSQLServer.cls"
