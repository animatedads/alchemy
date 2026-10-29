from pathlib import Path
s=(Path(__file__).parents[1]/'rexx'/'WireImapSource.cls').read_text()
assert 'toArray' not in s
assert 'session~examine(mailbox)' in s
assert 'uidSearch("ALL", "COUNT MIN MAX ALL")' in s
assert 'uidSet~uidAtOrdinal(ordinal)' in s
assert 'BODY.PEEK[HEADER.FIELDS' in s
assert 'uidFetchBodyPeek' in s
assert 'uidMove' not in s and 'uidStore' not in s and 'deleteMailbox' not in s
print('PASS IMAP adapter static contract')
