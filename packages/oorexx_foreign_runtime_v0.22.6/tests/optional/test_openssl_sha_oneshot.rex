lib=.foreign~load('openssl_sha_oneshot.bridge.json')
payload='00610062ff00010203'x
out256=.foreign~buffer(32)
out512=.foreign~buffer(64)
ignored=lib~sha256(payload,payload~length,out256)
ignored=lib~sha512(payload,payload~length,out512)
expected256='6b7f2d24560b2fc85dfb3d33882e5b6b4e88608c88e04bcd2c4e6cde6fd75640'
expected512='d997031ce9d079463f8bc3cec222f08d1337a44df92557da8350a34848b7284c1a89571d8ca524d6c07da2d87ed09d1a6a0bb902e535f0e9145ef4989b9f416f'
if out256~hex<>expected256 then call fail 'SHA-256 binary exact mismatch:' out256~hex
if out512~hex<>expected512 then call fail 'SHA-512 binary exact mismatch:' out512~hex
out256~close; out512~close; lib~close
say 'PASS OpenSSL one-shot SHA-256/SHA-512 exact binary bytes via Foreign Runtime'
exit 0
fail: procedure
  parse arg message
  say 'FAIL' message
  exit 1
::requires '../../rexx/foreign.cls'
