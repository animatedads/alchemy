/* Rasen Falcon owned inbound SMTP service.
 * Scope: Internet/MX receive for configured local domains -> durable Storage
 * Fabric object + INBOX / INBOX-UNSIGNED membership.  It deliberately does
 * not provide authenticated submission; that remains a separate LDAP +
 * Access Permissions service boundary.
 */
signal on syntax name fatalSyntax

host = requiredEnv('RF_SMTP_HOST')
portText = requiredEnv('RF_SMTP_PORT')
if \portText~datatype('W') then call fail 'RF_SMTP_PORT must be a whole number'
port = portText + 0
if port < 1 | port > 65535 then call fail 'RF_SMTP_PORT out of range'
localDomains = splitList(requiredEnv('RF_SMTP_LOCAL_DOMAINS'))
if localDomains~items = 0 then call fail 'RF_SMTP_LOCAL_DOMAINS contains no domains'
storeRoot = requiredEnv('RF_SMTP_STORE_ROOT')
cataloguePath = requiredEnv('RF_SMTP_CATALOGUE_PATH')
certFile = requiredEnv('RF_SMTP_CERT_FILE')
keyFile = requiredEnv('RF_SMTP_KEY_FILE')
bridgeDir = requiredEnv('RF_SMTP_BRIDGE_DIR')
readyFile = requiredEnv('RF_SMTP_READY_FILE')
banner = env('RF_SMTP_BANNER'); if banner = '' then banner = 'mail.rasenfalcon.com'
trustFile = env('RF_SMTP_SMIME_CA_FILE')
tempRoot = env('RF_SMTP_TEMP_ROOT'); if tempRoot = '' then tempRoot = '/tmp'
openssl = env('RF_SMTP_OPENSSL'); if openssl = '' then openssl = 'openssl'

catalogue = .StorageCatalogue~new
catalogue~load(cataloguePath)
store = .StorageFabricSmtpStore~new(storeRoot,catalogue,'rasenfalcon-smtp','smtp-mail',cataloguePath)
delivery = .StorageFabricSmtpDeliveryProvider~new(store,localDomains)
verifier = .OpenSslSmimeMessageSignatureVerifier~new(trustFile,tempRoot,openssl)
policy = .SmtpPolicyConfig~new
service = .SmtpService~new(policy,.nil,.nil,.nil,.nil,verifier,delivery,.nil)

tlsConfig = .SecureSocketServerConfig~new
tlsConfig~certificateFile = certFile
tlsConfig~privateKeyFile = keyFile
tlsConfig~bridgeDirectory = bridgeDir
tls = .OpenSslSecureSocketServerProvider~new(tlsConfig)
if \tls~available then call fail 'SMTP TLS provider unavailable'

say 'Rasen Falcon inbound SMTP starting host='host 'port='port 'domains='listText(localDomains)
server = .SmtpWireServer~new(service,host,port,banner,tls)
ignore = server~serve(0,readyFile)
tls~close
exit 0

requiredEnv: procedure
  use strict arg name
  v = value(name,, 'ENVIRONMENT')
  if v = '' then do
    say 'SMTP SERVICE CONFIGURATION ERROR: missing' name
    exit 78
  end
  return v

env: procedure
  use strict arg name
  return value(name,, 'ENVIRONMENT')

splitList: procedure
  use strict arg text
  out=.array~new
  text=changestr(',',text,' ')
  do i=1 to words(text)
    item=word(text,i)~strip
    if item<>'' then out~append(item)
  end
  return out

listText: procedure
  use strict arg values
  out=''
  do i=1 to values~items
    if i>1 then out||=','
    out||=values[i]
  end
  return out

fail: procedure
  use strict arg message
  say 'SMTP SERVICE CONFIGURATION ERROR:' message
  exit 78

fatalSyntax:
  say 'SMTP SERVICE FATAL RC='rc 'SIGL='sigl 'CONDITION='condition('C') 'DESCRIPTION='condition('D')
  exit 70

::requires "src/SmtpWireServer.cls"
::requires "src/SmtpDurableDelivery.cls"
::requires "src/SmtpOpenSslSmimeVerifier.cls"
::requires "src/SecureSocketOpenSslServer.cls"
::requires "StorageFabric.cls"
