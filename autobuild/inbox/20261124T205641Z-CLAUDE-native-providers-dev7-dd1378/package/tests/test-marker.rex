/* Architecture: Tom Dyer. Coding: ChatGPT. */
if \ .LinuxProcess~hasMethod('PAGESIZEAWARE') then exit 1
if .NativeObservedProcess~new~rssKiB \= 12345 then exit 2
say 'PASS page-size-aware superclass delegation (fixture)'
::requires 'ProcessProvider.cls'
::requires 'Computer.cls'
