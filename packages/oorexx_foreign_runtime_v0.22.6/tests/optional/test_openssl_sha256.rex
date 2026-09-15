lib=.foreign~load('openssl_sha256.bridge.json')
ctx=lib~ctx_new
md=lib~sha256
if \ctx~isA(.ForeignObject) then call fail 'ctx_new did not return ForeignObject'
if ctx~type<>'EVP_MD_CTX' then call fail 'ctx type'
if ctx~ownership<>'owned' then call fail 'ctx ownership'
if md~ownership<>'borrowed' then call fail 'md ownership'
if lib~digest_init(ctx,md,.nil)<>1 then call fail 'EVP_DigestInit_ex'
if lib~digest_update(ctx,'abc',3)<>1 then call fail 'EVP_DigestUpdate'
digest=.foreign~buffer(32)
digestLen=.foreign~buffer(4)
if lib~digest_final(ctx,digest,digestLen)<>1 then call fail 'EVP_DigestFinal_ex'
expected='ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
if digestLen~u32<>32 then call fail 'digest length'
if digest~hex<>expected then call fail 'SHA-256 digest mismatch:' digest~hex
ctx~close
if \ctx~closed then call fail 'owned ctx close'
md~close
if \md~closed then call fail 'borrowed md close bookkeeping'
digest~close; digestLen~close; lib~close
say 'SHA256' expected
say 'PASS OpenSSL EVP SHA-256 via Foreign Runtime'
exit 0
fail: procedure
  parse arg message
  say 'FAIL' message
  exit 1
::requires '../../rexx/foreign.cls'
