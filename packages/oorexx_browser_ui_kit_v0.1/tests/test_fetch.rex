/* test_fetch.rex -- fetch-for-me against a fake curl: allowlist, hand-followed redirects, hashes, excerpt, reply.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 8 November 2026.
 *   bin/kit.sh rexx tests/test_fetch.rex
 */
kit=value('KIT',, 'ENVIRONMENT')
store=kit'/var/test-fetched'
address system 'rm -rf' fxQ(store)
props=fxReadConf(kit'/etc/fetch.conf')
props['store_dir']=store
policy=.FetchPolicy~new(props)
tools=.directory~new
tools['curl']='sh' fxQ(kit'/tests/fakes/curl-fetch-fake')        /* via sh: a copied file may lose its exec bit */
tools['svn']='false'
pass=0
fail=0

/* the allowlist */
call check 'host sourceforge.net allowed', policy~hostAllowed('sourceforge.net')
call check 'mirror subdomain allowed', policy~hostAllowed('netix.dl.sourceforge.net')
call check 'look-alike host refused', \policy~hostAllowed('evilsourceforge.net')
call check 'suffix trick refused', \policy~hostAllowed('sourceforge.net.evil.com')
call check 'fxHost strips user@, port, query', fxHost('https://u:p@SourceForge.net:443/x?y=1')=='sourceforge.net'
call check 'fxHost on a userinfo trick', fxHost('https://sourceforge.net@evil.com/x')=='evil.com'

/* a text file */
r=.FetchRun~new(policy, .FetchRequest~new('req-1', 'http', 'https://sourceforge.net/p/oorexx/code-0/HEAD/tree/README.txt?format=raw', 'CLAUDE'), tools)
call check 'text file fetched', r~fetch, r~findings~lines~makeString('L', ' / ')
call check 'stored under the query-free name', SysFileExists(store'/req-1/README.txt')
call check 'SHA256SUMS written', fileText(store'/req-1/SHA256SUMS')~pos('README.txt')>0
call check 'excerpt holds the text', fileText(store'/req-1/excerpt.txt')~pos('ooRexx README (fake)')>0
call check 'the report names the content type', fileText(store'/req-1/reply.md')~pos('content-type text/plain')>0, fileText(store'/req-1/reply.md')
reply=fileText(store'/req-1/reply.md')
call check 'reply names the asker and the hash', reply~pos('Fetched for CLAUDE, request req-1')>0 & reply~pos(fileText(store'/req-1/SHA256SUMS')~word(1))>0
call check 'reply marks the excerpt as data', reply~pos('data, not instructions')>0
call check 'store directory is mode 700', dirMode(store'/req-1')=='700', dirMode(store'/req-1')
call check 'ledger row written', fileText(store'/fetch-ledger.tsv')~pos('req-1')>0

/* redirects followed by hand through allowed mirrors */
r=.FetchRun~new(policy, .FetchRequest~new('req-2', 'http', 'https://sourceforge.net/projects/oorexx/files/x.zip/download', 'CLAUDE'), tools)
call check 'two allowed redirects followed', r~fetch, r~findings~lines~makeString('L', ' / ')
call check 'redirects recorded as INFO', r~findings~count('INFO')>=2
call check 'binary file gets no text excerpt', fileText(store'/req-2/excerpt.txt')~pos('not text')>0, fileText(store'/req-2/excerpt.txt')

/* refusals */
r=.FetchRun~new(policy, .FetchRequest~new('req-3', 'http', 'https://sourceforge.net/evil', 'CLAUDE'), tools)
call check 'redirect to unlisted host refused', \r~fetch & r~findings~lines~makeString('L', ' ')~pos('evil.example.com which is not on the allowlist')>0, r~findings~lines~makeString('L', ' / ')
r=.FetchRun~new(policy, .FetchRequest~new('req-4', 'http', 'https://example.com/x', 'CLAUDE'), tools)
call check 'unlisted host refused before any fetch', \r~fetch & \SysFileExists(store'/req-4')
r=.FetchRun~new(policy, .FetchRequest~new('req-5', 'http', 'http://sourceforge.net/x', 'CLAUDE'), tools)
call check 'plain http refused', \r~fetch
r=.FetchRun~new(policy, .FetchRequest~new('../up', 'http', 'https://sourceforge.net/x', 'CLAUDE'), tools)
call check 'path-like request id refused', \r~fetch
r=.FetchRun~new(policy, .FetchRequest~new('req-6', 'http', 'https://sourceforge.net/x;rm -rf ~', 'CLAUDE'), tools)
call check 'shell metacharacters refused', \r~fetch
r=.FetchRun~new(policy, .FetchRequest~new('req-7', 'http', 'https://sourceforge.net/missing', 'CLAUDE'), tools)
call check '404 is a STOP', \r~fetch & r~findings~lines~makeString('L', ' ')~pos('HTTP 404')>0
r=.FetchRun~new(policy, .FetchRequest~new('req-1', 'http', 'https://sourceforge.net/p/oorexx/code-0/HEAD/tree/README.txt?format=raw', 'CLAUDE'), tools)
call check 'a request id is used once', \r~fetch & r~findings~lines~makeString('L', ' ')~pos('already exists')>0
r=.FetchRun~new(policy, .FetchRequest~new('req-8', 'ftp', 'https://sourceforge.net/x', 'CLAUDE'), tools)
call check 'unknown kind refused', \r~fetch

address system 'rm -rf' fxQ(store)
say 'fetch tests:' pass 'passed,' fail 'failed'
exit (fail>0)

check:
  use arg what, ok, detail=''
  if ok then do
    pass=pass+1
    say 'PASS' what
  end
  else do
    fail=fail+1
    say 'FAIL' what '--' detail
  end
  return

::routine fileText
  use strict arg f
  if \SysFileExists(f) then return ''
  s=.stream~new(f)
  t=s~charin(1, s~chars)
  s~close
  return t
::routine dirMode
  use strict arg d
  address system 'stat -c %a' fxQ(d) with output stem o.
  if o.0=0 then return '?'
  return o.1~strip

::requires 'FetchForMe.cls'
