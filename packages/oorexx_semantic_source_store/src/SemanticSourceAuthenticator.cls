/*
 * Semantic Source Control - signed challenge authenticator.
 *
 * IMPORTANT: this class does not own keys or permissions.  It stores challenge
 * lifecycle and delegates key resolution/signature validation/permission checks
 * to the existing security framework through the injected securityAuthority.
 *
 * Expected securityAuthority contract:
 *   resolvePublicKey(keyId) -> Directory { principal_id, public_key, status }
 *   verifyEd25519(publicKey, canonicalMessage, signatureB64Url) -> boolean
 *   isPermitted(principalId, actionName, resourceId) -> boolean
 *
 * Production adapters MUST implement those methods with Security Effect / Bouncer
 * and Access Permissions, not with an SSC-local trust or ACL database.
 */

::class SemanticSourceAuthenticator public

::constant DEFAULT_AUDIENCE "semantic-source-mcp"

::method init
  use strict arg sql, securityAuthority, clock = .nil
  self~sql = sql
  self~securityAuthority = securityAuthority
  self~clock = clock

::attribute sql get
::attribute sql set private
::attribute securityAuthority get
::attribute securityAuthority set private
::attribute clock get
::attribute clock set private

::method issueChallenge
  use strict arg challengeId, keyId, nonce, issuedAt, expiresAt, actionName = "", resourceId = "", audience = ""
  if audience = "" then audience = self~DEFAULT_AUDIENCE
  if challengeId = "" then raise syntax 88.900 array("challengeId must not be empty")
  if keyId = "" then raise syntax 88.900 array("keyId must not be empty")
  if nonce = "" then raise syntax 88.900 array("nonce must not be empty")
  if audience = "" then raise syntax 88.900 array("audience must not be empty")

  keyRecord = self~securityAuthority~resolvePublicKey(keyId)
  if keyRecord == .nil then raise syntax 88.900 array("unknown key: " || keyId)
  if self~field(keyRecord, "status", "")~upper \= "ACTIVE" then,
    raise syntax 88.900 array("key is not active: " || keyId)

  statement = "INSERT INTO ssc_auth_challenge (challenge_id,key_id,audience,action_name,resource_id,nonce,issued_at,expires_at,consumed_at,status) VALUES (" ||,
              self~quote(challengeId) || "," || self~quote(keyId) || "," || self~quote(audience) || "," || self~quote(actionName) || "," ||,
              self~quote(resourceId) || "," || self~quote(nonce) || "," || self~quote(issuedAt) || "," || self~quote(expiresAt) || ",'','ISSUED')"
  ignore = self~query(statement)

  challenge = .directory~new
  challenge["schema"] = "semantic-source.auth.challenge/1"
  challenge["challenge_id"] = challengeId
  challenge["key_id"] = keyId
  challenge["audience"] = audience
  challenge["action"] = actionName
  challenge["resource_id"] = resourceId
  challenge["nonce"] = nonce
  challenge["issued_at"] = issuedAt
  challenge["expires_at"] = expiresAt
  challenge["principal_id"] = self~field(keyRecord, "principal_id", "")
  challenge["canonical_message"] = self~canonicalMessage(challenge)
  return challenge

::method authenticate
  use strict arg challengeId, signatureB64Url, nowValue
  challenge = self~loadChallenge(challengeId)
  if self~field(challenge, "status", "") \= "ISSUED" then,
    raise syntax 88.900 array("challenge is not usable: " || challengeId)
  if nowValue > self~field(challenge, "expires_at", "") then do
    ignore = self~markChallenge(challengeId, "EXPIRED", "")
    raise syntax 88.900 array("challenge expired: " || challengeId)
  end

  keyId = self~field(challenge, "key_id", "")
  keyRecord = self~securityAuthority~resolvePublicKey(keyId)
  if keyRecord == .nil then raise syntax 88.900 array("unknown key: " || keyId)
  if self~field(keyRecord, "status", "")~upper \= "ACTIVE" then,
    raise syntax 88.900 array("key is not active: " || keyId)

  envelope = .directory~new
  envelope["challenge_id"] = self~field(challenge, "challenge_id", "")
  envelope["key_id"] = keyId
  envelope["audience"] = self~field(challenge, "audience", "")
  envelope["action"] = self~field(challenge, "action_name", "")
  envelope["resource_id"] = self~field(challenge, "resource_id", "")
  envelope["nonce"] = self~field(challenge, "nonce", "")
  envelope["issued_at"] = self~field(challenge, "issued_at", "")
  envelope["expires_at"] = self~field(challenge, "expires_at", "")
  canonical = self~canonicalMessage(envelope)

  publicKey = self~field(keyRecord, "public_key", "")
  if \self~securityAuthority~verifyEd25519(publicKey, canonical, signatureB64Url) then do
    ignore = self~audit("AUTHENTICATE", self~field(keyRecord, "principal_id", ""), keyId, challengeId, "", self~field(challenge, "action_name", ""), self~field(challenge, "resource_id", ""), "DENIED", "invalid signature", nowValue)
    raise syntax 88.900 array("invalid authenticator signature")
  end

  principalId = self~field(keyRecord, "principal_id", "")
  actionName = self~field(challenge, "action_name", "")
  resourceId = self~field(challenge, "resource_id", "")
  if actionName \= "" then do
    if \self~securityAuthority~isPermitted(principalId, actionName, resourceId) then do
      ignore = self~markChallenge(challengeId, "CONSUMED", nowValue)
      ignore = self~audit("AUTHORIZE", principalId, keyId, challengeId, "", actionName, resourceId, "DENIED", "permission denied", nowValue)
      raise syntax 88.900 array("principal is not permitted for action: " || actionName)
    end
  end

  ignore = self~markChallenge(challengeId, "CONSUMED", nowValue)
  auth = .directory~new
  auth["principal_id"] = principalId
  auth["key_id"] = keyId
  auth["audience"] = self~field(challenge, "audience", "")
  auth["action"] = actionName
  auth["resource_id"] = resourceId
  auth["authenticated_at"] = nowValue
  ignore = self~audit("AUTHENTICATE", principalId, keyId, challengeId, "", actionName, resourceId, "ALLOWED", "signed challenge accepted", nowValue)
  return auth

::method createSession
  use strict arg authenticatedContext, sessionId, accessToken, issuedAt, expiresAt, audience = ""
  if authenticatedContext == .nil then raise syntax 88.900 array("authenticated context is required")
  principalId = self~field(authenticatedContext, "principal_id", "")
  keyId = self~field(authenticatedContext, "key_id", "")
  authAudience = self~field(authenticatedContext, "audience", "")
  if audience = "" then audience = authAudience
  if principalId = "" then raise syntax 88.900 array("authenticated principal is required")
  if sessionId = "" then raise syntax 88.900 array("sessionId must not be empty")
  if accessToken = "" then raise syntax 88.900 array("accessToken must not be empty")
  if audience = "" then raise syntax 88.900 array("audience must not be empty")
  if authAudience \= "" & authAudience \= audience then raise syntax 88.900 array("session audience mismatch")

  tokenHash = self~securityAuthority~hashOpaqueToken(accessToken)
  if tokenHash = "" then raise syntax 88.900 array("security authority returned empty token hash")
  authContext = "SIGNED_CHALLENGE:" || self~field(authenticatedContext, "authenticated_at", issuedAt)
  statement = "INSERT INTO ssc_auth_session (session_id,access_token_hash,principal_id,key_id,audience,issued_at,expires_at,status,auth_context) VALUES (" ||,
              self~quote(sessionId) || "," || self~quote(tokenHash) || "," || self~quote(principalId) || "," || self~quote(keyId) || "," ||,
              self~quote(audience) || "," || self~quote(issuedAt) || "," || self~quote(expiresAt) || ",'ACTIVE'," || self~quote(authContext) || ")"
  ignore = self~query(statement)
  ignore = self~audit("SESSION_CREATE", principalId, keyId, "", sessionId, "", "", "ALLOWED", "opaque bearer session created", issuedAt)

  session = .directory~new
  session["schema"] = "semantic-source.auth.session/1"
  session["session_id"] = sessionId
  session["access_token"] = accessToken
  session["principal_id"] = principalId
  session["audience"] = audience
  session["issued_at"] = issuedAt
  session["expires_at"] = expiresAt
  return session

::method resolveSession
  use strict arg accessToken, nowValue, audience = ""
  if accessToken = "" then raise syntax 88.900 array("bearer token is required")
  tokenHash = self~securityAuthority~hashOpaqueToken(accessToken)
  rs = self~query("SELECT * FROM ssc_auth_session WHERE access_token_hash=" || self~quote(tokenHash))
  if rs~rows~items = 0 then raise syntax 88.900 array("bearer session not found")
  session = rs~rows[1]
  if self~field(session, "status", "") \= "ACTIVE" then raise syntax 88.900 array("bearer session is not active")
  if nowValue > self~field(session, "expires_at", "") then do
    ignore = self~query("UPDATE ssc_auth_session SET status='EXPIRED' WHERE session_id=" || self~quote(self~field(session, "session_id", "")))
    raise syntax 88.900 array("bearer session expired")
  end
  if audience \= "" & self~field(session, "audience", "") \= audience then raise syntax 88.900 array("bearer session audience mismatch")

  keyId = self~field(session, "key_id", "")
  keyRecord = self~securityAuthority~resolvePublicKey(keyId)
  if keyRecord == .nil then raise syntax 88.900 array("session key no longer resolves")
  if self~field(keyRecord, "status", "")~upper \= "ACTIVE" then raise syntax 88.900 array("session key is no longer active")
  return session

::method revokeSession
  use strict arg sessionId, nowValue
  rs = self~query("SELECT * FROM ssc_auth_session WHERE session_id=" || self~quote(sessionId))
  if rs~rows~items = 0 then raise syntax 88.900 array("session not found: " || sessionId)
  session = rs~rows[1]
  ignore = self~query("UPDATE ssc_auth_session SET status='REVOKED' WHERE session_id=" || self~quote(sessionId))
  ignore = self~audit("SESSION_REVOKE", self~field(session, "principal_id", ""), self~field(session, "key_id", ""), "", sessionId, "", "", "ALLOWED", "session revoked", nowValue)
  return 1

::method authorizeBearerAction
  use strict arg accessToken, nowValue, actionName, resourceId = "", audience = ""
  session = self~resolveSession(accessToken, nowValue, audience)
  principalId = self~field(session, "principal_id", "")
  if \self~securityAuthority~isPermitted(principalId, actionName, resourceId) then do
    ignore = self~audit("AUTHORIZE", principalId, self~field(session, "key_id", ""), "", self~field(session, "session_id", ""), actionName, resourceId, "DENIED", "permission denied", nowValue)
    raise syntax 88.900 array("principal is not permitted for action: " || actionName)
  end
  ignore = self~audit("AUTHORIZE", principalId, self~field(session, "key_id", ""), "", self~field(session, "session_id", ""), actionName, resourceId, "ALLOWED", "bearer action authorised", nowValue)
  return session

::method authorizeSessionAction
  use strict arg principalId, actionName, resourceId = ""
  if \self~securityAuthority~isPermitted(principalId, actionName, resourceId) then,
    raise syntax 88.900 array("principal is not permitted for action: " || actionName)
  return 1

::method canonicalMessage
  use strict arg challenge
  -- Exact ordering is part of the authenticator protocol.  Values are UTF-8 text
  -- and LF-delimited.  Python helper emits the identical byte sequence.
  return "SSC-AUTH-1" || "0A"x ||,
         self~field(challenge, "challenge_id", "") || "0A"x ||,
         self~field(challenge, "key_id", "") || "0A"x ||,
         self~field(challenge, "audience", "") || "0A"x ||,
         self~field(challenge, "action", self~field(challenge, "action_name", "")) || "0A"x ||,
         self~field(challenge, "resource_id", "") || "0A"x ||,
         self~field(challenge, "nonce", "") || "0A"x ||,
         self~field(challenge, "issued_at", "") || "0A"x ||,
         self~field(challenge, "expires_at", "")

::method loadChallenge private
  use strict arg challengeId
  rs = self~query("SELECT * FROM ssc_auth_challenge WHERE challenge_id=" || self~quote(challengeId))
  if rs~rows~items = 0 then raise syntax 88.900 array("challenge not found: " || challengeId)
  return rs~rows[1]

::method markChallenge private
  use strict arg challengeId, status, consumedAt
  ignore = self~query("UPDATE ssc_auth_challenge SET status=" || self~quote(status) || ", consumed_at=" || self~quote(consumedAt) || " WHERE challenge_id=" || self~quote(challengeId))

::method audit private
  use strict arg eventKind, principalId, keyId, challengeId, sessionId, actionName, resourceId, outcome, detail, eventTime
  eventId = challengeId || ":" || eventKind || ":" || outcome || ":" || eventTime
  statement = "INSERT INTO ssc_auth_event (event_id,event_time,event_kind,principal_id,key_id,challenge_id,session_id,action_name,resource_id,outcome,detail) VALUES (" ||,
              self~quote(eventId) || "," || self~quote(eventTime) || "," || self~quote(eventKind) || "," || self~quote(principalId) || "," ||,
              self~quote(keyId) || "," || self~quote(challengeId) || "," || self~quote(sessionId) || "," || self~quote(actionName) || "," ||,
              self~quote(resourceId) || "," || self~quote(outcome) || "," || self~quote(detail) || ")"
  ignore = self~query(statement)

::method field private
  use strict arg record, key, defaultValue
  if record == .nil then return defaultValue
  if \record~hasIndex(key) then return defaultValue
  value = record[key]
  if value == .nil then return defaultValue
  return value

::method query private
  use strict arg statement
  dbResult = self~sql~execute(statement)
  if dbResult~status = "SUCCESS" then return dbResult
  raise syntax 88.900 array("Database operation failed: " || statement || "; " || dbResult~message)

::method quote private
  use strict arg value
  if value == .nil then value = ""
  return "'" || value~changestr("'", "''") || "'"

