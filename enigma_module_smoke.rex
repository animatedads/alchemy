/* enigma_module_smoke.rex
 * Manual smoke for EnigmaM3CipherSession as a CryptoStream-compatible module.
 */

machine = .EnigmaM3CipherSession~new("I", "II", "III", "A", "A", "A", "AM FI NV PS TU WZ")

split = machine~updateWrite("HELLO") || machine~updateWrite("WORLD")

machine~reset("A", "A", "A")
whole = machine~updateWrite("HELLOWORLD")

say "split: " split
say "whole: " whole
if split = whole then say "PASS Enigma streaming continuity"
else say "FAIL Enigma split/whole mismatch"

machine~reset("A", "A", "A")
plain = machine~updateRead(whole)
say "plain: " plain
if plain = "HELLOWORLD" then say "PASS Enigma reciprocal decrypt"
else say "FAIL Enigma decrypt mismatch"

::requires "crypto.cls"
