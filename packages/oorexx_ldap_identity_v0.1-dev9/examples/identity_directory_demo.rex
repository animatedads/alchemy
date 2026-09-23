dir = .IdentityDirectory~new("demo-peer")
ignore = dir~createPrincipal("principal:alice", "uid=alice,ou=people,dc=example,dc=org", "PERSON", "Alice Example", "alice")
ignore = dir~createGroup("group:operators", "cn=operators,ou=groups,dc=example,dc=org", "Operators")
ignore = dir~addGroupMember("group:operators", "principal:alice")
ignore = dir~createResource("resource:directory", "cn=directory,ou=resources,dc=example,dc=org", "DIRECTORY", "identity://example")
ignore = dir~createAclGrant("acl:operators-search", "cn=operators-search,ou=acl,dc=example,dc=org", "group:operators", "resource:directory", "LDAP_SEARCH", "ALLOW")
p = .NativeLdapPersonality~new
say "Directory semantic entries projected through native LDAP personality:"
do entity over dir~allEntries
  entry = p~project(entity, dir)
  say entry~dn
  do name over entry~attributes~names
    line = "  " || name || ":"
    do value over entry~attributes~get(name)
      line ||= " " || value
    end
    say line
  end
end
::requires "src/LdapDirectoryPersonality.cls"
