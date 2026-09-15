/* Package-level test statements: none of these ASSERT calls execute SQL. */
sql = "BEGIN ISOLATION LEVEL SERIALIZABLE READ WRITE; COMMIT;"
call assert sql~pos("COMMIT;") > 0, "compiled SQL contains commit"
procStatus = "OK"
call assert procStatus = "OK", "procedure state good"
mustSql = "durability evidence"
call assert mustSql <> "", "sql evidence retained"

/* This one really is SQL text and should still be proposed as SQL CALL. */
callText = "CALL POST_LEDGER(?, ?)"
