/* FpHttp.cls - SLAM 450 Flight Planner v0.1: every retrieval script fetches
 * through Alchemy's own HTTPS client, API Client v0.4.1 (ApiHttpsTransport:
 * RxSock sockets, OpenSSL through Foreign Runtime v0.22.6), never curl.
 *
 * Kit, from the environment:
 *   FP_API_BRIDGE   the API Client's built bridge directory (native/build.sh)
 *   FP_CA_FILE      CA bundle (default /etc/ssl/certs/ca-certificates.crt)
 * and on REXX_PATH: oorexx_api_client_v0.4.1/src, the Foreign Runtime's rexx
 * directory, oorexx_crypto_v0.1/src; LD_LIBRARY_PATH: the Foreign Runtime's
 * build directory and the bridge.
 *
 * FpHttp~kitCheck answers before anything is fetched; each fetch returns the
 * response with its evidence: URL, status, bytes, SHA-512 (the estate's own
 * crypto.cls), retrieval time.
 *
 * Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-07.
 */
::requires 'ApiHttpTransport.cls'
::requires 'crypto.cls'

::class FpHttp public
::attribute transport get

::method kitCheck class
  /* an Array of "ok|fail name detail" lines; all ok means fetching can start */
  out = .array~new
  bridge = value('FP_API_BRIDGE',, 'ENVIRONMENT')
  ca = value('FP_CA_FILE',, 'ENVIRONMENT')
  if ca == '' then ca = '/etc/ssl/certs/ca-certificates.crt'
  if bridge == '' then out~append('fail bridge FP_API_BRIDGE is not set (API Client native/build.sh output)')
  else if \SysIsFileDirectory(bridge) then out~append('fail bridge' bridge 'is not a directory')
  else out~append('ok   bridge' bridge)
  if stream(ca, 'c', 'query exists') == '' then out~append('fail ca' ca 'not found')
  else out~append('ok   ca' ca)
  return out

::method init
  expose transport
  cfg = .ApiHttpTransportConfig~new
  cfg~bridgeDirectory = value('FP_API_BRIDGE',, 'ENVIRONMENT')
  ca = value('FP_CA_FILE',, 'ENVIRONMENT')
  if ca == '' then ca = '/etc/ssl/certs/ca-certificates.crt'
  cfg~caFile = ca
  cfg~readTimeout = 120
  cfg~httpVersionPolicy = 'HTTP1_ONLY'   /* no nghttp2 needed on the node */
  cfg~userAgent = 'Alchemy-SLAM450-FlightPlanner/0.1 (ooRexx ApiClient)'
  transport = .ApiHttpsTransport~new(cfg)

::method get
  expose transport
  use strict arg id, url
  req = .ApiRequest~new(id, 'GET', url)
  resp = transport~execute(req)
  ev = .directory~new
  ev['URL'] = url
  ev['STATUS'] = resp~status
  ev['ERROR'] = resp~errorCode
  ev['BYTES'] = resp~body~length
  ev['SHA512'] = .CryptoHash~hashString(resp~body, 'SHA512')
  ev['RETRIEVED'] = .DateTime~new~toTimeZone(0)~isoDate~left(19)'Z'
  return .array~of(resp, ev)
