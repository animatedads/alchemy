/* Rasen Falcon owned LDAP service bootstrap.
 * Identity Directory remains semantic authority; NoSQLServer owns persistence;
 * Secret Broker owns secret materialisation; OpenSSL/Foreign Runtime owns TLS.
 */
signal on syntax name fatalSyntax

host = requiredEnv('RF_LDAP_HOST')
portText = requiredEnv('RF_LDAP_PORT')
if \portText~datatype('W') then call fail 'RF_LDAP_PORT must be a whole number'
port = portText
if port < 1 then call fail 'RF_LDAP_PORT out of range'
if port > 65535 then call fail 'RF_LDAP_PORT out of range'
peerId = requiredEnv('RF_LDAP_PEER_ID')
namingContext = requiredEnv('RF_LDAP_NAMING_CONTEXT')
storeRoot = requiredEnv('RF_LDAP_STORE_ROOT')
secretMapFile = requiredEnv('RF_LDAP_SECRET_MAP_FILE')
certFile = requiredEnv('RF_LDAP_CERT_FILE')
keyFile = requiredEnv('RF_LDAP_KEY_FILE')
bridgeDir = requiredEnv('RF_LDAP_BRIDGE_DIR')
readyFile = requiredEnv('RF_LDAP_READY_FILE')

mapping = loadSecretMap(secretMapFile)
if mapping~items = 0 then call fail 'RF_LDAP_SECRET_MAP_FILE contains no mappings'

broker = .SecretBroker~new(.MappedEnvironmentSecretProvider~new(mapping))
store = .NoSQLDirectoryStore~new(storeRoot)
directory = .IdentityDirectory~new(peerId, store, .true)

resource = directory~entryById('resource:directory')
if resource == .nil then call fail 'persistent directory is not provisioned with resource:directory'
if resource~state \= 'ACTIVE' then call fail 'resource:directory is not ACTIVE'

matching = .LdapMatchingRuleRegistry~new
authenticator = .SecretBrokerSimpleBindAuthenticator~new(directory, broker, 'LDAP_SIMPLE_BIND_SECRET', matching)
authority = .DirectoryAclLdapAuthority~new(directory)
sasl = .PlainLdapSaslProvider~new(authenticator)
service = .LdapConversationService~new(directory, .NativeLdapPersonality~new, authenticator, authority, 'resource:directory', sasl, matching)

tlsConfig = .LdapTlsConfig~new
tlsConfig~certificateFile = certFile
tlsConfig~privateKeyFile = keyFile
tlsConfig~bridgeDirectory = bridgeDir
if env('RF_LDAP_CLIENT_CA_FILE') \= '' then tlsConfig~clientCAFile = env('RF_LDAP_CLIENT_CA_FILE')
if env('RF_LDAP_REQUIRE_CLIENT_CERT')~caselessEquals('YES') then tlsConfig~requireClientCertificate = .true
tls = .OpenSslLdapTlsProvider~new(tlsConfig)
if \tls~available then call fail 'LDAP TLS provider unavailable'

/* Production identity is LDAPS-only. STARTTLS remains independently qualified
 * by the package but is not a production fallback for this unit. */
server = .LdapWireServer~new(service, host, port, namingContext, tls, .nil, .true)
say 'Rasen Falcon LDAP starting peer='peerId 'host='host 'port='port 'namingContext='namingContext
ignore = server~serve(0, readyFile)
exit 0

requiredEnv: procedure
  use strict arg name
  valueText = value(name,, 'ENVIRONMENT')
  if valueText = '' then do
    say 'LDAP SERVICE CONFIGURATION ERROR: missing' name
    exit 78
  end
  return valueText

env: procedure
  use strict arg name
  return value(name,, 'ENVIRONMENT')

loadSecretMap: procedure
  use strict arg path
  mapping = .directory~new
  if stream(path, 'C', 'QUERY EXISTS') = '' then do
    say 'LDAP SERVICE CONFIGURATION ERROR: missing secret map' path
    exit 78
  end
  call stream path, 'C', 'OPEN READ'
  do while lines(path) > 0
    line = linein(path)~strip
    if line = '' then iterate
    if line~left(1) = '#' then iterate
    tab = line~pos('09'x)
    if tab = 0 then do
      say 'LDAP SERVICE CONFIGURATION ERROR: secret map must be reference<TAB>environment-variable'
      exit 78
    end
    reference = line~left(tab - 1)~strip
    environmentName = line~substr(tab + 1)~strip
    if reference = '' then do
      say 'LDAP SERVICE CONFIGURATION ERROR: empty secret reference'
      exit 78
    end
    if environmentName = '' then do
      say 'LDAP SERVICE CONFIGURATION ERROR: empty secret environment variable'
      exit 78
    end
    if value(environmentName,, 'ENVIRONMENT') = '' then do
      say 'LDAP SERVICE CONFIGURATION ERROR: mapped environment secret missing for' reference
      exit 78
    end
    mapping[reference] = environmentName
  end
  call stream path, 'C', 'CLOSE'
  return mapping

fail: procedure
  use strict arg message
  say 'LDAP SERVICE CONFIGURATION ERROR:' message
  exit 78

fatalSyntax:
  say 'LDAP SERVICE FATAL RC='rc 'SIGL='sigl 'CONDITION='condition('C') 'DESCRIPTION='condition('D')
  exit 70

::requires "src/LdapWireServer.cls"
::requires "src/NoSQLDirectoryStore.cls"
::requires "src/LdapSecretBrokerAdapter.cls"
::requires "src/LdapOpenSslTls.cls"
::requires "SecretBroker.cls"
