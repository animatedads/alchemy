/* CryptoForeignRuntimeProvider.cls
 * Hybrid high-priority in-process Runtime Reference provider.
 *
 * Standard expensive operations bind directly to libcrypto through Foreign
 * Runtime v0.11/libffi.  A deliberately small compatibility shim remains only
 * for semantics that intentionally differ from standard OpenSSL operations:
 * raw Edwards25519 arithmetic, unclamped X25519, and the package's experimental
 * Goldilocks/Ed448 keypair.
 */

::class CryptoForeignRuntimeTarget public
::attribute providerId get
::attribute implementationId get
::attribute providerPath get

::method init
  expose providerId implementationId directDefinitionPath compatDefinitionPath directLib compatLib providerPath
  use strict arg directDefinitionPath, compatDefinitionPath, providerId = "foreign.openssl.crypto", implementationId = "openssl.libcrypto.hybrid.v2"
  directLib = .nil
  compatLib = .nil
  providerPath = ""

::method ensureDirectLibrary private
  expose directDefinitionPath directLib providerPath
  if directLib \== .nil then return directLib
  directLib = .foreign~load(directDefinitionPath)
  providerPath = directLib~providerPath
  return directLib

::method ensureCompatLibrary private
  expose compatDefinitionPath compatLib providerPath
  if compatLib \== .nil then return compatLib
  compatLib = .foreign~load(compatDefinitionPath)
  if providerPath == "" then providerPath = compatLib~providerPath
  return compatLib

::method runtimeImplementationInvoke unguarded
  expose providerId implementationId
  use strict arg operationId, request, contract
  if contract~executionClass \= "PURE" then return .RuntimeProviderResult~failure("REJECTED_BEFORE_EXECUTION", "foreign crypto provider only handles PURE operations", providerId, implementationId)

  supported = "crypto.sha256.digest/1 crypto.sha512.digest/1 crypto.hmac.sha512.digest/1 crypto.chacha20.crypt/1 crypto.edwards25519.add/1 crypto.edwards25519.multiply/1 crypto.ed25519.keypair/1 crypto.ed25519.sign/1 crypto.ed25519.verify/1 crypto.ed448.keypair/1 crypto.x25519.public_key/1 crypto.x25519.shared_secret/1 crypto.rsa.keypair/1 crypto.rsa.generate_keypair/1 crypto.rsa.encrypt/1 crypto.rsa.decrypt/1 crypto.rsa.sign/1 crypto.rsa.verify/1"
  if wordpos(operationId, supported) = 0 then return .RuntimeProviderResult~failure("UNSUPPORTED", "operation not implemented", providerId, implementationId)

  phase = "LOAD"
  resources = .array~new
  signal on syntax name foreignFailure

  /* ---- Direct libcrypto operations ---------------------------------- */
  if wordpos(operationId, "crypto.sha256.digest/1 crypto.sha512.digest/1 crypto.hmac.sha512.digest/1 crypto.chacha20.crypt/1 crypto.ed25519.keypair/1 crypto.ed25519.sign/1 crypto.ed25519.verify/1 crypto.rsa.keypair/1 crypto.rsa.generate_keypair/1 crypto.rsa.encrypt/1 crypto.rsa.decrypt/1 crypto.rsa.sign/1 crypto.rsa.verify/1") > 0 then
    library = self~ensureDirectLibrary

  if operationId == "crypto.sha256.digest/1" | operationId == "crypto.sha512.digest/1" then do
    phase = "INPUT"
    if \request~hasIndex("data_hex") then return self~fail(resources, "MALFORMED_RESPONSE", "SHA request missing data_hex")
    data = rx_foreign_request_tagged_bytes(request["data_hex"])
    if data == .nil then return self~fail(resources, "MALFORMED_RESPONSE", "SHA data is not exact bytes or tagged hex")
    if operationId == "crypto.sha256.digest/1" then size = 32; else size = 64
    out = self~keep(resources, .foreign~buffer(size))
    phase = "INVOKE"
    if size == 32 then rc = library~sha256(data, data~length, out)
    else rc = library~sha512(data, data~length, out)
    if rc = 0 then return self~fail(resources, "REMOTE_FAULT", "OpenSSL digest failed")
    value = out~hex
    return self~success(resources, value)
  end

  if operationId == "crypto.hmac.sha512.digest/1" then do
    phase = "INPUT"
    if \request~hasIndex("key_hex") | \request~hasIndex("message") then return self~fail(resources, "MALFORMED_RESPONSE", "HMAC request incomplete")
    keyHex = request["key_hex"]~string~lower
    if keyHex == "" | keyHex~length // 2 \= 0 | verify(keyHex,"0123456789abcdef") \= 0 then return self~fail(resources, "REJECTED_BEFORE_EXECUTION", "invalid HMAC key")
    key = x2c(keyHex); message = rx_foreign_request_bytes(request["message"])
    out = self~keep(resources, .foreign~buffer(64))
    outLen = self~keep(resources, library~struct("SizeTBox")); outLen~set("value", 64)
    phase = "INVOKE"
    rc = library~q_mac(.nil,"HMAC",.nil,"SHA512",.nil,key,key~length,message,message~length,out,64,outLen)
    if rc = 0 | outLen~get("value") \= 64 then return self~fail(resources, "REMOTE_FAULT", "OpenSSL HMAC-SHA-512 failed")
    value = out~hex
    return self~success(resources, value)
  end

  if operationId == "crypto.chacha20.crypt/1" then do
    phase = "INPUT"
    if \request~hasIndex("data") | \request~hasIndex("key_hex") | \request~hasIndex("nonce_hex") then return self~fail(resources, "MALFORMED_RESPONSE", "ChaCha20 request incomplete")
    keyHex=request["key_hex"]~string~lower; nonceHex=request["nonce_hex"]~string~lower
    if keyHex~length \= 64 | verify(keyHex,"0123456789abcdef") \= 0 then return self~fail(resources, "REJECTED_BEFORE_EXECUTION", "invalid ChaCha20 key")
    if nonceHex~length \= 24 | verify(nonceHex,"0123456789abcdef") \= 0 then return self~fail(resources, "REJECTED_BEFORE_EXECUTION", "invalid ChaCha20 nonce")
    data=rx_foreign_request_bytes(request["data"])
    if data~length == 0 then return self~success(resources, "")
    key=x2c(keyHex); nonce=x2c(nonceHex); iv="01000000"x || nonce
    ctx=self~keep(resources,library~cipher_ctx_new); cipher=self~keep(resources,library~chacha20_cipher)
    if ctx==.nil | cipher==.nil then return self~fail(resources,"REMOTE_FAULT","OpenSSL ChaCha20 objects unavailable")
    out=self~keep(resources,.foreign~buffer(data~length)); outLen=self~keep(resources,library~struct("I32Box"));outLen~set("value",0)
    final=self~keep(resources,.foreign~buffer(16)); finalLen=self~keep(resources,library~struct("I32Box"));finalLen~set("value",0)
    phase="INVOKE"
    if library~encrypt_init(ctx,cipher,.nil,key,iv) \= 1 then return self~fail(resources,"REMOTE_FAULT","OpenSSL ChaCha20 init failed")
    if library~encrypt_update(ctx,out,outLen,data,data~length) \= 1 then return self~fail(resources,"REMOTE_FAULT","OpenSSL ChaCha20 update failed")
    if library~encrypt_final(ctx,final,finalLen) \= 1 then return self~fail(resources,"REMOTE_FAULT","OpenSSL ChaCha20 final failed")
    if outLen~get("value") \= data~length | finalLen~get("value") \= 0 then return self~fail(resources,"MALFORMED_RESPONSE","OpenSSL ChaCha20 returned an unexpected output length")
    value=out~bytes
    return self~success(resources,value)
  end

  if operationId == "crypto.ed25519.keypair/1" then do
    phase="INPUT"
    if \request~hasIndex("seed_hex") then return self~fail(resources,"MALFORMED_RESPONSE","Ed25519 keypair request incomplete")
    seedHex=request["seed_hex"]~string~lower
    if seedHex~length \= 64 | verify(seedHex,"0123456789abcdef") \= 0 then return self~fail(resources,"REJECTED_BEFORE_EXECUTION","Ed25519 seed must be 32 bytes hex")
    seed=x2c(seedHex)
    pkey=self~keep(resources,library~pkey_private_ed25519(.nil,"ED25519",.nil,seed,seed~length))
    if pkey==.nil then return self~fail(resources,"REMOTE_FAULT","OpenSSL Ed25519 private key creation failed")
    pub=self~keep(resources,.foreign~buffer(32)); pubLen=self~keep(resources,library~struct("SizeTBox"));pubLen~set("value",32)
    phase="INVOKE"
    if library~pkey_get_raw_public(pkey,pub,pubLen) \= 1 | pubLen~get("value") \= 32 then return self~fail(resources,"REMOTE_FAULT","OpenSSL Ed25519 public key extraction failed")
    hash=self~keep(resources,.foreign~buffer(64))
    if library~sha512(seed,seed~length,hash)=0 then return self~fail(resources,"REMOTE_FAULT","OpenSSL Ed25519 scalar hash failed")
    h=hash~bytes
    scalarBytes=bitand(substr(h,1,1),"f8"x) || substr(h,2,30) || bitor(bitand(substr(h,32,1),"7f"x),"40"x)
    d=.Directory~new;d["private"]=seedHex;d["public"]=pub~hex;d["scalar"]=rx_foreign_le_bytes_to_decimal(scalarBytes)
    return self~success(resources,d)
  end

  if operationId == "crypto.ed25519.sign/1" then do
    phase="INPUT"
    if \request~hasIndex("private_hex") | \request~hasIndex("message") then return self~fail(resources,"MALFORMED_RESPONSE","Ed25519 sign request incomplete")
    seedHex=request["private_hex"]~string~lower
    if seedHex~length \= 64 | verify(seedHex,"0123456789abcdef") \= 0 then return self~fail(resources,"REJECTED_BEFORE_EXECUTION","Ed25519 private seed must be 32 bytes hex")
    seed=x2c(seedHex); msg=rx_foreign_request_bytes(request["message"])
    pkey=self~keep(resources,library~pkey_private_ed25519(.nil,"ED25519",.nil,seed,seed~length)); ctx=self~keep(resources,library~md_ctx_new)
    if pkey==.nil | ctx==.nil then return self~fail(resources,"REMOTE_FAULT","OpenSSL Ed25519 sign objects unavailable")
    sig=self~keep(resources,.foreign~buffer(64)); sigLen=self~keep(resources,library~struct("SizeTBox"));sigLen~set("value",64)
    phase="INVOKE"
    if library~digest_sign_init(ctx,.nil,.nil,.nil,pkey) \= 1 then return self~fail(resources,"REMOTE_FAULT","OpenSSL Ed25519 sign init failed")
    if library~digest_sign(ctx,sig,sigLen,msg,msg~length) \= 1 | sigLen~get("value") \= 64 then return self~fail(resources,"REMOTE_FAULT","OpenSSL Ed25519 sign failed")
    value=sig~hex
    return self~success(resources,value)
  end

  if operationId == "crypto.ed25519.verify/1" then do
    phase="INPUT"
    if \request~hasIndex("public_hex") | \request~hasIndex("signature_hex") | \request~hasIndex("message") then return self~fail(resources,"MALFORMED_RESPONSE","Ed25519 verify request incomplete")
    pubHex=request["public_hex"]~string~lower;sigHex=request["signature_hex"]~string~lower
    if pubHex~length \= 64 | verify(pubHex,"0123456789abcdef") \= 0 | sigHex~length \= 128 | verify(sigHex,"0123456789abcdef") \= 0 then return self~success(resources,"false")
    msg=rx_foreign_request_bytes(request["message"]); pub=x2c(pubHex); sig=x2c(sigHex)
    pkey=self~keep(resources,library~pkey_public_ed25519(.nil,"ED25519",.nil,pub,pub~length));ctx=self~keep(resources,library~md_ctx_new)
    if pkey==.nil | ctx==.nil then return self~fail(resources,"REMOTE_FAULT","OpenSSL Ed25519 verify objects unavailable")
    phase="INVOKE"
    if library~digest_verify_init(ctx,.nil,.nil,.nil,pkey) \= 1 then return self~fail(resources,"REMOTE_FAULT","OpenSSL Ed25519 verify init failed")
    rc=library~digest_verify(ctx,sig,sig~length,msg,msg~length)
    if rc==1 then return self~success(resources,"true")
    if rc==0 then return self~success(resources,"false")
    return self~fail(resources,"REMOTE_FAULT","OpenSSL Ed25519 verify failed")
  end

  if operationId == "crypto.rsa.keypair/1" then do
    phase="INPUT"
    if \request~hasIndex("p") | \request~hasIndex("q") | \request~hasIndex("e") then return self~fail(resources,"MALFORMED_RESPONSE","RSA keypair request incomplete")
    phase="INVOKE"
    kp=self~rsaKeypair(resources,library,request["p"],request["q"],request["e"])
    if kp==.nil then return self~fail(resources,"REJECTED_BEFORE_EXECUTION","OpenSSL RSA key construction failed")
    return self~success(resources,kp)
  end

  if operationId == "crypto.rsa.generate_keypair/1" then do
    phase="INPUT"
    if \request~hasIndex("e") then return self~fail(resources,"MALFORMED_RESPONSE","RSA generate request incomplete")
    phase="INVOKE"
    kp=self~rsaGenerate(resources,library,request["e"])
    if kp==.nil then return self~fail(resources,"REMOTE_FAULT","OpenSSL RSA key generation failed")
    return self~success(resources,kp)
  end

  if operationId == "crypto.rsa.encrypt/1" then do
    phase="INPUT"
    if \request~hasIndex("plaintext_hex") | \request~hasIndex("e") | \request~hasIndex("n") then return self~fail(resources,"MALFORMED_RESPONSE","RSA encrypt request incomplete")
    plaintext=x2c(request["plaintext_hex"]~string)
    phase="INVOKE"
    value=self~rsaEncrypt(resources,library,plaintext,request["e"],request["n"])
    if value==.nil then return self~fail(resources,"REJECTED_BEFORE_EXECUTION","RSA plaintext is invalid/too long for modulus")
    return self~success(resources,value)
  end

  if operationId == "crypto.rsa.decrypt/1" then do
    phase="INPUT"
    if \request~hasIndex("ciphertext") | \request~hasIndex("d") | \request~hasIndex("n") then return self~fail(resources,"MALFORMED_RESPONSE","RSA decrypt request incomplete")
    phase="INVOKE"
    value=self~rsaDecrypt(resources,library,request["ciphertext"],request["d"],request["n"])
    if value==.nil then return self~fail(resources,"REMOTE_FAULT","OpenSSL RSA decrypt failed")
    return self~success(resources,value)
  end

  if operationId == "crypto.rsa.sign/1" | operationId == "crypto.rsa.verify/1" then do
    phase="INPUT"
    if operationId == "crypto.rsa.sign/1" then do
      if \request~hasIndex("message_int") | \request~hasIndex("d") | \request~hasIndex("n") then return self~fail(resources,"MALFORMED_RESPONSE","RSA sign request incomplete")
      base=request["message_int"]; exponent=request["d"]
    end
    else do
      if \request~hasIndex("signature") | \request~hasIndex("e") | \request~hasIndex("n") then return self~fail(resources,"MALFORMED_RESPONSE","RSA verify request incomplete")
      base=request["signature"]; exponent=request["e"]
    end
    phase="INVOKE"
    value=self~rsaModExp(resources,library,base,exponent,request["n"])
    if value==.nil then return self~fail(resources,"REMOTE_FAULT","OpenSSL RSA modular exponentiation failed")
    return self~success(resources,value)
  end

  /* ---- Compatibility-only operations -------------------------------- */
  if wordpos(operationId, "crypto.edwards25519.add/1 crypto.edwards25519.multiply/1 crypto.ed448.keypair/1 crypto.x25519.public_key/1 crypto.x25519.shared_secret/1") > 0 then
    library = self~ensureCompatLibrary

  if operationId == "crypto.edwards25519.add/1" | operationId == "crypto.edwards25519.multiply/1" then do
    phase="INPUT"
    if operationId == "crypto.edwards25519.add/1" then do
      if \request~hasIndex("x") | \request~hasIndex("y") | \request~hasIndex("qx") | \request~hasIndex("qy") then return self~fail(resources,"MALFORMED_RESPONSE","Edwards add request incomplete")
      packed=request["x"]~string||"|"||request["y"]~string||"|"||request["qx"]~string||"|"||request["qy"]~string
    end
    else do
      if \request~hasIndex("x") | \request~hasIndex("y") | \request~hasIndex("scalar") then return self~fail(resources,"MALFORMED_RESPONSE","Edwards multiply request incomplete")
      packed=request["x"]~string||"|"||request["y"]~string||"|"||request["scalar"]~string
    end
    out=self~keep(resources,.foreign~buffer(2048));phase="INVOKE"
    if operationId == "crypto.edwards25519.add/1" then rc=library~edwards25519_add(packed,packed~length,out)
    else rc=library~edwards25519_multiply(packed,packed~length,out)
    if rc \= 1 then return self~fail(resources,"REMOTE_FAULT","OpenSSL compatibility Edwards operation failed")
    text=rx_foreign_buffer_text(out); parse var text x "|" y
    d=.Directory~new;d["x"]=x;d["y"]=y
    return self~success(resources,d)
  end

  if operationId == "crypto.ed448.keypair/1" then do
    phase="INPUT"
    if \request~hasIndex("seed_hex") then return self~fail(resources,"MALFORMED_RESPONSE","Ed448 keypair request incomplete")
    seedHex=request["seed_hex"]~string~lower
    if seedHex~length \= 114 | verify(seedHex,"0123456789abcdef") \= 0 then return self~fail(resources,"REJECTED_BEFORE_EXECUTION","Ed448 seed must be 57 bytes hex")
    seed=x2c(seedHex);out=self~keep(resources,.foreign~buffer(89));phase="INVOKE"
    rc=library~ed448_keypair(seed,seed~length,out)
    if rc \= 1 then return self~fail(resources,"REMOTE_FAULT","OpenSSL compatibility Ed448 keypair failed")
    raw=out~bytes
    d=.Directory~new;d["private"]=seedHex;d["public"]=c2x(substr(raw,1,57))~lower;d["scalar"]=rx_foreign_le_bytes_to_decimal(substr(raw,58,32))
    return self~success(resources,d)
  end

  if operationId == "crypto.x25519.public_key/1" | operationId == "crypto.x25519.shared_secret/1" then do
    phase="INPUT"
    if operationId == "crypto.x25519.public_key/1" then do
      if \request~hasIndex("private_scalar") then return self~fail(resources,"MALFORMED_RESPONSE","X25519 public request incomplete")
      packed=request["private_scalar"]~string
    end
    else do
      if \request~hasIndex("my_private") | \request~hasIndex("their_public") then return self~fail(resources,"MALFORMED_RESPONSE","X25519 shared request incomplete")
      packed=request["my_private"]~string||"|"||request["their_public"]~string
    end
    out=self~keep(resources,.foreign~buffer(1024));phase="INVOKE"
    if operationId == "crypto.x25519.public_key/1" then rc=library~x25519_public(packed,packed~length,out)
    else rc=library~x25519_shared(packed,packed~length,out)
    if rc \= 1 then return self~fail(resources,"REMOTE_FAULT","OpenSSL compatibility X25519 ladder failed")
    value=rx_foreign_buffer_text(out)
    return self~success(resources,value)
  end

  return self~fail(resources,"UNSUPPORTED","operation not implemented")

foreignFailure:
  self~closeResources(resources)
  condition = condition("O")
  detail = "Foreign Runtime crypto provider raised a condition"
  if condition \== .nil then do
    if condition~hasIndex("DESCRIPTION") then if condition["DESCRIPTION"] \= "" then detail = condition["DESCRIPTION"]
    if detail == "Foreign Runtime crypto provider raised a condition" then if condition~hasIndex("MESSAGE") then if condition["MESSAGE"] \= "" then detail = condition["MESSAGE"]
  end
  if phase == "LOAD" then code = "UNAVAILABLE"
  else code = "REMOTE_FAULT"
  return .RuntimeProviderResult~failure(code, detail, providerId, implementationId)

::method rsaKeypair private
  use strict arg resources, library, pText, qText, eText
  p=self~bnFromDecimal(resources,library,pText);q=self~bnFromDecimal(resources,library,qText);e=self~bnFromDecimal(resources,library,eText)
  if p==.nil | q==.nil | e==.nil then return .nil
  return self~rsaKeypairFromBns(resources,library,p,q,e)

::method rsaGenerate private
  use strict arg resources, library, eText
  e=self~bnFromDecimal(resources,library,eText)
  if e==.nil then return .nil
  p=self~keep(resources,library~bn_new);q=self~keep(resources,library~bn_new)
  if p==.nil | q==.nil then return .nil
  do tries=1 to 64
    if library~bn_generate_prime(p,1024,0,.nil,.nil,.nil) \= 1 then return .nil
    if library~bn_generate_prime(q,1024,0,.nil,.nil,.nil) \= 1 then return .nil
    if library~bn_cmp(p,q)==0 then iterate
    kp=self~rsaKeypairFromBns(resources,library,p,q,e)
    if kp \== .nil then return kp
  end
  return .nil

::method rsaKeypairFromBns private
  use strict arg resources, library, p, q, e
  ctx=self~keep(resources,library~bn_ctx_new)
  n=self~keep(resources,library~bn_new);phi=self~keep(resources,library~bn_new);pm=self~keep(resources,library~bn_new);qm=self~keep(resources,library~bn_new);d=self~keep(resources,library~bn_new)
  if ctx==.nil | n==.nil | phi==.nil | pm==.nil | qm==.nil | d==.nil then return .nil
  if library~bn_mul(n,p,q,ctx) \= 1 then return .nil
  if library~bn_copy(pm,p)=0 | library~bn_copy(qm,q)=0 then return .nil
  if library~bn_sub_word(pm,1) \= 1 | library~bn_sub_word(qm,1) \= 1 then return .nil
  if library~bn_mul(phi,pm,qm,ctx) \= 1 then return .nil
  if library~bn_mod_inverse(d,e,phi,ctx)=0 then return .nil
  nv=self~bnToInteger(resources,library,n);ev=self~bnToInteger(resources,library,e);dv=self~bnToInteger(resources,library,d);pv=self~bnToInteger(resources,library,phi)
  if nv==.nil | ev==.nil | dv==.nil | pv==.nil then return .nil
  kp=.Directory~new;kp["n"]=nv;kp["e"]=ev;kp["d"]=dv;kp["phi"]=pv
  return kp

::method rsaEncrypt private
  use strict arg resources, library, plaintext, exponentText, modulusText
  e=self~bnFromDecimal(resources,library,exponentText);n=self~bnFromDecimal(resources,library,modulusText)
  ctx=self~keep(resources,library~bn_ctx_new);m=self~keep(resources,library~bn_new);r=self~keep(resources,library~bn_new)
  if e==.nil | n==.nil | ctx==.nil | m==.nil | r==.nil then return .nil
  bits=library~bn_num_bits(n); if bits <= 0 then return .nil
  hexDigits=(bits+3)%4; blockBytes=(hexDigits-1)%2
  if blockBytes <= 0 | plaintext~length >= blockBytes then return .nil
  padLen=blockBytes-plaintext~length; padded=plaintext||copies(d2c(padLen),padLen)
  if library~bn_bin2bn(padded,padded~length,m)=0 then return .nil
  library~bn_set_flags(e,4)
  if library~bn_mod_exp_consttime(r,m,e,n,ctx,.nil) \= 1 then return .nil
  return self~bnToInteger(resources,library,r)

::method rsaDecrypt private
  use strict arg resources, library, ciphertextText, exponentText, modulusText
  c=self~bnFromDecimal(resources,library,ciphertextText);d=self~bnFromDecimal(resources,library,exponentText);n=self~bnFromDecimal(resources,library,modulusText)
  ctx=self~keep(resources,library~bn_ctx_new);m=self~keep(resources,library~bn_new)
  if c==.nil | d==.nil | n==.nil | ctx==.nil | m==.nil then return .nil
  library~bn_set_flags(d,4)
  if library~bn_mod_exp_consttime(m,c,d,n,ctx,.nil) \= 1 then return .nil
  bits=library~bn_num_bits(n); if bits <= 0 then return .nil
  hexDigits=(bits+3)%4; blockBytes=(hexDigits-1)%2
  if blockBytes <= 0 then return .nil
  out=self~keep(resources,.foreign~buffer(blockBytes))
  if library~bn_to_binpad(m,out,blockBytes) \= blockBytes then return .nil
  raw=out~bytes; padLen=c2d(right(raw,1))
  if padLen >= 1 & padLen <= raw~length then raw=left(raw,raw~length-padLen)
  return c2x(raw)~lower

::method rsaModExp private
  use strict arg resources, library, baseText, exponentText, modulusText
  b=self~bnFromDecimal(resources,library,baseText);e=self~bnFromDecimal(resources,library,exponentText);m=self~bnFromDecimal(resources,library,modulusText)
  ctx=self~keep(resources,library~bn_ctx_new);r=self~keep(resources,library~bn_new)
  if b==.nil | e==.nil | m==.nil | ctx==.nil | r==.nil then return .nil
  library~bn_set_flags(e,4)
  if library~bn_mod_exp_consttime(r,b,e,m,ctx,.nil) \= 1 then return .nil
  return self~bnToInteger(resources,library,r)

::method bnFromDecimal private
  use strict arg resources, library, text
  r=library~bn_dec2bn(.foreign~out,text~string)
  if \r~isA(.ForeignResult) then return .nil
  if r~returnValue=0 then return .nil
  b=r~out("bn")
  if b==.nil then return .nil
  return self~keep(resources,b)

::method bnToInteger private
  numeric digits 3000
  use strict arg resources, library, b
  bits=library~bn_num_bits(b)
  if bits < 0 then return .nil
  if bits == 0 then return 0
  size=(bits+7)%8
  out=self~keep(resources,.foreign~buffer(size))
  if library~bn_to_binpad(b,out,size) \= size then return .nil
  return x2d(out~hex)

::method keep private
  use strict arg resources, object
  if object \== .nil then resources~append(object)
  return object

::method closeResources private
  use strict arg resources
  if resources==.nil then return
  do i=resources~items to 1 by -1
    object=resources[i]
    if object \== .nil then if object~hasMethod("CLOSE") then object~close
  end

::method success private
  expose providerId implementationId
  use strict arg resources, value
  self~closeResources(resources)
  return .RuntimeProviderResult~success(value,providerId,implementationId)

::method fail private
  expose providerId implementationId
  use strict arg resources, code, detail
  self~closeResources(resources)
  return .RuntimeProviderResult~failure(code,detail,providerId,implementationId)

::method close
  expose directLib compatLib
  if directLib \== .nil then do
    directLib~close
    directLib=.nil
  end
  if compatLib \== .nil then do
    compatLib~close
    compatLib=.nil
  end


::class CryptoForeignRuntimeInstaller public
::method defaultDirectBridge class
  parse source . . sourceFile
  return filespec("LOCATION", sourceFile) || "/../native/openssl_direct.bridge.json"

::method defaultCompatBridge class
  parse source . . sourceFile
  return filespec("LOCATION", sourceFile) || "/../native/openssl_compat.bridge.json"

/* Compatibility alias retained for callers that only ask where the primary
 * Foreign Runtime definition lives. */
::method defaultBridge class
  return self~defaultDirectBridge

::method install class
  use strict arg directBridgePath = (self~defaultDirectBridge), broker = .nil, priority = 1000, providerId = "foreign.openssl.crypto", compatBridgePath = (self~defaultCompatBridge)
  if broker == .nil then broker = .RuntimeImplementationSwitch~broker
  if broker == .nil then broker = .RuntimeImplementationBroker~new

  target = .CryptoForeignRuntimeTarget~new(directBridgePath, compatBridgePath, providerId, "openssl.libcrypto.hybrid.v2")
  provider = .RuntimeObjectImplementationProvider~new(providerId, target)
  ops = "crypto.sha256.digest/1 crypto.sha512.digest/1 crypto.hmac.sha512.digest/1 crypto.chacha20.crypt/1 crypto.edwards25519.add/1 crypto.edwards25519.multiply/1 crypto.ed25519.keypair/1 crypto.ed25519.sign/1 crypto.ed25519.verify/1 crypto.ed448.keypair/1 crypto.x25519.public_key/1 crypto.x25519.shared_secret/1 crypto.rsa.keypair/1 crypto.rsa.generate_keypair/1 crypto.rsa.encrypt/1 crypto.rsa.decrypt/1 crypto.rsa.sign/1 crypto.rsa.verify/1"
  installed = .Directory~new
  installed["broker"] = broker; installed["target"] = target; installed["provider"] = provider
  do i = 1 to words(ops)
    op = word(ops, i)
    ref = .RuntimeImplementationReference~new(provider, priority, .true, 1, 1)
    broker~register(op, ref)
    installed[op] = ref
  end
  installed["sha256_reference"] = installed["crypto.sha256.digest/1"]
  installed["sha512_reference"] = installed["crypto.sha512.digest/1"]
  .RuntimeImplementationSwitch~installBroker(broker)
  .CryptoLibraryBuild~referenceSwitch = .RuntimeImplementationSwitch
  return installed

::routine rx_foreign_request_bytes public
  use strict arg value
  if value~isa(.RuntimeExactBytes) then return value~bytes
  return value~string

::routine rx_foreign_request_tagged_bytes public
  use strict arg value
  if value~isa(.RuntimeExactBytes) then return value~bytes
  text=value~string
  if left(text,4) \= "hex:" then return .nil
  hex=substr(text,5)~lower
  if hex~length // 2 \= 0 | verify(hex,"0123456789abcdef") \= 0 then return .nil
  return x2c(hex)

::routine rx_foreign_le_bytes_to_decimal public
  numeric digits 2000
  use strict arg bytes
  value = 0
  do i = bytes~length to 1 by -1
    value = value * 256 + c2d(substr(bytes,i,1))
  end
  return value

::routine rx_foreign_buffer_text public
  use strict arg buffer
  bytes=buffer~bytes
  n=pos("00"x,bytes)
  if n > 0 then return left(bytes,n-1)
  return bytes

::requires "crypto.cls"
::requires "RuntimeImplementationReference.cls"
::requires "foreign.cls"
