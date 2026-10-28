/* Native guard for the authentic NoSQLServer DatabaseRow structure.
 * A DatabaseRow has [] access and a values Table; it does not itself have
 * allIndexes. The migration must enumerate row~values~allIndexes.
 */
raw = .Table~new
raw["doc_key"] = "D-001"
raw["title"] = "Exact" || x2c("0d0a") || "text"
row = .DatabaseRow~new(raw)
names = row~values~allIndexes
if names~items \= 2 then raise syntax 93.900 array("DatabaseRow column count")
copy = .Table~new
do name over names
  copy[name] = row[name]
end
if copy["doc_key"] \== raw["doc_key"] then -
  raise syntax 93.900 array("DatabaseRow value mismatch")
if copy["title"] \== raw["title"] then -
  raise syntax 93.900 array("DatabaseRow CRLF mismatch")
say "NOTNOTES_DATABASE_ROW_CONTRACT_PASS"
exit 0
::requires 'vendor/nosql/NoSQLServer.cls'
