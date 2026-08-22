/* deterministic acceptance tests for git_mesh_transport_v0.1 */
address command 'rm -rf /tmp/git_mesh_transport_test'

root = '/tmp/git_mesh_transport_test'
m = .GitMeshTransport~new(root)
call assert m~ensureLayout, 'layout'
call assert SysFileExists(root || '/mesh/ctl'), 'ctl directory'
call assert SysFileExists(root || '/mesh/announce'), 'announce directory'
call assert SysFileExists(root || '/mesh/notes'), 'notes directory'

p = m~messagePath('CHATGPT', 'RUNNER', '20260822T043000Z-0001.msg')
call assert p == root || '/mesh/ctl/CHATGPT-RUNNER/20260822T043000Z-0001.msg', 'message path'

payload = '{"knd":"RUN","package":"demo"}'
call assert m~send('CHATGPT', 'RUNNER', '20260822T043000Z-0001.msg', payload), 'send'
call assert SysFileExists(p), 'message exists'
call assert m~read(p) == payload, 'read payload'

call assert \m~send('CHATGPT', 'RUNNER', '20260822T043000Z-0001.msg', payload), 'append only collision'
call assert pos('already exists', m~lastError) > 0, 'collision diagnostic'

bad = m~messagePath('../CHATGPT', 'RUNNER', 'x.msg')
call assert bad == .nil, 'reject traversal node'

call assert m~writeAnnouncement('RUNNER', '{"status":"up"}'), 'announcement write'
call assert SysFileExists(root || '/mesh/announce/node.RUNNER.json'), 'announcement exists'

call assert m~writeNote('RUNNER', '20260822-status.md', '# runner ok'), 'note write'
call assert SysFileExists(root || '/mesh/notes/RUNNER/20260822-status.md'), 'note exists'

say 'PASS test_git_mesh_transport'
address command 'rm -rf /tmp/git_mesh_transport_test'
exit 0

assert: procedure
  use arg condition, label
  if condition then return
  say 'FAIL' label
  exit 1

::requires 'git_mesh_transport.cls'
