# MAS/LDAP binding to Alchemy Identity Directory (reviewed through dev14)

Status: development binding; BASE-1 remains unqualified.

This binding was established against dev10 and has been re-reviewed against the current `oorexx_ldap_identity_v0.1-dev14` Library line; MAS continues to bind the published semantic conversation/identity contracts rather than private implementation state. MAS does not invent a private directory model.

## Consumed public development contracts

MAS/LDAP consumes these existing contracts as applicable:

- `identity.directory/0.1` — neutral semantic identity directory
- `ldap.personality/0.1` — LDAP projection/import personality
- `ldap.conversation/0.1` — authenticated LDAP conversation and operation authority
- `ldap.dn/0.1` — DN syntax and hierarchy
- `ldap.filter/0.1` — LDAP filter parsing/evaluation
- `ldap.matching/0.1` — live matching semantics
- `ldap.schema/0.1` — native schema/subschema discovery
- `ldap.paging/0.1` — bounded result paging where used

The contracts are development APIs, not frozen production interfaces.

## Concrete host seam

The primary MAS host adapter SHALL be constructed around `LdapConversationService`, not around raw LDAP wire packets. Its existing operations are:

- `bind`
- `bindSasl`
- `saslMechanisms`
- `search`
- `compare`
- `add`
- `modify`
- `delete`
- `modifyDn`
- `capabilities`

`LdapConversationService` already separates authentication from operation authority. MAS MUST preserve that separation. A successful LDAP Bind attributes an LDAP identity; it does not grant MAS/MVS authority and does not itself authorize Search/Compare/Add/Modify/Delete/ModifyDN.

`NativeLdapPersonality` is the native LDAP projection over the neutral directory. `FilteredDirectoryPersonality` and `AttributeAliasConversationFilter` are the existing compatibility edge for alternate external vocabulary; MAS must not add vendor semantics to the neutral identity core.

## Identity rules

`oorexxEntityId` is the stable platform semantic identity. `entryUUID` is the LDAP entry UUID. They are deliberately distinct and MAS SHALL NOT merge them. DN is an LDAP address, not the semantic identity.

## MVS operation mapping

The initial MVS-facing calls map semantically as follows:

| MVS personality call | Alchemy LDAP seam |
| --- | --- |
| LDAPINIT | create/open MAS LDAP personality context |
| LDAPBIND | `LdapConversationService~bind` |
| LDAPSRCH | `LdapConversationService~search` |
| LDAPNEXT | MAS-owned continuation over bounded search results |
| LDAPATTR / LDAPVALUE | MAS projection over returned `LdapEntry` / `LdapAttributeSet` |
| LDAPADD | `LdapConversationService~add` |
| LDAPMOD | `LdapConversationService~modify` |
| LDAPDEL | `LdapConversationService~delete` |
| LDAPCMP | `LdapConversationService~compare` |
| LDAPUNBD | release MAS LDAP session/context |

This is a semantic mapping, not a claim that the MVS assembler entry modules are implemented yet.

## Representation boundary

MVS handles remain opaque 32-bit MAS tokens. No ooRexx object reference crosses the wire. DN/filter strings are explicit CHAR values with declared encoding. Attribute values whose LDAP syntax is not known to be text remain BYTES. Large result sets are iterated/paged and must not be materialized wholesale in the 16 MB reference guest.

## Security boundary

MAS caller provenance (job/step/program/session) and LDAP authentication are independent inputs. Provider credentials remain off MVS configuration. The Alchemy LDAP authority decision remains authoritative for directory operations; MAS must not synthesize success when authority is unavailable.

## Deliberate exclusions

This binding does not claim IBM z/OS LDAP compatibility, full OpenLDAP compatibility, frozen Alchemy APIs, or a completed MVS LDAP implementation. It also does not route MAS through `LdapWireClient`: MAS is an in-process Alchemy consumer on the host side and should use the semantic conversation service directly.
