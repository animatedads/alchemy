#!/usr/bin/env rexx
/* autobuild_config.rex -- show or change one key of the Autobuild config.json.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 2026-11-14.
 * Replaces the python3 -c one-liners of the v0.5.1 install procedure.
 *
 *   rexx autobuild_config.rex show [CONFIG]
 *   rexx autobuild_config.rex set KEY VALUE [CONFIG]
 *
 * "set rexx auto" stores the absolute path of the rexx found on PATH.
 * CONFIG defaults to ~/alchemy-autobuild/config.json.  VALUE true/false is
 * written as a JSON boolean, a whole number as a number, anything else as a
 * string.  Only the keys below may be set, so a typo cannot add a key the
 * service silently ignores.  Every change is logged before and after.
 */
parse arg verb rest
known = "git_intake python_gate python_gate_script rexx poll_seconds git_poll_seconds"
select
  when verb == "show" then parse var rest path .
  when verb == "set" then parse var rest key value path .
  otherwise call usage
end
if path == "" then path = value("HOME",, "ENVIRONMENT")"/alchemy-autobuild/config.json"
if \sysFileExists(path) then do
  .error~lineout("autobuild_config: no config at" path)
  exit 2
end
c = .json~fromJsonFile(path)
if verb == "show" then do
  say .json~toJSON(c, .true)
  exit 0
end
if key == "" | value == "" then call usage
if wordpos(key, known) == 0 then do
  .error~lineout("autobuild_config: unknown key" key"; known keys:" known)
  exit 2
end
if key == "python_gate" & wordpos(value, "enforce advisory") == 0 then do
  .error~lineout("autobuild_config: python_gate must be enforce or advisory")
  exit 2
end
if key == "rexx" & value == "auto" then do        -- systemd's PATH is short: store an absolute path
  value = sysSearchPath("PATH", "rexx")
  if value == "" then do
    .error~lineout("autobuild_config: rexx not found on PATH")
    exit 2
  end
end
old = "(absent)"
if c~hasIndex(key) then do
  old = c[key]~string
  if c[key]~isA(.JsonBoolean) then old = c[key]~makeJSON
end
select
  when value == "true" then c[key] = .JsonBoolean~true
  when value == "false" then c[key] = .JsonBoolean~false
  when value~datatype("W") then c[key] = value
  otherwise c[key] = .JsonString~new(value)
end
.json~toJsonFile(path, c, .true)
say "autobuild_config:" key "was" old "now" value "in" path
exit 0

usage:
  .error~lineout("usage: rexx autobuild_config.rex show [CONFIG]")
  .error~lineout("       rexx autobuild_config.rex set KEY VALUE [CONFIG]")
  exit 2

::requires "json.cls"
