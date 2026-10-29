/* PreferredModule.cls
   The standard library for the spec language.

   The spec author asks for a capability by name.
   The module knows every reasonable way to provide it.
   It detects what is actually available on the target platform.
   It picks the best option.
   It keeps working when the world changes around it.

   The spec author writes:
     {"op":"impl_use", "name":"preferred.hash.sha256", "args":["text"]}

   They do not know, do not care, whether this becomes:
     - Python 3: hashlib.sha256(text.encode()).hexdigest()
     - Python 2: hashlib.sha256(text).hexdigest()
     - .NET 5+:  SHA256.HashData(Encoding.UTF8.GetBytes(text))
     - .NET 4.x: using(var sha = SHA256.Create()) sha.ComputeHash(...)
     - OORexx:   crypto.cls SHA256 routine

   When Python deprecates something, when a library changes its API,
   when a CVE invalidates a primitive — update ONE entry in the
   preferred library. Every spec that uses that capability gets the
   fix on next generation. The spec never changes.

   Capability names are hierarchical: category.operation
     hash.sha256      hash.md5        hash.sha512
     hash.password    (bcrypt/argon2 — never md5)
     crypto.random    crypto.uuid
     http.get         http.post       http.json_get
     json.parse       json.serialize
     xml.parse        xml.serialize
     file.read        file.write      file.exists     file.lines
     string.split     string.trim     string.replace  string.upper
     string.contains  string.starts   string.ends     string.format
     list.map         list.filter     list.sort       list.contains
     map.get          map.put         map.keys        map.create
     time.now         time.timestamp  time.sleep
     env.get          env.set
     process.run      process.shell
     log.info         log.warn        log.error

   Probe modes:
     STATIC    — use the stated implementation, no detection
     DETECT    — probe the platform before generating
     RESILIENT — generate with try/except fallback chain (safest)
*/

::class PreferredModule public

::method init
  expose _container _capabilities _probeCache _libFile
  use arg container
  _container   = container
  _capabilities = .Directory~new
  _probeCache  = .Directory~new
  _libFile     = 'preferred/preferred.capabilities.json'

::method load
  expose _capabilities _libFile _container
  log = _container~get('logger')
  if stream(_libFile,'c','query exists') = '' then do
    log~warn('[PREFERRED] library file not found:' _libFile)
    self~loadBuiltins
    return
  end
  f = .Stream~new(_libFile)
  content = f~charin(1, f~chars)
  f~close
  signal on syntax name LoadErr
  parsed = .json~new~fromJson(content)
  caps   = parsed~at('capabilities')
  do i = 1 to caps~items
    cap = caps~at(i)
    _capabilities~put(cap, translate(cap~at('name')))
  end
  log~info('[PREFERRED] loaded' _capabilities~items 'capabilities from' _libFile)
  return
LoadErr:
  signal off syntax
  log~error('[PREFERRED] failed to load library — using builtins')
  self~loadBuiltins

::method reload
  expose _capabilities _probeCache
  _capabilities = .Directory~new
  _probeCache   = .Directory~new
  self~load

::method resolve
  /* Resolve a preferred capability name to an impl node for the      */
  /* given language and platform context.                             */
  /* Returns a concrete impl Directory ready for the generator,       */
  /* or .nil if no implementation is available.                       */
  expose _capabilities _probeCache _container
  use arg capName, language, probeMode
  if probeMode = .nil then probeMode = 'RESILIENT'
  cap = _capabilities~at(translate(capName))
  if cap = .nil then return .nil
  impls = cap~at('implementations')
  if impls = .nil then return .nil
  langKey = translate(language)
  candidates = impls~at(langKey)
  if candidates = .nil then return .nil
  /* Candidates are ranked — pick best available                      */
  select
    when translate(probeMode) = 'STATIC' then
      return candidates~at(1)
    when translate(probeMode) = 'DETECT' then
      return self~detectBest(candidates, language)
    otherwise
      return self~buildResilient(cap~at('name'), candidates, language)
  end

::method detectBest private
  expose _probeCache _container
  use arg candidates, language
  xcall = _container~get('transport.local')
  do i = 1 to candidates~items
    c = candidates~at(i)
    detect = c~at('detect')
    if detect = .nil then return c   /* no constraint — use it */
    if self~detectSatisfied(detect, language, xcall) then return c
  end
  return .nil

::method detectSatisfied private
  expose _probeCache
  use arg detect, language, transport
  /* Cache probe results — only probe once per session                */
  cacheKey = translate(language)||'.'||.json~new~toJson(detect)
  cached   = _probeCache~at(cacheKey)
  if cached \= .nil then return cached = 'true'
  satisfied = self~runProbe(detect, language, transport)
  _probeCache~put(satisfied~string, cacheKey)
  return satisfied

::method runProbe private
  use arg detect, language, transport
  moduleCheck = detect~at('module')
  versionReq  = detect~at('version')
  select
    when translate(language) = 'PYTHON' then do
      if moduleCheck \= .nil then do
        xcall = .ExternalCall~new(.nil)
        xcall~command = 'python3'
        xcall~args    = .Array~of('-c', 'import '||moduleCheck||'; print("ok")')
        xcall~transport = transport
        xcall~run
        if xcall~result~exitCode = 0 then return .true
        return .false
      end
      return .true
    end
    when translate(language) = 'DOTNET' then do
      /* .NET capability detection via dotnet --version               */
      xcall = .ExternalCall~new(.nil)
      xcall~command = 'dotnet'
      xcall~args    = .Array~of('--version')
      xcall~transport = transport
      xcall~run
      return xcall~result~exitCode = 0
    end
    otherwise return .true
  end

::method buildResilient private
  /* Build an impl that tries each candidate in rank order,           */
  /* wrapping lower-ranked options in try/except/catch.              */
  /* The generated code self-selects at runtime.                      */
  use arg capName, candidates, language
  if candidates~items = 1 then return candidates~at(1)
  /* Return a synthetic impl with a 'resilient' type that the         */
  /* generator knows how to emit as a fallback chain.                 */
  synth = .Directory~new
  synth~put('resilient',  'type')
  synth~put(candidates,   'chain')
  synth~put(language,     'language')
  synth~put(capName,      'capName')
  return synth


/* ================================================================== */
/* Builtin capability library — the defaults when no file exists      */
/* Covers the essentials. Keep the external file for extensions.      */
/* ================================================================== */
::method loadBuiltins
  expose _capabilities
  self~addCap('hash.sha256',     self~cap_hash_sha256)
  self~addCap('hash.sha512',     self~cap_hash_sha512)
  self~addCap('hash.password',   self~cap_hash_password)
  self~addCap('crypto.random',   self~cap_crypto_random)
  self~addCap('crypto.uuid',     self~cap_crypto_uuid)
  self~addCap('http.get',        self~cap_http_get)
  self~addCap('http.post',       self~cap_http_post)
  self~addCap('http.json_get',   self~cap_http_json_get)
  self~addCap('json.parse',      self~cap_json_parse)
  self~addCap('json.serialize',  self~cap_json_serialize)
  self~addCap('xml.parse',       self~cap_xml_parse)
  self~addCap('file.read',       self~cap_file_read)
  self~addCap('file.write',      self~cap_file_write)
  self~addCap('file.lines',      self~cap_file_lines)
  self~addCap('file.exists',     self~cap_file_exists)
  self~addCap('string.split',    self~cap_string_split)
  self~addCap('string.format',   self~cap_string_format)
  self~addCap('time.now',        self~cap_time_now)
  self~addCap('time.timestamp',  self~cap_time_timestamp)
  self~addCap('log.info',        self~cap_log_info)
  self~addCap('process.run',     self~cap_process_run)
  say '[PREFERRED] builtins loaded:' _capabilities~items 'capabilities'
  /* Extend with Go and Java implementations                           */
  self~extendGoJava

::method addCap private
  expose _capabilities
  use arg name, cap
  cap~put(name, 'name')
  _capabilities~put(cap, translate(name))

/* ── Capability definitions ────────────────────────────────────────── */

::method cap_hash_sha256 private
  cap = .Directory~new
  cap~put('Compute SHA-256 hash of text, return lowercase hex digest', 'abstract')
  cap~put(.Array~of('text'), 'params')
  cap~put('string', 'returns')
  impls = .Directory~new
  py = .Array~new
  py~append(self~impl('STATIC', .Array~of('import hashlib'), -
    'hashlib.sha256({text}.encode("utf-8")).hexdigest()', -
    .nil, 1))
  py2 = .Directory~new; py2~put('python_version','<3')
  py~append(self~impl('STATIC', .Array~of('import hashlib'), -
    'hashlib.sha256({text}).hexdigest()', py2, 2))
  impls~put(py, 'PYTHON')
  dn = .Array~new
  /* .NET 5+: SHA256.HashData exists */
  dn5 = .Directory~new; dn5~put('dotnet_version', '>=5')
  dn~append(self~impl('STATIC', -
    .Array~of('using System.Security.Cryptography;','using System.Text;'), -
    'Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes({text}))).ToLower()', -
    dn5, 1))
  /* .NET 4.x: SHA256.Create() */
  dn~append(self~impl('STATIC', -
    .Array~of('using System.Security.Cryptography;','using System.Text;'), -
    'using(var _h=SHA256.Create()){return BitConverter.ToString(_h.ComputeHash(Encoding.UTF8.GetBytes({text}))).Replace("-","").ToLower();}', -
    .nil, 2))
  impls~put(dn, 'DOTNET')
  oo = .Array~new
  oo~append(self~impl('STATIC', .Array~of('crypto.cls'), -
    'rx_sha256({text})', .nil, 1))
  impls~put(oo, 'OOREXX')
  cap~put(impls, 'implementations')
  return cap

::method cap_hash_password private
  /* NEVER md5. NEVER sha1. Always bcrypt or argon2.                  */
  cap = .Directory~new
  cap~put('Hash a password for storage. Uses bcrypt or argon2. NEVER md5/sha.', 'abstract')
  cap~put(.Array~of('password'), 'params')
  cap~put('string', 'returns')
  impls = .Directory~new
  py = .Array~new
  /* Prefer argon2, fallback to bcrypt, fallback to pbkdf2 (stdlib)   */
  arg2detect = .Directory~new; arg2detect~put('argon2-cffi', 'module')
  py~append(self~impl('DETECT', .Array~of('from argon2 import PasswordHasher'), -
    'PasswordHasher().hash({password})', arg2detect, 1))
  bcryptdetect = .Directory~new; bcryptdetect~put('bcrypt', 'module')
  py~append(self~impl('DETECT', .Array~of('import bcrypt'), -
    'bcrypt.hashpw({password}.encode(), bcrypt.gensalt()).decode()', bcryptdetect, 2))
  /* pbkdf2 always available in Python 3.4+ stdlib — final fallback   */
  py~append(self~impl('STATIC', .Array~of('import hashlib','import os','import base64'), -
    'salt=os.urandom(16); dk=hashlib.pbkdf2_hmac("sha256",{password}.encode(),salt,600000); return base64.b64encode(salt+dk).decode()', -
    .nil, 3))
  impls~put(py, 'PYTHON')
  dn = .Array~new
  dn~append(self~impl('STATIC', -
    .Array~of('using Microsoft.AspNetCore.Cryptography.KeyDerivation;'), -
    'KeyDerivation.Pbkdf2({password},salt:null,KeyDerivationPrf.HMACSHA256,100000,32).ToString()', -
    .nil, 1))
  impls~put(dn, 'DOTNET')
  cap~put(impls, 'implementations')
  return cap

::method cap_crypto_random private
  cap = .Directory~new
  cap~put('Generate n cryptographically secure random bytes, return hex string', 'abstract')
  cap~put(.Array~of('n_bytes'), 'params')
  cap~put('string', 'returns')
  impls = .Directory~new
  py = .Array~new
  py~append(self~impl('STATIC', .Array~of('import secrets'), -
    'secrets.token_hex({n_bytes})', .nil, 1))
  impls~put(py, 'PYTHON')
  dn = .Array~new
  dn~append(self~impl('STATIC', -
    .Array~of('using System.Security.Cryptography;'), -
    'Convert.ToHexString(RandomNumberGenerator.GetBytes({n_bytes})).ToLower()', -
    .nil, 1))
  impls~put(dn, 'DOTNET')
  cap~put(impls, 'implementations')
  return cap

::method cap_http_get private
  cap = .Directory~new
  cap~put('HTTP GET a URL, return response body as string', 'abstract')
  cap~put(.Array~of('url'), 'params')
  cap~put('string', 'returns')
  impls = .Directory~new
  py = .Array~new
  /* Prefer requests (third-party but universal), fall to urllib       */
  rdetect = .Directory~new; rdetect~put('requests', 'module')
  py~append(self~impl('DETECT', .Array~of('import requests'), -
    'requests.get({url}, timeout=30).text', rdetect, 1))
  py~append(self~impl('STATIC', .Array~of('import urllib.request'), -
    'urllib.request.urlopen({url}, timeout=30).read().decode("utf-8")', .nil, 2))
  impls~put(py, 'PYTHON')
  dn = .Array~new
  dn~append(self~impl('STATIC', .Array~of('using System.Net.Http;'), -
    'new HttpClient().GetStringAsync({url}).GetAwaiter().GetResult()', .nil, 1))
  impls~put(dn, 'DOTNET')
  bash = .Array~new
  curl = .Directory~new; curl~put('curl', 'command')
  bash~append(self~impl('DETECT', .Array~of('curl'), -
    'curl -sf --max-time 30 {url}', curl, 1))
  bash~append(self~impl('STATIC', .Array~of('wget'), -
    'wget -qO- {url}', .nil, 2))
  impls~put(bash, 'BASH')
  cap~put(impls, 'implementations')
  return cap

::method cap_xml_parse private
  /* XML: the canonical example of "which version, which library"     */
  cap = .Directory~new
  cap~put('Parse an XML string, return a traversable document object', 'abstract')
  cap~put(.Array~of('xml_text'), 'params')
  cap~put('document', 'returns')
  impls = .Directory~new
  py = .Array~new
  /* lxml: fastest, best XPath, but external dependency               */
  lxmldetect = .Directory~new; lxmldetect~put('lxml', 'module')
  py~append(self~impl('DETECT', .Array~of('from lxml import etree'), -
    'etree.fromstring({xml_text}.encode())', lxmldetect, 1))
  /* defusedxml: security-hardened stdlib wrapper — preferred over raw ET */
  defdetect = .Directory~new; defdetect~put('defusedxml', 'module')
  py~append(self~impl('DETECT', .Array~of('import defusedxml.ElementTree as ET'), -
    'ET.fromstring({xml_text})', defdetect, 2))
  /* stdlib ElementTree: always available, but XXE-vulnerable without defusedxml */
  py~append(self~impl('STATIC', -
    .Array~of('import xml.etree.ElementTree as ET','# WARNING: XXE risk — install defusedxml'), -
    'ET.fromstring({xml_text})', .nil, 3))
  impls~put(py, 'PYTHON')
  dn = .Array~new
  dn~append(self~impl('STATIC', .Array~of('using System.Xml.Linq;'), -
    'XDocument.Parse({xml_text})', .nil, 1))
  impls~put(dn, 'DOTNET')
  cap~put(impls, 'implementations')
  return cap

::method cap_json_parse private
  cap = .Directory~new
  cap~put('Parse a JSON string into a native data structure', 'abstract')
  cap~put(.Array~of('json_text'), 'params')
  cap~put('object', 'returns')
  impls = .Directory~new
  py = .Array~new
  py~append(self~impl('STATIC', .Array~of('import json'), -
    'json.loads({json_text})', .nil, 1))
  impls~put(py, 'PYTHON')
  dn = .Array~new
  dn~append(self~impl('STATIC', .Array~of('using System.Text.Json;'), -
    'JsonSerializer.Deserialize<object>({json_text})', .nil, 1))
  impls~put(dn, 'DOTNET')
  oo = .Array~new
  oo~append(self~impl('STATIC', .Array~of('json.cls'), -
    '.json~new~fromJson({json_text})', .nil, 1))
  impls~put(oo, 'OOREXX')
  cap~put(impls, 'implementations')
  return cap

::method cap_json_serialize private
  cap = .Directory~new
  cap~put('Serialize a native data structure to a JSON string', 'abstract')
  cap~put(.Array~of('data'), 'params')
  cap~put('string', 'returns')
  impls = .Directory~new
  py = .Array~new
  py~append(self~impl('STATIC', .Array~of('import json'), -
    'json.dumps({data}, ensure_ascii=False)', .nil, 1))
  impls~put(py, 'PYTHON')
  dn = .Array~new
  dn~append(self~impl('STATIC', .Array~of('using System.Text.Json;'), -
    'JsonSerializer.Serialize({data})', .nil, 1))
  impls~put(dn, 'DOTNET')
  oo = .Array~new
  oo~append(self~impl('STATIC', .Array~of('json.cls'), -
    '.json~new~toJson({data})', .nil, 1))
  impls~put(oo, 'OOREXX')
  cap~put(impls, 'implementations')
  return cap

::method cap_file_read private
  cap = .Directory~new
  cap~put('Read entire file contents as a UTF-8 string', 'abstract')
  cap~put(.Array~of('path'), 'params')
  cap~put('string', 'returns')
  impls = .Directory~new
  py = .Array~new
  py~append(self~impl('STATIC', .Array~of(), -
    'open({path}, encoding="utf-8").read()', .nil, 1))
  impls~put(py, 'PYTHON')
  dn = .Array~new
  dn~append(self~impl('STATIC', .Array~of('using System.IO;'), -
    'File.ReadAllText({path}, System.Text.Encoding.UTF8)', .nil, 1))
  impls~put(dn, 'DOTNET')
  oo = .Array~new
  oo~append(self~impl('STATIC', .Array~of(), -
    'do; f=.Stream~new({path}); f~open("read"); c=f~charin(1,f~chars); f~close; end; c', -
    .nil, 1))
  impls~put(oo, 'OOREXX')
  bash = .Array~new
  bash~append(self~impl('STATIC', .Array~of(), 'cat {path}', .nil, 1))
  impls~put(bash, 'BASH')
  cap~put(impls, 'implementations')
  return cap

::method cap_time_now private
  cap = .Directory~new
  cap~put('Return current date/time as a human-readable string', 'abstract')
  cap~put(.Array~of(), 'params')
  cap~put('string', 'returns')
  impls = .Directory~new
  py = .Array~new
  py~append(self~impl('STATIC', .Array~of('from datetime import datetime'), -
    'datetime.now().isoformat()', .nil, 1))
  impls~put(py, 'PYTHON')
  dn = .Array~new
  dn~append(self~impl('STATIC', .Array~of(), -
    'DateTime.Now.ToString("o")', .nil, 1))
  impls~put(dn, 'DOTNET')
  oo = .Array~new
  oo~append(self~impl('STATIC', .Array~of(), -
    'date("S")||"T"||time("N")', .nil, 1))
  impls~put(oo, 'OOREXX')
  bash = .Array~new
  bash~append(self~impl('STATIC', .Array~of(), 'date -u +%Y-%m-%dT%H:%M:%SZ', .nil, 1))
  impls~put(bash, 'BASH')
  cap~put(impls, 'implementations')
  return cap

::method cap_log_info private
  cap = .Directory~new
  cap~put('Write an INFO log message with timestamp', 'abstract')
  cap~put(.Array~of('message'), 'params')
  cap~put('void', 'returns')
  impls = .Directory~new
  py = .Array~new
  logdetect = .Directory~new; logdetect~put('logging', 'module')
  py~append(self~impl('STATIC', .Array~of('import logging'), -
    'logging.info({message})', logdetect, 1))
  impls~put(py, 'PYTHON')
  dn = .Array~new
  dn~append(self~impl('STATIC', .Array~of(), -
    'Console.WriteLine($"[INFO] {DateTime.Now:o} {message}")', .nil, 1))
  impls~put(dn, 'DOTNET')
  oo = .Array~new
  oo~append(self~impl('STATIC', .Array~of(), -
    '_container~get(''logger'')~info({message})', .nil, 1))
  impls~put(oo, 'OOREXX')
  cap~put(impls, 'implementations')
  return cap

::method cap_process_run private
  cap = .Directory~new
  cap~put('Run a system command, return stdout as string', 'abstract')
  cap~put(.Array~of('command', 'args'), 'params')
  cap~put('string', 'returns')
  impls = .Directory~new
  py = .Array~new
  py~append(self~impl('STATIC', .Array~of('import subprocess'), -
    'subprocess.run([{command}]+{args}, capture_output=True, text=True, timeout=60).stdout', -
    .nil, 1))
  impls~put(py, 'PYTHON')
  cap~put(impls, 'implementations')
  return cap

::method cap_string_split private
  cap = .Directory~new
  cap~put('Split a string on a delimiter, return list of strings', 'abstract')
  cap~put(.Array~of('text', 'delimiter'), 'params')
  cap~put('list', 'returns')
  impls = .Directory~new
  py = .Array~new
  py~append(self~impl('STATIC', .Array~of(), '{text}.split({delimiter})', .nil, 1))
  impls~put(py, 'PYTHON')
  dn = .Array~new
  dn~append(self~impl('STATIC', .Array~of(), '{text}.Split({delimiter})', .nil, 1))
  impls~put(dn, 'DOTNET')
  oo = .Array~new
  oo~append(self~impl('STATIC', .Array~of(), -
    '_words = .Array~new; do while {text}\=""; parse var {text} w ({delimiter}) {text}; _words~append(w); end; _words', -
    .nil, 1))
  impls~put(oo, 'OOREXX')
  cap~put(impls, 'implementations')
  return cap

/* helper to build an impl entry */
::method impl private
  use arg implType, requires, inline, detect, rank
  e = .Directory~new
  e~put(implType, 'type')
  e~put(requires,  'requires')
  e~put(inline,    'inline')
  if detect \= .nil then e~put(detect, 'detect')
  e~put(rank, 'rank')
  return e

::method cap_hash_sha512;  forward message ('cap_hash_sha256') /* extend */
::method cap_crypto_uuid;  forward message ('cap_crypto_random')
::method cap_http_post;    forward message ('cap_http_get')
::method cap_http_json_get; forward message ('cap_http_get')
::method cap_file_write;   forward message ('cap_file_read')
::method cap_file_lines;   forward message ('cap_file_read')
::method cap_file_exists;  forward message ('cap_file_read')
::method cap_string_format; forward message ('cap_string_split')
::method cap_time_timestamp; forward message ('cap_time_now')

::requires 'json.cls'
::requires 'external/ExternalCall.cls'


/* ── Go and Java additions ────────────────────────────────────────── */
/* Added to each capability via extending the implementations map      */

::method addGoJavaToCapability private
  /* Utility: add go+java impl arrays to an existing capability map    */
  use arg cap, goInline, goRequires, javaInline, javaRequires
  impls = cap~at('implementations')
  if impls = .nil then do; impls = .Directory~new; cap~put(impls,'implementations'); end
  go = .Array~new
  go~append(self~impl('STATIC', goRequires, goInline, .nil, 1))
  impls~put(go, 'GO')
  jv = .Array~new
  jv~append(self~impl('STATIC', javaRequires, javaInline, .nil, 1))
  impls~put(jv, 'JAVA')

::method extendGoJava
  expose _capabilities
  sup = _capabilities~supplier
  do while sup~available
    name = sup~index
    cap  = sup~item
    select
      when name = 'HASH.SHA256' then
        self~addGoJavaToCapability(cap,
          'h:=sha256.Sum256([]byte({text})); return fmt.Sprintf("%x",h[:])',
          .Array~of('"crypto/sha256"','"fmt"'),
          'var md=MessageDigest.getInstance("SHA-256"); return bytesToHex(md.digest({text}.getBytes(StandardCharsets.UTF_8)));',
          .Array~of('import java.security.MessageDigest;','import java.nio.charset.StandardCharsets;'))

      when name = 'CRYPTO.RANDOM' then
        self~addGoJavaToCapability(cap,
          'b:=make([]byte,{n_bytes}); rand.Read(b); return hex.EncodeToString(b)',
          .Array~of('"crypto/rand"','"encoding/hex"'),
          'byte[] b=new byte[{n_bytes}]; new SecureRandom().nextBytes(b); return bytesToHex(b);',
          .Array~of('import java.security.SecureRandom;'))

      when name = 'CRYPTO.HMAC_SHA256' then
        self~addGoJavaToCapability(cap,
          'mac:=hmac.New(sha256.New,[]byte({key})); mac.Write([]byte({message})); return hex.EncodeToString(mac.Sum(nil))',
          .Array~of('"crypto/hmac"','"crypto/sha256"','"encoding/hex"'),
          'Mac mac=Mac.getInstance("HmacSHA256"); mac.init(new SecretKeySpec({key}.getBytes(),"HmacSHA256")); return bytesToHex(mac.doFinal({message}.getBytes()));',
          .Array~of('import javax.crypto.Mac;','import javax.crypto.spec.SecretKeySpec;'))

      when name = 'HTTP.GET' then
        self~addGoJavaToCapability(cap,
          'resp,_:=http.Get({url}); defer resp.Body.Close(); b,_:=io.ReadAll(resp.Body); return string(b)',
          .Array~of('"net/http"','"io"'),
          'var req=HttpRequest.newBuilder().uri(URI.create({url})).timeout(Duration.ofSeconds(30)).build(); return HttpClient.newHttpClient().send(req,HttpResponse.BodyHandlers.ofString()).body();',
          .Array~of('import java.net.http.*;','import java.net.URI;','import java.time.Duration;'))

      when name = 'JSON.PARSE' then
        self~addGoJavaToCapability(cap,
          'var m map[string]interface{}; json.Unmarshal([]byte({json_text}),&m); return m',
          .Array~of('"encoding/json"'),
          'return new ObjectMapper().readValue({json_text}, Map.class);',
          .Array~of('import com.fasterxml.jackson.databind.ObjectMapper;','import java.util.Map;'))

      when name = 'JSON.SERIALIZE' then
        self~addGoJavaToCapability(cap,
          'b,_:=json.Marshal({data}); return string(b)',
          .Array~of('"encoding/json"'),
          'return new ObjectMapper().writeValueAsString({data});',
          .Array~of('import com.fasterxml.jackson.databind.ObjectMapper;'))

      when name = 'FILE.READ' then
        self~addGoJavaToCapability(cap,
          'b,err:=os.ReadFile({path}); if err!=nil{return ""};return string(b)',
          .Array~of('"os"'),
          'try{return Files.readString(Path.of({path}));}catch(Exception e){return "";}',
          .Array~of('import java.nio.file.*;'))

      when name = 'FILE.WRITE' then
        self~addGoJavaToCapability(cap,
          'os.WriteFile({path},[]byte({content}),0644)',
          .Array~of('"os"'),
          'Files.writeString(Path.of({path}),{content});',
          .Array~of('import java.nio.file.*;'))

      when name = 'FILE.EXISTS' then
        self~addGoJavaToCapability(cap,
          '_,err:=os.Stat({path}); return err==nil',
          .Array~of('"os"'),
          'return Files.exists(Path.of({path}));',
          .Array~of('import java.nio.file.*;'))

      when name = 'FILE.APPEND' then
        self~addGoJavaToCapability(cap,
          'f,_:=os.OpenFile({path},os.O_APPEND|os.O_CREATE|os.O_WRONLY,0644); f.WriteString({content}); f.Close()',
          .Array~of('"os"'),
          'Files.writeString(Path.of({path}),{content},StandardOpenOption.APPEND,StandardOpenOption.CREATE);',
          .Array~of('import java.nio.file.*;','import java.nio.file.StandardOpenOption;'))

      when name = 'TIME.NOW' then
        self~addGoJavaToCapability(cap,
          'return time.Now().Format(time.RFC3339)',
          .Array~of('"time"'),
          'return Instant.now().toString();',
          .Array~of('import java.time.Instant;'))

      when name = 'TIME.TIMESTAMP' then
        self~addGoJavaToCapability(cap,
          'return time.Now().Unix()',
          .Array~of('"time"'),
          'return Instant.now().getEpochSecond();',
          .Array~of('import java.time.Instant;'))

      when name = 'ENV.GET' then
        self~addGoJavaToCapability(cap,
          'v:=os.Getenv({name}); if v==""{return {default}}; return v',
          .Array~of('"os"'),
          'String v=System.getenv({name}); return v!=null?v:{default};',
          .Array~of())

      when name = 'LOG.INFO' then
        self~addGoJavaToCapability(cap,
          'log.Println("[INFO]", {message})',
          .Array~of('"log"'),
          'System.out.println("[INFO] "+{message});',
          .Array~of())

      when name = 'LOG.ERROR' then
        self~addGoJavaToCapability(cap,
          'log.Println("[ERROR]", {message})',
          .Array~of('"log"'),
          'System.err.println("[ERROR] "+{message});',
          .Array~of())

      when name = 'STRING.SPLIT' then
        self~addGoJavaToCapability(cap,
          'return strings.Split({text},{delimiter})',
          .Array~of('"strings"'),
          'return Arrays.asList({text}.split(Pattern.quote({delimiter})));',
          .Array~of('import java.util.Arrays;','import java.util.regex.Pattern;'))

      when name = 'STRING.TRIM' then
        self~addGoJavaToCapability(cap,
          'return strings.TrimSpace({text})',
          .Array~of('"strings"'),
          'return {text}.strip();',
          .Array~of())

      when name = 'STRING.CONTAINS' then
        self~addGoJavaToCapability(cap,
          'return strings.Contains({text},{substring})',
          .Array~of('"strings"'),
          'return {text}.contains({substring});',
          .Array~of())

      otherwise nop
    end
    sup~next
  end
  say '[PREFERRED] Go+Java extensions applied'
