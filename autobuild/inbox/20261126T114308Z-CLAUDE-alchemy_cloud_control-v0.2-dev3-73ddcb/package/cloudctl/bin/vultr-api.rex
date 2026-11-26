/* vultr-api.rex -- one Vultr API v2 call for Cloud Control, with the API key kept off every command line.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 7 November 2026.
 *
 *   rexx vultr-api.rex METHOD PATH [BODY_BASE64]     response body on stdout; curl's rc (22 = HTTP error)
 *   rexx vultr-api.rex --check                         rc 0 when a usable key is found, else 3 with the reason
 *
 * The key comes from, in order: the file named by VULTR_API_KEY_FILE; the VULTR_API_KEY variable (as the
 * workstation cloudctl.sh accepted); ~/.config/vultr/api-key.  A key file must be mode 600 or 400.  The key goes
 * to curl on stdin as a header (-H @-), so it is never in argv, ps, the ledger or the events log.  The JSON body
 * arrives base64-encoded (one argument, whatever it contains) and is handed to curl in a mode-600 file.
 * VULTR_API_BASE overrides https://api.vultr.com/v2 (tests).
 */
parse arg method path b64 .
if method='' then do
  .error~lineout('usage: rexx vultr-api.rex METHOD PATH [BODY_BASE64] | --check')
  exit 4
end
key=findKey()
if key='' then exit 3
if method='--check' then exit 0

base=value('VULTR_API_BASE', , 'ENVIRONMENT')
if base='' then base='https://api.vultr.com/v2'
headers=.array~of('Authorization: Bearer' key, 'Accept: application/json')
cmd='curl -fsS -X' method '-H @-'
bodyFile=''
if b64<>'' then do
  tmp=value('TMPDIR', , 'ENVIRONMENT')
  if tmp='' then tmp='/tmp'
  bodyFile=SysTempFileName(tmp'/vultr-api.?????.json')
  if bodyFile='' then bodyFile=tmp'/vultr-api.'SysQueryProcess('PID')'.json'
  call writeBody bodyFile, b64~decodeBase64
  headers~append('Content-Type: application/json')
  cmd=cmd '--data-binary @'quote(bodyFile)
end
cmd=cmd quote(base||path)
address system cmd with input using (headers)
r=rc
if bodyFile<>'' then call SysFileDelete bodyFile
exit r

/* The key, or '' with the reason on stderr. */
findKey: procedure
  f=value('VULTR_API_KEY_FILE', , 'ENVIRONMENT')
  if f='' then do
    k=value('VULTR_API_KEY', , 'ENVIRONMENT')
    if k<>'' then return space(k, 0)
    f=value('HOME', , 'ENVIRONMENT')'/.config/vultr/api-key'
  end
  if \SysFileExists(f) then do
    .error~lineout('vultr-api: no Vultr API key: no file' f '(set VULTR_API_KEY_FILE, or put the key there, mode 600)')
    return ''
  end
  address system 'stat -c %a' quote(f) with output stem m.
  if m.0=0 then m.1='?'
  if wordpos(m.1, '600 400')=0 then do
    .error~lineout('vultr-api: key file' f 'is mode' m.1': chmod 600 it')
    return ''
  end
  s=.stream~new(f)
  s~open('read')
  k=s~charin(1, s~chars)
  s~close
  k=space(k~translate(' ', '0D0A09'x), 0)
  if k='' then .error~lineout('vultr-api: key file' f 'is empty')
  return k

writeBody: procedure
  use strict arg file, text
  address system 'umask 077 && : >' quote(file)
  s=.stream~new(file)
  s~open('write replace')
  s~charout(text)
  s~close
  return

quote: procedure
  use strict arg s
  return "'"s~changeStr("'", "'\''")"'"
