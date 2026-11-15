/* fetch-for-me.rex -- fetch an allowlisted URL for an agent that cannot reach it.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 8 November 2026.
 *
 *   bin/kit.sh rexx bin/fetch-for-me.rex REQUEST_ID URL [svn] [--for WHO]
 *
 * Result in <store_dir>/REQUEST_ID/: the file (or export.tar.gz for an svn directory), SHA256SUMS, excerpt.txt,
 * reply.md.  reply.md is printed: it is the text that goes back to the asker through the mailbox.
 * Exit 0 fetched, 1 refused or failed (the reasons are printed), 2 usage.
 */
parse arg id url rest
kind='http'
asker='unknown'
do while rest<>''
  parse var rest w rest
  select
    when w=='svn' then kind='svn'
    when w=='--for' then parse var rest asker rest
    otherwise do
      say 'fetch-for-me: unknown argument' w
      exit 2
    end
  end
end
if id=='' | url=='' then do
  say 'usage: fetch-for-me.rex REQUEST_ID URL [svn] [--for WHO]'
  exit 2
end
kit=value('KIT',, 'ENVIRONMENT')
conf=fxReadConf(kit'/etc/fetch.conf')
local=fxReadConf(kit'/var/fetch.local.conf')
do k over local~allIndexes
  conf[k]=local[k]
end
tools=.directory~new
tools['curl']=value('FETCH_CURL',, 'ENVIRONMENT')
if tools['curl']=='' then tools['curl']='curl'
tools['svn']=value('FETCH_SVN',, 'ENVIRONMENT')
if tools['svn']=='' then tools['svn']='svn'
run=.FetchRun~new(.FetchPolicy~new(conf), .FetchRequest~new(id, kind, url, asker), tools)
ok=run~fetch
if ok then do
  s=.stream~new(.FetchPolicy~new(conf)~storeDir'/'id'/reply.md')
  s~open('read')
  do while s~lines>0
    say s~linein
  end
  s~close
  exit 0
end
say 'fetch-for-me: NOT fetched' id
do l over run~findings~lines
  say '  'l
end
exit 1
::requires 'FetchForMe.cls'
