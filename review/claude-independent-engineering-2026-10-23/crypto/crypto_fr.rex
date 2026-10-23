/* Probe: Crypto v0.8.3 SHA-256 via Foreign Runtime v0.22.6 vs pure ooRexx. Claude (Opus 5.5). */
signal on syntax name onSyntax
data = copies("method body text ", 64)          -- ~1 KB, a typical method
t0 = time("E"); pure = .SHA256~new(data)~digest; tPure = time("E") - t0
installed = .CryptoForeignRuntimeInstaller~install
say "foreign runtime provider installed:" installed
t0 = time("E")
do i = 1 to 200
  fast = .SHA256~new(data)~digest
end
tFast = (time("E") - t0) / 200
say "pure ooRexx SHA-256 (1 KB): " format(tPure,,4) "s"
say "foreign runtime SHA-256:    " format(tFast,,6) "s per hash (200 runs)"
say "digests equal:" (pure == fast) " speedup x" || format(tPure / max(tFast, 0.000001),,0)
say "known vector abc ok:" (.SHA256~new("abc")~digest = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
exit 0
onSyntax:
  say "SYNTAX rc="rc "sigl="sigl "C="condition("C") "D="condition("D")
  co = condition("O"); if co~hasIndex("ADDITIONAL") then do a over co["ADDITIONAL"]; say "  A="a; end
  exit 1
::requires "crypto.cls"
::requires "CryptoForeignRuntimeProvider.cls"
