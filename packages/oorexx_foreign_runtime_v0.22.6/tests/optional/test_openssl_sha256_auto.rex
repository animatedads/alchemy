/* Automatic out-parameter OpenSSL EVP SHA-256 conformance. */
lib=.foreign~load('openssl_sha256.bridge.json')
ctx=lib~ctx_new
md=lib~sha256
if lib~digest_init(ctx,md,.nil)<>1 then exit 1
if lib~digest_update(ctx,'abc',3)<>1 then exit 2
r=lib~digest_final(ctx)
if \r~isA(.ForeignResult) then exit 3
if r~returnValue<>1 then exit 4
if r~out('digestLength')<>32 then exit 5
digest=r~out('digest')
expected='ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
if digest~hex<>expected then do
  say 'FAIL auto SHA256' digest~hex
  exit 6
end
say 'SHA256-AUTO' digest~hex
say 'PASS automatic OpenSSL EVP SHA-256 outputs via Foreign Runtime'
digest~close
ctx~close
lib~close
exit 0
::requires '../../rexx/foreign.cls'
