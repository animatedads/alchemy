numeric digits 30
m=.HostedModuleDeclaration~new('mcp-project','oorexx-https','0.4.4','McpHttpsRoute.cls','McpHttpsRoute','bind','/mcp','POST','compose-before-start')
call must m~validate='','valid hosted declaration'
r=.HostedModuleDeploymentRequirement~new(m)
call must r~kind='hosted-module:oorexx-https','host kind'
call must r~expected='PROBED_ACTIVE','strong live state'
e=.HostedModuleEvidence~new('mcp-project')
call must e~state='ABSENT','initial state'
e~staged=.true; call must e~state='STAGED','staged state'
e~packageLoadable=.true; call must e~state='LOADABLE','loadable state'
e~composed=.true; call must e~state='COMPOSED','composed state'
e~activated=.true; call must e~state='ACTIVE_UNPROBED','active unprobed state'
e~probed=.true; e~probeStatus='405'; call must e~state='PROBED_ACTIVE','probed state'
call must e~satisfied,'all lifecycle evidence required'
say 'PASS hosted module model'
exit 0
must: procedure
 use strict arg c,m
 if \c then do; say 'FAIL' m; exit 1; end
return
::requires 'HostedModuleDeployment.cls'
