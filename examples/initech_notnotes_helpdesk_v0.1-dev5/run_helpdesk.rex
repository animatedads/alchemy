parse source . . here
root=filespec("L",here)
if right(root,1)="/" then root=left(root,length(root)-1)
call value "REXX_PATH", root||"/src:"||root||"/deps/notnotes_app/src:"||root||"/deps/notnotes_app/vendor/notnotes:"||root||"/deps/notnotes_app/vendor/nosql:"||root||"/deps/notnotes_app/vendor/pdf/src:"||root||"/deps/notnotes_app/vendor/cliui/rexx:"||root||"/deps/notnotes_intentions:"||root||"/deps/intention_service/src:"||root||"/deps/intention_service/src/nlp:"||value("REXX_PATH",,"ENVIRONMENT"), "ENVIRONMENT"
actor=value("INITECH_USER",,"ENVIRONMENT"); if actor="" then actor="codex"
dataRoot=value("INITECH_DATA_ROOT",,"ENVIRONMENT"); if dataRoot="" then dataRoot=root||"/data/mininotes"
session=.InitechHelpDeskSession~new(dataRoot,actor)
say "Initech TPS Help Desk. User:" actor
say "Ask for TPS reports, TPS review reports, or 'log business ...'. Type DONE to finish."
do forever
  call charout , "> "
  line=linein()
  if line==.nil then leave
  response=session~handle(line)
  say response["TEXT"]
  if response["STATUS"]="CLOSED" then exit 0
end
closeResult=session~close
say "Session TPS report:" closeResult["TPS_KEY"] "review:" closeResult["REVIEW_KEY"] "rating:" closeResult["RATING"]
exit 0
::requires "InitechHelpDesk.cls"
