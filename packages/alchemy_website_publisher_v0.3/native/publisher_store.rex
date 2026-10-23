/* Candidate-only handoff to NoSQLServer v0.90. No publishing authority. */
numeric digits 20
signal on syntax name failed
signal on error name failed
parse arg action database filename expected
if action == '' | database == '' then do
  say 'USAGE: rexx publisher_store.rex init|save|load|history|verify DB [FILE] [REVISION]'
  exit 64
end
store = .CmsWebsiteSnapshotStore~new(database)
select
  when action == 'init' then say 'STORE_READY candidate-only; native revision=' store~revision
  when action == 'save' then do
    if filename == '' | expected == '' then raise syntax 93.900 additional('save needs input and expected revision')
    raw = readFile(filename)
    if pos('alchemy.website.publisher.export/0.1', raw) = 0 then raise syntax 93.900 additional('Expected publisher export/0.1')
    revision = store~append(raw,expected)
    say 'SAVED_NATIVE_REVISION' revision 'CANDIDATE_ONLY'
  end
  when action == 'load' then do
    if filename == '' then raise syntax 93.900 additional('load needs an unused output pathname')
    if expected == '' then expected = 0
    record = store~get(expected)
    if record == .nil then raise syntax 93.900 additional('Revision not found')
    payload = '{"schema":"alchemy.website.publisher.native-record/0.2",' || ,
              '"provider":"NoSQLServer",' || ,
              '"backend":"SQLITE_NATIVE_READWRITE",' || ,
              '"authority":"CANDIDATE_ONLY",' || ,
              '"revision":' || record['revision'] || ',' || ,
              '"parent_revision":' || record['parent_revision'] || ',' || ,
              '"document":' || jsonQuote(record['document']) || '}'
    call writeNew filename,payload
    say 'LOADED_NATIVE_REVISION' record['revision'] filename
  end
  when action == 'verify' then do
    count = store~verify
    say 'LEDGER_VALID' count 'CANDIDATE_ONLY'
  end
  when action == 'history' then do
    if filename == '' then raise syntax 93.900 additional('history needs an unused output pathname')
    txt = 'revision' || '09'x || 'parent_revision' || '09'x || 'recorded_at' || '0a'x
    do record over store~all
      if record['site'] == 'rasenfalcon.com' then txt ||= record['revision'] || '09'x || record['parent_revision'] || '09'x || record['recorded_at'] || '0a'x
    end
    call writeNew filename,txt
    say 'HISTORY_EXPORTED' filename
  end
  otherwise raise syntax 93.900 additional('Unknown action')
end
exit 0

readFile: procedure
  use arg name
  if stream(name,'C','QUERY EXISTS') == '' then raise syntax 93.900 additional('Missing input file')
  call stream name,'C','OPEN READ'
  len=chars(name)
  content=charin(name,1,len)
  call stream name,'C','CLOSE'
  return content

writeNew: procedure
  use arg name,content
  if stream(name,'C','QUERY EXISTS') \= '' then raise syntax 93.900 additional('Output exists: refusing overwrite')
  call stream name,'C','OPEN WRITE'
  call charout name,content,1
  call stream name,'C','CLOSE'
  return

jsonQuote: procedure
  use arg input
  input=changestr('5c'x,input,'5c5c'x)
  input=changestr('22'x,input,'5c22'x)
  input=changestr('0d'x,input,'5c72'x)
  input=changestr('0a'x,input,'5c6e'x)
  input=changestr('09'x,input,'5c74'x)
  return '22'x || input || '22'x

failed:
  say 'NO_COMMIT:' condition('D')
  exit 2
::requires 'CmsWebsiteSnapshotStore.cls'
