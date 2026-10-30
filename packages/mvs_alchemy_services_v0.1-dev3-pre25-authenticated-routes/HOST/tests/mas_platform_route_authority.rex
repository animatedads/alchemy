/* PRE25 real LDAP Identity dev22 + ConnectSelector dev8 authority smoke. */
directory=.IdentityDirectory~new('mas-pre25')
call must directory~createPrincipal('HERC01','uid=HERC01,ou=people,dc=rasenfalcon,dc=com','SERVICE','HERC01','HERC01'),'principal'
call must directory~createResource('route.ed209c','cn=route-ed209c,ou=resources,dc=rasenfalcon,dc=com','CONNECT_ROUTE','connect://ED209C/RPC','ED209C RPC'),'resource'
call must directory~createAclGrant('acl.herc01.ed209c.rpc','cn=acl-herc01-ed209c-rpc,ou=acls,dc=rasenfalcon,dc=com','HERC01','route.ed209c','CONNECT_RPC','ALLOW'),'acl'
mapping=.MasRouteResourceMap~new~register('ED209C','RPC','route.ed209c','CONNECT_RPC')
sessions=.TestRouteSessionProvider~new(.LdapSession~new('ldap-session-1','HERC01',.true))
channel=.TestChannelAttestor~new(.true)
authority=.MasAuthenticatedRouteAuthority~new(sessions,channel,directory,mapping)
routes=.ConnectRoutePolicy~new~allow('mas.providers.database.get','REQUEST','RPC','ED209C')
policy=.ConnectAuthenticatedRoutePolicy~new(routes,authority)
intent=.ConnectIntent~new('mas.providers.database.get','REQUEST','IMMEDIATE','RPC','ED209C')
call assert policy~permitted(intent,'RPC'),'allowed route'
channel~allowed=.false; call assert \policy~permitted(intent,'RPC'),'channel deny'
channel~allowed=.true; sessions~session=.LdapSession~new('ldap-session-2','HERC01',.false); call assert \policy~permitted(intent,'RPC'),'unauthenticated deny'
sessions~session=.LdapSession~new('ldap-session-3','NOACL',.true); call assert \policy~permitted(intent,'RPC'),'acl default deny'
sessions~session=.LdapSession~new('ldap-session-4','HERC01',.true)
resolver=.MasLdapHostIdentityResolver~new(.TestMasSessionResolver~new(sessions~session))
identity=resolver~resolve('mvs-session-7')
call assert identity<>.nil & identity~principalId='HERC01','principal attribution'
ctx=.TestHttpsContext~new('TLSv1.3','TLS_AES_256_GCM_SHA384',7)
https=.MasHttpsExchangeChannelAttestor~new(.TestContextProvider~new(ctx))
call assert \https~attestRoute(intent,'RPC'),'tls alone denied'
ctx~put('mas.private_ca_verified',.true)
call assert https~attestRoute(intent,'RPC'),'private-ca evidence accepted'
say 'PASS MAS_PLATFORM_ROUTE_AUTHORITY_PRE25'
exit 0
must: procedure; use arg r,l; if r==.nil | \r~ok then do; say 'FAIL' l; exit 8; end; return
assert: procedure; use arg ok,l; if \ok then do; say 'FAIL' l; exit 8; end; return
::class TestRouteSessionProvider subclass MasRouteSessionProvider
::attribute session
::method init; expose session; use strict arg s; session=s
::method sessionForRoute; expose session; use strict arg intention,provider; return session
::class TestMasSessionResolver
::method init; expose session; use strict arg s; session=s
::method resolveSession; expose session; use strict arg sessionId,context=.nil; return session
::class TestChannelAttestor subclass MasRouteChannelAttestor
::attribute allowed
::method init; expose allowed; use strict arg a; allowed=a
::method attestRoute; expose allowed; use strict arg intention,provider; return allowed
::class TestContextProvider
::method init; expose context; use strict arg c; context=c
::method contextForRoute; expose context; use strict arg intention,provider; return context
::class TestHttpsContext
::attribute tlsProtocol get
::attribute tlsCipher get
::attribute tlsGeneration get
::method init; expose tlsProtocol tlsCipher tlsGeneration values; use strict arg p,c,g; tlsProtocol=p; tlsCipher=c; tlsGeneration=g; values=.Directory~new
::method put; expose values; use strict arg n,v; values[n]=v; return self
::method get; expose values; use strict arg n,d=.nil; if values~hasIndex(n) then return values[n]; return d
::requires 'ConnectSelector.cls'
::requires 'ConnectAuthenticatedRoutePolicy.cls'
::requires 'MasPlatformRouteAuthority.cls'
