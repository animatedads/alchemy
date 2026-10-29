/* Rasen Falcon LDAP activation admission proof.
 * No network or production secret dependency: this qualifies the directory
 * authority model consumed by website/mail service rehearsals.
 */
failed = 0

dir = .IdentityDirectory~new("rasenfalcon-activation")
call ok dir~createPrincipal("principal:human", "uid=human,ou=people,dc=rasenfalcon,dc=com", "PERSON", "Human Operator", "human"), "human principal"
call ok dir~createPrincipal("principal:chatgpt", "uid=chatgpt,ou=agents,dc=rasenfalcon,dc=com", "SERVICE", "CHATGPT", "chatgpt"), "chatgpt principal"
call ok dir~createPrincipal("principal:claude", "uid=claude,ou=agents,dc=rasenfalcon,dc=com", "SERVICE", "CLAUDE", "claude"), "claude principal"
call ok dir~createGroup("group:mail-users", "cn=mail-users,ou=groups,dc=rasenfalcon,dc=com", "Mail users"), "mail group"
call ok dir~addGroupMember("group:mail-users", "principal:human"), "human mail membership"
call ok dir~addGroupMember("group:mail-users", "principal:chatgpt"), "chatgpt mail membership"
call ok dir~createResource("resource:directory", "cn=directory,ou=resources,dc=rasenfalcon,dc=com", "DIRECTORY", "identity://rasenfalcon", "Rasen Falcon Directory"), "directory resource"
call ok dir~createResource("resource:mail", "cn=mail,ou=resources,dc=rasenfalcon,dc=com", "MAIL", "mail://rasenfalcon", "Rasen Falcon Mail"), "mail resource"
call ok dir~createResource("resource:website-private", "cn=website-private,ou=resources,dc=rasenfalcon,dc=com", "HTTPS", "https://office.rasenfalcon.com", "Private Website"), "website resource"
call ok dir~createAclGrant("acl:mail-users:mail-read", "cn=mail-read,ou=acl,dc=rasenfalcon,dc=com", "group:mail-users", "resource:mail", "MAIL_READ", "ALLOW"), "mail read grant"
call ok dir~createAclGrant("acl:human:website", "cn=website-human,ou=acl,dc=rasenfalcon,dc=com", "principal:human", "resource:website-private", "HTTPS_LOGIN", "ALLOW"), "website grant"
call ok dir~createAclGrant("acl:chatgpt:email-send", "cn=email-send-chatgpt,ou=acl,dc=rasenfalcon,dc=com", "principal:chatgpt", "resource:mail", "EMAIL_SEND", "ALLOW"), "chatgpt send grant"

call allowed dir~aclDecision("principal:human", "resource:mail", "MAIL_READ"), "human reads mail through group"
call allowed dir~aclDecision("principal:chatgpt", "resource:mail", "MAIL_READ"), "chatgpt reads own authorised mail surface"
call denied dir~aclDecision("principal:claude", "resource:mail", "MAIL_READ"), "claude does not inherit chatgpt/human mail"
call allowed dir~aclDecision("principal:human", "resource:website-private", "HTTPS_LOGIN"), "human private website login"
call denied dir~aclDecision("principal:chatgpt", "resource:website-private", "HTTPS_LOGIN"), "chatgpt not human website principal"
call allowed dir~aclDecision("principal:chatgpt", "resource:mail", "EMAIL_SEND"), "chatgpt explicit email send"
call denied dir~aclDecision("principal:claude", "resource:mail", "EMAIL_SEND"), "claude cannot cross chatgpt signing/send authority"

call ok dir~setEntityState("principal:chatgpt", "REVOKED"), "revoke chatgpt"
call deniedAdmission dir, "principal:chatgpt", "resource:mail", "EMAIL_SEND", "revoked chatgpt denied immediately"
call allowedAdmission dir, "principal:human", "resource:mail", "MAIL_READ", "active human still admitted"

if failed = 0 then do
  say "LDAP ACTIVATION IDENTITY POLICY: OK"
  exit 0
end
say "LDAP ACTIVATION IDENTITY POLICY: FAILED" failed
exit 1

ok: procedure expose failed
  use arg directoryResult, label
  if \directoryResult~ok then do
    say "FAIL" label directoryResult~code directoryResult~detail
    failed += 1
  end
  return

allowed: procedure expose failed
  use arg directoryResult, label
  if \directoryResult~ok then do
    say "EXPECTED ALLOW FAILED" label directoryResult~code
    failed += 1
  end
  return

denied: procedure expose failed
  use arg directoryResult, label
  if directoryResult~ok then do
    say "EXPECTED DENY FAILED" label
    failed += 1
  end
  return

admissionDecision: procedure
  use arg directory, principalId, resourceId, action
  principal = directory~entryById(principalId)
  if principal == .nil then return .DirectoryResult~failure("NO_SUCH_PRINCIPAL", principalId)
  if principal~state <> "ACTIVE" then return .DirectoryResult~failure("PRINCIPAL_NOT_ACTIVE", principal~state)
  return directory~aclDecision(principalId, resourceId, action)

allowedAdmission: procedure expose failed
  use arg directory, principalId, resourceId, action, label
  decision = admissionDecision(directory, principalId, resourceId, action)
  if \decision~ok then do
    say "EXPECTED ACTIVE ADMISSION FAILED" label decision~code
    failed += 1
  end
  return

deniedAdmission: procedure expose failed
  use arg directory, principalId, resourceId, action, label
  decision = admissionDecision(directory, principalId, resourceId, action)
  if decision~ok then do
    say "EXPECTED REVOKED ADMISSION FAILED" label
    failed += 1
  end
  return

::requires "src/IdentityDirectory.cls"
