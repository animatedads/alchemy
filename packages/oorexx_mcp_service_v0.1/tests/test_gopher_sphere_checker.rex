gopher=value('MCP_GOPHER',,'ENVIRONMENT')
api=value('MCP_API_ROLLUP',,'ENVIRONMENT')
overrides=value('MCP_SPHERE_OVERRIDE_DIR',,'ENVIRONMENT')
if gopher='' | api='' | overrides='' then do
  say 'SKIP test_gopher_sphere_checker (set MCP_GOPHER, MCP_API_ROLLUP, MCP_SPHERE_OVERRIDE_DIR)'
  exit 0
end
checker=.McpGopherSphereChecker~new(gopher,api,overrides)
args=.directory~new; args['sphereId']='https-server'
r=checker~check(args)
call assert r~ok & r~code='SPHERE_RESOLVED','https-server sphere resolves'
selected=r~value['gopher']['result']['selected']
call assert selected['source_class']~string='local_override','override sphere selected'
call assert selected['archive_sha256']~string<>'','sphere provenance hash returned'
args['sphereId']='no-such-sphere'
r=checker~check(args)
call assert \r~ok & r~code='SPHERE_NOT_FOUND','missing sphere reported'
args['sphereId']='bad;name'
r=checker~check(args)
call assert \r~ok & r~code='INVALID_ARGUMENT','unsafe sphere id rejected'
say 'PASS test_gopher_sphere_checker'
exit 0
assert: procedure
  use arg condition,label
  if \condition then do; say 'FAIL:' label; exit 1; end
  return
::requires 'McpGopherSphereChecker.cls'
