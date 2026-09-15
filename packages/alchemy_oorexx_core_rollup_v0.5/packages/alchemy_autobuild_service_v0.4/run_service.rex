parse arg line
repo=""; poll=5; once=.false
do i=1 to words(line)
  token=word(line,i)
  select
    when token~left(7)="--repo=" then repo=token~substr(8)
    when token~left(7)="--poll=" then poll=token~substr(8)+0
    when token="--once" then once=.true
    otherwise do; say "ERROR unknown argument:" token; exit 2; end
  end
end
if repo="" then do; say "usage: rexx run_service.rex --repo=PATH [--poll=SECONDS] [--once]"; exit 2; end
service=.AlchemyAutobuildService~new(repo,poll)
if once then do
  cycle=service~runOnce
  say "DISCOVERED=" || cycle~discovered
  say "PROCESSED=" || cycle~processed
  do item over cycle~results
    say item~submissionId item~status
  end
  exit 0
end
say "Alchemy ooRexx Autobuild Service v" || .AlchemyAutobuildServiceBuild~VERSION
say "REPO=" || repo
say "POLL_SECONDS=" || poll
service~runForever
exit 0
::requires "AlchemyAutobuildService.cls"
