/* Resident memory across 10,000 bound inserts (SQLCOMMAND with values), 10,000 unbound inserts, and
 * 10,000 SQLEXECUTE runs of one prepared statement. Arg: database path.
 * Claude (Opus 5.5), 2026-10-28. Architecture: Tom Dyer. Rexx/SQL: Mark Hessling.
 * Found by SLAM (oorexx_slam_v0.1): its whole-estate ingest was killed by the kernel at 6.1 GB. */
parse arg db
call rxfuncadd 'SQLLoadFuncs', 'rexxsql', 'SQLLoadFuncs'; call SQLLoadFuncs
call SQLConnect 'c1', , , db
call SQLCommand 'd', 'create table t (a integer, b integer)'
call rss 'start'
call SQLCommand 'b', 'begin'
do i = 1 to 10000
  call SQLCommand 'i', 'insert into t values (?, ?)', 'CHAR', i, 'CHAR', i
end
call SQLCommand 'c', 'commit'
call rss 'SQLCOMMAND, 10000 bound inserts'
call SQLCommand 'b', 'begin'
do i = 1 to 10000
  call SQLCommand 'i', 'insert into t values (' i ',' i ')'
end
call SQLCommand 'c', 'commit'
call rss 'SQLCOMMAND, 10000 unbound inserts'
call SQLPrepare 'p', 'insert into t values (?, ?)'
call SQLCommand 'b', 'begin'
do i = 1 to 10000
  call SQLExecute 'p', 'CHAR', i, 'CHAR', i
end
call SQLCommand 'c', 'commit'
call rss 'SQLPREPARE once + 10000 SQLEXECUTE'
call SQLDisconnect 'c1'
exit
rss: procedure
  use arg label
  address system 'echo "' || label~left(44) || '" $(grep VmRSS /proc/$PPID/status)'
  return
