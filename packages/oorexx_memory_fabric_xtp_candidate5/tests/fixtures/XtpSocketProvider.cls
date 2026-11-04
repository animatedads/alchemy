/* ooRexx test-only dev34 public shape, NEVER shipped on a production path. */
::class XtpNamedAcceptedSocket public
::method init
 expose serviceName protection keyId keyPrincipal buffer
 use strict arg serviceArg, protectionArg, kidArg, principalArg, bytes
 serviceName=serviceArg; protection=protectionArg; keyId=kidArg; keyPrincipal=principalArg; buffer=bytes
::attribute serviceName get
::attribute protection get
::attribute keyId get
::attribute keyPrincipal get
::method recv
 expose buffer
 use strict arg maximumBytes
 if buffer==.nil then return .nil
 if buffer='' then return .nil
 take=maximumBytes
 if take>buffer~length then take=buffer~length
 bytes=buffer~substr(1,take)
 buffer=buffer~substr(take+1)
 return bytes
