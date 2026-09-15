call main
exit 0
main:
  call assertEq "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", .SHA256~new("")~digest, "SHA-256 empty"
  call assertEq "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", .SHA256~new("abc")~digest, "SHA-256 abc"
  call assertEq "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1", .SHA256~new("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq")~digest, "SHA-256 long vector"
  sh = .SHA256~new("a"); sh~update("b"); sh~update("c")
  call assertEq "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", sh~digest, "SHA-256 streaming"
  multi = .SHA256~new("a"~copies(17)); multi~update("a"~copies(33)); multi~update("a"~copies(50))
  call assertEq "2816597888e4a0d3a36b82b83316ab32680eb8f00f8cd3b904d681246d285a0e", multi~digest, "SHA-256 multi-block streaming"
  call assertEq "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", .CryptoHash~hashString("abc", "SHA256"), "CryptoHash SHA-256 convenience"
  say "PASS test_sha256"
  return
assertEq: procedure; use arg e,a,label; if e \== a then raise syntax 88.900 array(label || " expected=" || e || " actual=" || a); return
::requires "crypto.cls"
