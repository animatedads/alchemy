/* NoSQLServer v0.91: strict single-table predicate mutation snapshot guard. */
path='fixtures/v091_phantom.sqlite'
engine=.SQLiteWritableDatabaseEngine~new(path)

/* Another connection changes the table after NoSQL selection but before
 * BEGIN IMMEDIATE.  Previously an UPDATE/DELETE of the selected old row
 * could commit while the newly inserted matching row was missed. */
address system 'python3 v091_sqlite_change.py add ' path ' 2 beta'
rs=engine~deleteWhere('notes',.nil)
call assert rs~status\=.Error~SUCCESS,'phantom insertion rejects stale direct mutation'
call assert rs~message~pos('phantom')>0,'conflict identifies phantom rows'
call assert engine~snapshotPath\=.nil,'failed mutation preserves snapshot metadata'

/* Zero matches is not an exemption: compare even for an empty batch. */
rs=engine~deleteWhere('notes',.NoMatch~new)
call assert rs~status\=.Error~SUCCESS,'zero-match write also fails stale snapshot'

/* New snapshot is authoritative and permits the intended mutation. */
ignored = engine~refreshNative
rs=engine~deleteWhere('notes',.nil)
call assert rs~status=.Error~SUCCESS,'refreshed predicate write accepted'
call assert rs~affectedRows=2,'new row included in DELETE ALL'

/* External UPDATE between snapshot and write must also conflict. */
address system 'python3 v091_sqlite_change.py add ' path ' 3 gamma'
ignored = engine~refreshNative
address system 'python3 v091_sqlite_change.py edit ' path ' 3 modified'
rs=engine~deleteWhere('notes',.nil)
call assert rs~status\=.Error~SUCCESS,'external row edit rejects mutation'
ignored = engine~refreshNative
rs=engine~deleteWhere('notes',.nil)
call assert rs~status=.Error~SUCCESS,'fresh delete succeeds'

/* No-op guarded batch is valid for an unchanged table. */
ignored = engine~refreshNative
rs=engine~deleteWhere('notes',.NoMatch~new)
call assert rs~status=.Error~SUCCESS,'unchanged snapshot zero-op accepted'
call assert rs~affectedRows=0,'empty guarded operation affects zero rows'

say 'NOSQLSERVER V0.91 SQLITE PHANTOM GUARD: PASS'
exit 0
assert: procedure
 use arg cond,label
 if \cond then do
  say 'FAIL' label
  exit 1
 end
 return
::class NoMatch public
::method evaluate
 return .false
::requires '../src/NoSQLServerSQLiteWritable.cls'
