/* Qualification fixture exposing the exact dev10 provider-side constructor
 * shapes consumed by ImapSmtpDeliveredStore.cls. */
::class ImapServerResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::method init
  expose ok code detail value
  use strict arg okArg,codeArg,detailArg="",valueArg=.nil
  ok=(okArg==.true); code=codeArg~string~upper; detail=detailArg~string; value=valueArg
::method success class
  use strict arg value=.nil,detail=""
  return self~new(.true,"OK",detail,value)
::method failure class
  use strict arg code,detail="",value=.nil
  return self~new(.false,code,detail,value)
::class ImapServerNamespace public
::attribute personalPrefix get
::attribute delimiter get
::method init
  expose personalPrefix delimiter
  use strict arg prefixArg="",delimiterArg="/"
  personalPrefix=prefixArg~string; delimiter=delimiterArg~string
::class ImapServerMailboxDescriptor public
::attribute name get
::attribute delimiter get
::attribute attributes get
::attribute role get
::attribute deliveryManaged get
::attribute subscribed get
::method init
  expose name delimiter attributes role deliveryManaged subscribed
  use strict arg nameArg,delimiterArg="/",attributesArg="",roleArg="ORDINARY",managedArg=.false,subscribedArg=.false
  name=nameArg~string; delimiter=delimiterArg~string; attributes=attributesArg~string; role=roleArg~string~upper
  deliveryManaged=(managedArg==.true); subscribed=(subscribedArg==.true)
::class ImapServerMailboxSnapshot public
::attribute mailbox get
::attribute messageCount get
::attribute recent get
::attribute unseenCount get
::attribute firstUnseenSequence get
::attribute uidValidity get
::attribute uidNext get
::attribute highestModSeq get
::attribute generation get
::attribute readOnly get
::attribute flags get
::attribute permanentFlags get
::method init
  expose mailbox messageCount recent unseenCount firstUnseenSequence uidValidity uidNext highestModSeq generation readOnly flags permanentFlags
  use strict arg mailboxArg,messageCountArg=0,recentArg=0,unseenArg=0,firstUnseenArg=0,uidValidityArg="1",uidNextArg="1",modseqArg="1",generationArg="1",readOnlyArg=.false,flagsArg="\\Answered \\Flagged \\Deleted \\Seen \\Draft",permanentArg="\\Answered \\Flagged \\Deleted \\Seen \\Draft"
  mailbox=mailboxArg~string; messageCount=messageCountArg+0; recent=recentArg+0; unseenCount=unseenArg+0; firstUnseenSequence=firstUnseenArg+0
  uidValidity=uidValidityArg~string; uidNext=uidNextArg~string; highestModSeq=modseqArg~string; generation=generationArg~string; readOnly=(readOnlyArg==.true); flags=flagsArg; permanentFlags=permanentArg
::class ImapMailboxProvider public
::method capabilities; return .array~new
