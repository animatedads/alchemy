/* ooRexx Cloud Console v0.1-dev2
 * Provider-neutral machine lifecycle and firewall control.
 * Core logic is ooRexx; provider execution is delegated to official CLIs.
 */

::class CloudJsonParser public
::attribute error get

::method init
  expose text pos length error
  use arg source
  text = source
  pos = 1
  length = text~length
  error = ""

::method parse
  expose text pos length error
  error = ""
  self~skipWs
  value = self~parseValue
  if error \= "" then return .nil
  self~skipWs
  if pos <= length then do
    error = "trailing data at character " || pos
    return .nil
  end
  return value

::method skipWs private
  expose text pos length
  do while pos <= length
    c = text~substr(pos, 1)
    if c == " " | c == '09'x | c == '0a'x | c == '0d'x then pos = pos + 1
    else leave
  end

::method parseValue private
  expose text pos length error
  self~skipWs
  if pos > length then do
    error = "unexpected end of JSON"
    return .nil
  end
  c = text~substr(pos, 1)
  select
    when c == '"' then return self~parseString
    when c == "{" then return self~parseObject
    when c == "[" then return self~parseArray
    when c == "-" | (c >= "0" & c <= "9") then return self~parseNumber
    otherwise do
      if text~substr(pos, 4) = "true" then do; pos = pos + 4; return "true"; end
      if text~substr(pos, 5) = "false" then do; pos = pos + 5; return "false"; end
      if text~substr(pos, 4) = "null" then do; pos = pos + 4; return .nil; end
      error = "unexpected token at character " || pos
      return .nil
    end
  end

::method parseObject private
  expose text pos length error
  obj = .Directory~new
  pos = pos + 1
  self~skipWs
  if pos <= length & text~substr(pos, 1) == "}" then do
    pos = pos + 1
    return obj
  end
  do forever
    self~skipWs
    if pos > length | text~substr(pos, 1) \== '"' then do
      error = "object key expected at character " || pos
      return .nil
    end
    key = self~parseString
    if error \= "" then return .nil
    self~skipWs
    if pos > length | text~substr(pos, 1) \== ":" then do
      error = "colon expected after object key at character " || pos
      return .nil
    end
    pos = pos + 1
    value = self~parseValue
    if error \= "" then return .nil
    obj[key] = value
    self~skipWs
    if pos > length then do
      error = "unterminated object"
      return .nil
    end
    c = text~substr(pos, 1)
    if c == "}" then do
      pos = pos + 1
      return obj
    end
    if c \== "," then do
      error = "comma expected in object at character " || pos
      return .nil
    end
    pos = pos + 1
  end

::method parseArray private
  expose text pos length error
  arr = .Array~new
  pos = pos + 1
  self~skipWs
  if pos <= length & text~substr(pos, 1) == "]" then do
    pos = pos + 1
    return arr
  end
  do forever
    value = self~parseValue
    if error \= "" then return .nil
    arr~append(value)
    self~skipWs
    if pos > length then do
      error = "unterminated array"
      return .nil
    end
    c = text~substr(pos, 1)
    if c == "]" then do
      pos = pos + 1
      return arr
    end
    if c \== "," then do
      error = "comma expected in array at character " || pos
      return .nil
    end
    pos = pos + 1
  end

::method parseString private
  expose text pos length error
  out = ""
  pos = pos + 1
  do while pos <= length
    c = text~substr(pos, 1)
    if c == '"' then do
      pos = pos + 1
      return out
    end
    if c == "\\" then do
      pos = pos + 1
      if pos > length then do
        error = "unterminated escape sequence"
        return .nil
      end
      e = text~substr(pos, 1)
      select
        when e == '"' then out = out || '"'
        when e == "\\" then out = out || "\\"
        when e == "/" then out = out || "/"
        when e == "b" then out = out || '08'x
        when e == "f" then out = out || '0c'x
        when e == "n" then out = out || '0a'x
        when e == "r" then out = out || '0d'x
        when e == "t" then out = out || '09'x
        when e == "u" then do
          if pos + 4 > length then do
            error = "short unicode escape"
            return .nil
          end
          hex = text~substr(pos + 1, 4)
          if \datatype(hex, "X") then do
            error = "invalid unicode escape"
            return .nil
          end
          /* Preserve non-ASCII JSON escapes literally. Provider identity fields
             are not interpreted as executable content. */
          out = out || "\\u" || hex
          pos = pos + 4
        end
        otherwise do
          error = "invalid string escape at character " || pos
          return .nil
        end
      end
      pos = pos + 1
      iterate
    end
    out = out || c
    pos = pos + 1
  end
  error = "unterminated string"
  return .nil

::method parseNumber private
  expose text pos length error
  start = pos
  allowed = "-+0123456789.eE"
  do while pos <= length
    c = text~substr(pos, 1)
    if pos(c, allowed) = 0 then leave
    pos = pos + 1
  end
  n = text~substr(start, pos - start)
  if n = "" then do
    error = "invalid number"
    return .nil
  end
  return n


::class CloudJson public
::method encode class
  use arg value
  if value == .nil then return "null"
  if value~isA(.Directory) then do
    out = "{"
    first = .true
    do key over value~allIndexes
      if \first then out = out || ","
      first = .false
      out = out || self~quote(key) || ":" || self~encode(value[key])
    end
    return out || "}"
  end
  if value~isA(.Array) then do
    out = "["
    do i = 1 to value~items
      if i > 1 then out = out || ","
      out = out || self~encode(value[i])
    end
    return out || "]"
  end
  return self~quote("" || value)

::method quote class
  use arg value
  out = '"'
  do i = 1 to value~length
    c = value~substr(i, 1)
    select
      when c == '"' then out = out || '\\"'
      when c == "\\" then out = out || "\\\\"
      when c == '0a'x then out = out || "\\n"
      when c == '0d'x then out = out || "\\r"
      when c == '09'x then out = out || "\\t"
      otherwise out = out || c
    end
  end
  return out || '"'


::class CloudUtil public
::method readAll class
  use arg path
  s = .Stream~new(path)
  if s~query("exists") = "" then return ""
  s~open("read")
  n = s~chars
  if n > 0 then data = s~charIn(1, n)
  else data = ""
  s~close
  return data

::method writeAll class
  use arg path, content
  s = .Stream~new(path)
  s~open("write replace")
  s~charOut(content)
  s~close
  return path

::method shellQuote class
  use arg value
  value = "" || value
  /* POSIX single-quote escaping: ' becomes '"'"'.  This keeps provider
     arguments and workspace paths as data rather than shell syntax. */
  sq = '27'x
  dq = '22'x
  replacement = sq || dq || sq || dq || sq
  return sq || changestr(sq, value, replacement) || sq

::method canonicalDirectory class
  use arg path
  if arg() < 1 then path = directory()
  else if path == .nil then path = directory()
  else if strip("" || path) = "" then path = directory()
  old = directory()
  changed = directory(path)
  if changed = "" then return .nil
  resolved = directory()
  call directory old
  return resolved

::method readLines class
  use arg path
  a = .Array~new
  if arg() < 1 then return a
  if path == .nil then return a
  if strip("" || path) = "" then return a
  st = .Stream~new("" || path)
  if st~query("exists") = "" then return a
  st~open("read")
  do while st~state = "READY"
    line = st~lineIn
    if st~state \= "READY" & line = "" then leave
    a~append(line)
  end
  st~close
  return a

::method env class
  use arg name, defaultValue
  v = value(name, , "ENVIRONMENT")
  if v = "" then return defaultValue
  return v

::method lower class
  use arg s
  return translate("" || s, "abcdefghijklmnopqrstuvwxyz", "ABCDEFGHIJKLMNOPQRSTUVWXYZ")

::method upper class
  use arg s
  return translate("" || s)

::method isArray class
  use arg value
  if arg() < 1 then return .false
  if value == .nil then return .false
  return value~isA(.Array)

::method mapGet class
  use arg d, key, defaultValue
  if d == .nil then return defaultValue
  if \d~isA(.Directory) then return defaultValue
  if d~hasIndex(key) then do
    if d[key] == .nil then return defaultValue
    return d[key]
  end
  return defaultValue

::method arrayGet class
  use arg a, index, defaultValue
  if a == .nil then return defaultValue
  if \a~isA(.Array) then return defaultValue
  if index < 1 | index > a~items then return defaultValue
  if a[index] == .nil then return defaultValue
  return a[index]

::method basenameUri class
  use arg value
  value = "" || value
  p = value~lastPos("/")
  if p = 0 then return value
  return value~substr(p + 1)

::method truncate class
  use arg value, width
  value = "" || value
  if value~length <= width then return value
  if width < 2 then return value~left(width)
  return value~left(width - 1) || "~"

::method splitScope class
  use arg scope
  reply = .Array~new
  p = scope~pos(":")
  if p = 0 then return reply
  reply~append(scope~left(p - 1))
  reply~append(scope~substr(p + 1))
  return reply

::method splitCidr class
  use arg cidr
  reply = .Array~new
  p = cidr~pos("/")
  if p = 0 then do
    reply~append(cidr)
    if cidr~pos(":") > 0 then reply~append("128")
    else reply~append("32")
    return reply
  end
  reply~append(cidr~left(p - 1))
  reply~append(cidr~substr(p + 1))
  return reply

::method firstNonEmpty class
  use arg a, b, c, d
  if arg(1, "E") then do
    if a \== .nil then if strip("" || a) \== "" then return a
  end
  if arg(2, "E") then do
    if b \== .nil then if strip("" || b) \== "" then return b
  end
  if arg(3, "E") then do
    if c \== .nil then if strip("" || c) \== "" then return c
  end
  if arg(4, "E") then do
    if d \== .nil then if strip("" || d) \== "" then return d
  end
  return ""

::method joinArray class
  use arg value, separator
  if separator = .nil | separator = "" then separator = ","
  if value == .nil then return ""
  if \value~isA(.Array) then return "" || value
  out = ""
  do i = 1 to value~items
    if i > 1 then out = out || separator
    out = out || value[i]
  end
  return out

::method splitMachineHandle class
  use arg handle
  a = .Array~new
  p = handle~pos("/")
  if p = 0 then do
    a~append("")
    a~append(handle)
    return a
  end
  a~append(handle~left(p - 1))
  a~append(handle~substr(p + 1))
  return a


::class CloudExec public
::attribute workspace get

::method init
  expose workspace
  use arg requestedWorkspace
  workspace = .CloudUtil~canonicalDirectory(requestedWorkspace)
  if workspace == .nil then workspace = ""

::method commandText
  use arg args
  if arg() < 1 then return .nil
  if \args~isA(.Array) then return .nil
  if args~items = 0 then return .nil
  out = ""
  do i = 1 to args~items
    q = .CloudUtil~shellQuote(args[i])
    if q == .nil then return .nil
    if i > 1 then out = out || " "
    out = out || q
  end
  return out

::method run
  expose workspace
  use arg args
  reply = .Directory~new
  reply["rc"] = "2"
  reply["stdout"] = ""
  reply["stderr"] = ""
  reply["command"] = ""
  if workspace = "" then do
    reply["stderr"] = "invalid workspace"
    return reply
  end
  cmd = self~commandText(args)
  if cmd == .nil then do
    reply["stderr"] = "unsafe command argument"
    return reply
  end
  wq = .CloudUtil~shellQuote(workspace)
  if wq == .nil then do
    reply["stderr"] = "unsafe workspace path"
    return reply
  end
  nonce = time("S") || "-" || random(100000, 999999)
  outPath = "/tmp/oorexx-cloudctl-" || nonce || ".out"
  errPath = "/tmp/oorexx-cloudctl-" || nonce || ".err"
  reply["command"] = cmd
  full = "cd " || wq || " && " || cmd || " >" || .CloudUtil~shellQuote(outPath) || " 2>" || .CloudUtil~shellQuote(errPath)
  address system full
  code = rc
  reply["rc"] = "" || code
  reply["stdout"] = .CloudUtil~readAll(outPath)
  reply["stderr"] = .CloudUtil~readAll(errPath)
  call SysFileDelete outPath
  call SysFileDelete errPath
  return reply

::method probe
  expose workspace
  use arg executable
  args = .Array~of("sh", "-c", "command -v " || executable)
  return self~run(args)


::class CloudSpec public
::method load class
  use arg path, workspace
  reply = .Directory~new
  if path = .nil | strip("" || path) = "" then return reply
  path = "" || path
  if path~left(1) \= "/" then path = workspace || "/" || path
  s = .Stream~new(path)
  if s~query("exists") = "" then do
    reply["__error"] = "spec file not found: " || path
    return reply
  end
  s~open("read")
  do while s~state = "READY"
    line = s~lineIn
    if s~state \= "READY" & line = "" then leave
    line = strip(line)
    if line = "" then iterate
    if line~left(1) = "#" then iterate
    p = line~pos("=")
    if p = 0 then do
      reply["__error"] = "invalid spec line (expected key=value): " || line
      s~close
      return reply
    end
    key = .CloudUtil~lower(strip(line~left(p - 1)))
    value = strip(line~substr(p + 1))
    if self~secretKey(key) then do
      reply["__error"] = "secret-bearing field is forbidden in cloudctl spec: " || key
      s~close
      return reply
    end
    reply[key] = value
  end
  s~close
  return reply

::method secretKey class
  use arg key
  k = .CloudUtil~lower(key)
  return k~pos("password") > 0 | k~pos("secret") > 0 | k~pos("api_key") > 0 | k~pos("apikey") > 0 | k~pos("token") > 0


::class CloudArgs public
::attribute options get
::attribute words get
::attribute error get

::method init
  expose options words error
  use arg raw, tokenArray
  supplied = arg()
  options = .Directory~new
  words = .Array~new
  error = ""
  if supplied < 2 then self~parseRaw(raw)
  else self~parseTokens(tokenArray)

::method parseRaw private
  use arg raw
  tokens = .Array~new
  count = words(raw)
  do i = 1 to count
    tokens~append(word(raw, i))
  end
  self~parseTokens(tokens)

::method parseTokens private
  expose options words error
  use arg tokens
  i = 1
  do while i <= tokens~items
    token = "" || tokens[i]
    if token~left(2) = "--" then do
      body = token~substr(3)
      eq = body~pos("=")
      if eq > 0 then do
        key = .CloudUtil~lower(body~left(eq - 1))
        val = body~substr(eq + 1)
      end
      else do
        key = .CloudUtil~lower(body)
        if self~isFlag(key) then val = "true"
        else do
          if i = tokens~items then do
            error = "missing value for --" || key
            return
          end
          i = i + 1
          val = "" || tokens[i]
        end
      end
      if .CloudSpec~secretKey(key) then do
        error = "cloudctl does not accept secret-bearing option --" || key
        return
      end
      options[key] = val
    end
    else words~append(token)
    i = i + 1
  end

::method isFlag private
  use arg key
  return key = "json" | key = "apply" | key = "help" | key = "version" | key = "yes" | key = "no_color"

::method mergeSpec
  expose options error
  use arg spec
  if spec~hasIndex("__error") then do
    error = spec["__error"]
    return
  end
  do key over spec~allIndexes
    if \options~hasIndex(key) then options[key] = spec[key]
  end

::method option
  expose options
  use arg key, defaultValue
  key = .CloudUtil~lower(key)
  if options~hasIndex(key) then return options[key]
  return defaultValue

::method has
  expose options
  use arg key
  return options~hasIndex(.CloudUtil~lower(key))


::class CloudResult public
::method newResult class
  use arg status, message
  r = .Directory~new
  r["schema"] = "oorexx.cloud.console.result/1"
  r["status"] = status
  r["message"] = message
  r["data"] = .Array~new
  return r

::method error class
  use arg message
  return self~newResult("ERROR", message)

::method ok class
  use arg message
  return self~newResult("OK", message)

::method planned class
  use arg message, provider, action, command
  r = self~newResult("PLANNED", message)
  r["provider"] = provider
  r["action"] = action
  r["command"] = command
  return r

::method applied class
  use arg message, provider, action, command, stdout
  r = self~newResult("APPLIED", message)
  r["provider"] = provider
  r["action"] = action
  r["command"] = command
  r["provider_stdout"] = stdout
  return r


::class CloudProvider public
::attribute id get
::attribute executable get
::attribute title get

::method init
  expose id executable title
  use arg newId, newExecutable, newTitle
  id = newId
  executable = newExecutable
  title = newTitle

::method globalArgs
  use arg opts
  return .Array~new

::method machineList
  use arg exec, opts
  return .CloudResult~error("machine list not implemented for " || self~id)

::method machineCommand
  use arg action, opts
  return .nil

::method machineCreate
  use arg opts
  return .nil

::method firewallList
  use arg exec, opts
  return .CloudResult~error("firewall list not implemented for " || self~id)

::method firewallCommand
  use arg action, opts
  return .nil

::method require
  use arg opts, names
  missing = .Array~new
  do i = 1 to names~items
    name = names[i]
    if strip(opts~option(name, "")) = "" then missing~append(name)
  end
  if missing~items = 0 then return ""
  msg = "missing required option"
  if missing~items > 1 then msg = msg || "s"
  msg = msg || ": "
  do i = 1 to missing~items
    if i > 1 then msg = msg || ", "
    msg = msg || "--" || missing[i]
  end
  return msg

::method parseJson
  use arg text
  p = .CloudJsonParser~new(text)
  data = p~parse
  if p~error \= "" then return .Array~of(.nil, p~error)
  return .Array~of(data, "")

::method execJson
  use arg exec, args
  raw = exec~run(args)
  if raw["rc"] \= "0" then do
    msg = strip(raw["stderr"])
    if msg = "" then msg = strip(raw["stdout"])
    if msg = "" then msg = "provider command failed rc=" || raw["rc"]
    return .Array~of(.nil, msg, raw)
  end
  parsed = self~parseJson(raw["stdout"])
  if parsed[2] \= "" then return .Array~of(.nil, "provider returned invalid JSON: " || parsed[2], raw)
  return .Array~of(parsed[1], "", raw)

::method machineRecord
  use arg handle, name, region, state, publicIp, privateIp
  d = .Directory~new
  d["provider"] = self~id
  d["handle"] = "" || handle
  d["name"] = "" || name
  d["region"] = "" || region
  d["state"] = "" || state
  d["public_ip"] = "" || publicIp
  d["private_ip"] = "" || privateIp
  return d

::method firewallRecord
  use arg rule, scope, direction, protocol, ports, source, description
  d = .Directory~new
  d["provider"] = self~id
  d["rule"] = "" || rule
  d["scope"] = "" || scope
  d["direction"] = .CloudUtil~upper("" || direction)
  p = .CloudUtil~lower("" || protocol)
  select
    when p = "6" | p = "tcp" then p = "tcp"
    when p = "17" | p = "udp" then p = "udp"
    when p = "1" | p = "icmp" then p = "icmp"
    when p = "-1" | p = "all" | p = "*" then p = "all"
    otherwise nop
  end
  d["protocol"] = p
  d["ports"] = .CloudUtil~joinArray(ports, ",")
  d["source"] = .CloudUtil~joinArray(source, ",")
  d["description"] = "" || description
  return d

::method addArg
  use arg args, flag, value
  if value = .nil | strip("" || value) = "" then return
  args~append(flag)
  args~append("" || value)


::class AzureProvider subclass CloudProvider public
::method init
  self~init:super("azure", "az", "Microsoft Azure")

::method machineList
  use arg exec, opts
  args = .Array~of("az", "vm", "list", "--show-details", "--output", "json", "--only-show-errors")
  self~addArg(args, "--subscription", opts~option("subscription", ""))
  self~addArg(args, "--resource-group", opts~option("group", ""))
  got = self~execJson(exec, args)
  if got[2] \= "" then return .CloudResult~error(got[2])
  rows = got[1]
  r = .CloudResult~ok("Azure machine inventory")
  if rows~isA(.Array) then do vm over rows
    id = .CloudUtil~mapGet(vm, "id", "")
    name = .CloudUtil~mapGet(vm, "name", "")
    region = .CloudUtil~mapGet(vm, "location", "")
    state = .CloudUtil~mapGet(vm, "powerState", .CloudUtil~mapGet(vm, "provisioningState", ""))
    pub = .CloudUtil~mapGet(vm, "publicIps", "")
    priv = .CloudUtil~mapGet(vm, "privateIps", "")
    r["data"]~append(self~machineRecord(id, name, region, state, pub, priv))
  end
  return r

::method machineCommand
  use arg action, opts
  machine = opts~option("machine", "")
  if machine = "" then return .Array~of(.nil, "missing required option: --machine")
  select
    when action = "start" then args = .Array~of("az", "vm", "start", "--ids", machine, "--only-show-errors")
    when action = "stop" then args = .Array~of("az", "vm", "deallocate", "--ids", machine, "--only-show-errors")
    when action = "reboot" then args = .Array~of("az", "vm", "restart", "--ids", machine, "--only-show-errors")
    when action = "destroy" then args = .Array~of("az", "vm", "delete", "--ids", machine, "--yes", "--only-show-errors")
    otherwise return .Array~of(.nil, "unsupported machine action: " || action)
  end
  self~addArg(args, "--subscription", opts~option("subscription", ""))
  return .Array~of(args, "")

::method machineCreate
  use arg opts
  missing = self~require(opts, .Array~of("group", "name", "image", "size"))
  if missing \= "" then return .Array~of(.nil, missing)
  args = .Array~of("az", "vm", "create", "--resource-group", opts~option("group", ""), "--name", opts~option("name", ""), "--image", opts~option("image", ""), "--size", opts~option("size", ""), "--only-show-errors")
  self~addArg(args, "--location", opts~option("region", ""))
  self~addArg(args, "--zone", opts~option("zone", ""))
  self~addArg(args, "--admin-username", opts~option("admin_user", ""))
  self~addArg(args, "--ssh-key-values", opts~option("ssh_key", ""))
  self~addArg(args, "--nsg", opts~option("security_group", ""))
  self~addArg(args, "--subscription", opts~option("subscription", ""))
  return .Array~of(args, "")

::method firewallList
  use arg exec, opts
  scope = .CloudUtil~splitScope(opts~option("scope", ""))
  if scope~items \= 2 then return .CloudResult~error("Azure --scope must be RESOURCE_GROUP:NSG_NAME")
  args = .Array~of("az", "network", "nsg", "rule", "list", "--resource-group", scope[1], "--nsg-name", scope[2], "--output", "json", "--only-show-errors")
  self~addArg(args, "--subscription", opts~option("subscription", ""))
  got = self~execJson(exec, args)
  if got[2] \= "" then return .CloudResult~error(got[2])
  r = .CloudResult~ok("Azure NSG rules")
  rows = got[1]
  if rows~isA(.Array) then do rule over rows
    name = .CloudUtil~mapGet(rule, "name", "")
    direction = .CloudUtil~mapGet(rule, "direction", "")
    protocol = .CloudUtil~mapGet(rule, "protocol", "")
    ports = .CloudUtil~firstNonEmpty(.CloudUtil~mapGet(rule, "destinationPortRange", ""), .CloudUtil~mapGet(rule, "destinationPortRanges", ""), "", "")
    source = .CloudUtil~firstNonEmpty(.CloudUtil~mapGet(rule, "sourceAddressPrefix", ""), .CloudUtil~mapGet(rule, "sourceAddressPrefixes", ""), "", "")
    desc = .CloudUtil~mapGet(rule, "description", "")
    r["data"]~append(self~firewallRecord(name, opts~option("scope", ""), direction, protocol, ports, source, desc))
  end
  return r

::method firewallCommand
  use arg action, opts
  scope = .CloudUtil~splitScope(opts~option("scope", ""))
  if scope~items \= 2 then return .Array~of(.nil, "Azure --scope must be RESOURCE_GROUP:NSG_NAME")
  if action = "allow" then do
    missing = self~require(opts, .Array~of("rule", "protocol", "port", "source"))
    if missing \= "" then return .Array~of(.nil, missing)
    priority = opts~option("priority", "3000")
    args = .Array~of("az", "network", "nsg", "rule", "create", "--resource-group", scope[1], "--nsg-name", scope[2], "--name", opts~option("rule", ""), "--priority", priority, "--access", "Allow", "--direction", "Inbound", "--protocol", opts~option("protocol", ""), "--source-address-prefixes", opts~option("source", ""), "--destination-port-ranges", opts~option("port", ""), "--only-show-errors")
  end
  else if action = "revoke" then do
    if opts~option("rule", "") = "" then return .Array~of(.nil, "missing required option: --rule")
    args = .Array~of("az", "network", "nsg", "rule", "delete", "--resource-group", scope[1], "--nsg-name", scope[2], "--name", opts~option("rule", ""), "--only-show-errors")
  end
  else return .Array~of(.nil, "unsupported firewall action: " || action)
  self~addArg(args, "--subscription", opts~option("subscription", ""))
  return .Array~of(args, "")


::class GcpProvider subclass CloudProvider public
::method init
  self~init:super("gcp", "gcloud", "Google Cloud")

::method addProject
  use arg args, opts
  self~addArg(args, "--project", opts~option("project", ""))
  self~addArg(args, "--configuration", opts~option("configuration", ""))

::method machineList
  use arg exec, opts
  args = .Array~of("gcloud", "compute", "instances", "list", "--format=json", "--quiet")
  self~addProject(args, opts)
  got = self~execJson(exec, args)
  if got[2] \= "" then return .CloudResult~error(got[2])
  r = .CloudResult~ok("Google Cloud machine inventory")
  rows = got[1]
  if rows~isA(.Array) then do vm over rows
    name = .CloudUtil~mapGet(vm, "name", "")
    zone = .CloudUtil~basenameUri(.CloudUtil~mapGet(vm, "zone", ""))
    state = .CloudUtil~mapGet(vm, "status", "")
    if zone = "" then id = name
    else id = zone || "/" || name
    pub = ""; priv = ""
    nis = .CloudUtil~mapGet(vm, "networkInterfaces", .nil)
    ni = .CloudUtil~arrayGet(nis, 1, .nil)
    if ni \= .nil then do
      priv = .CloudUtil~mapGet(ni, "networkIP", "")
      acs = .CloudUtil~mapGet(ni, "accessConfigs", .nil)
      ac = .CloudUtil~arrayGet(acs, 1, .nil)
      if ac \= .nil then pub = .CloudUtil~mapGet(ac, "natIP", "")
    end
    r["data"]~append(self~machineRecord(id, name, zone, state, pub, priv))
  end
  return r

::method machineCommand
  use arg action, opts
  machine = opts~option("machine", "")
  zone = opts~option("zone", "")
  if machine = "" then return .Array~of(.nil, "missing required option: --machine")
  parts = .CloudUtil~splitMachineHandle(machine)
  if zone = "" & parts[1] \= "" then do
    zone = parts[1]
    machine = parts[2]
  end
  if zone = "" then return .Array~of(.nil, "GCP machine mutation requires --zone or a zone/name machine handle")
  select
    when action = "start" then verb = "start"
    when action = "stop" then verb = "stop"
    when action = "reboot" then verb = "reset"
    when action = "destroy" then verb = "delete"
    otherwise return .Array~of(.nil, "unsupported machine action: " || action)
  end
  args = .Array~of("gcloud", "compute", "instances", verb, machine, "--zone", zone, "--quiet")
  self~addProject(args, opts)
  return .Array~of(args, "")

::method machineCreate
  use arg opts
  missing = self~require(opts, .Array~of("name", "zone", "size"))
  if missing \= "" then return .Array~of(.nil, missing)
  if opts~option("image", "") = "" & opts~option("image_family", "") = "" then return .Array~of(.nil, "GCP create requires --image or --image_family")
  args = .Array~of("gcloud", "compute", "instances", "create", opts~option("name", ""), "--zone", opts~option("zone", ""), "--machine-type", opts~option("size", ""), "--quiet")
  self~addArg(args, "--image", opts~option("image", ""))
  self~addArg(args, "--image-family", opts~option("image_family", ""))
  self~addArg(args, "--image-project", opts~option("image_project", ""))
  self~addArg(args, "--network", opts~option("network", ""))
  self~addArg(args, "--subnet", opts~option("subnet", ""))
  self~addArg(args, "--tags", opts~option("tags", ""))
  self~addProject(args, opts)
  return .Array~of(args, "")

::method firewallList
  use arg exec, opts
  if opts~option("scope", "") = "" then return .CloudResult~error("missing required option: --scope (GCP network name)")
  args = .Array~of("gcloud", "compute", "firewall-rules", "list", "--format=json", "--filter=network:" || opts~option("scope", ""), "--quiet")
  self~addProject(args, opts)
  got = self~execJson(exec, args)
  if got[2] \= "" then return .CloudResult~error(got[2])
  r = .CloudResult~ok("Google Cloud firewall rules")
  rows = got[1]
  if rows~isA(.Array) then do rule over rows
    name = .CloudUtil~mapGet(rule, "name", "")
    direction = .CloudUtil~mapGet(rule, "direction", "")
    desc = .CloudUtil~mapGet(rule, "description", "")
    source = ""
    sr = .CloudUtil~mapGet(rule, "sourceRanges", .nil)
    if .CloudUtil~isArray(sr) then do
      if sr~items > 0 then source = sr[1]
    end
    protocol = ""; ports = ""
    allowed = .CloudUtil~mapGet(rule, "allowed", .nil)
    a = .CloudUtil~arrayGet(allowed, 1, .nil)
    if a \= .nil then do
      protocol = .CloudUtil~mapGet(a, "IPProtocol", "")
      pa = .CloudUtil~mapGet(a, "ports", .nil)
      if .CloudUtil~isArray(pa) then do
        if pa~items > 0 then ports = pa[1]
      end
    end
    r["data"]~append(self~firewallRecord(name, opts~option("scope", ""), direction, protocol, ports, source, desc))
  end
  return r

::method firewallCommand
  use arg action, opts
  scope = opts~option("scope", "")
  if scope = "" then return .Array~of(.nil, "missing required option: --scope (GCP network name)")
  if action = "allow" then do
    missing = self~require(opts, .Array~of("rule", "protocol", "port", "source"))
    if missing \= "" then return .Array~of(.nil, missing)
    args = .Array~of("gcloud", "compute", "firewall-rules", "create", opts~option("rule", ""), "--network", scope, "--direction", "INGRESS", "--action", "ALLOW", "--rules", opts~option("protocol", "") || ":" || opts~option("port", ""), "--source-ranges", opts~option("source", ""), "--quiet")
    self~addArg(args, "--description", opts~option("description", ""))
  end
  else if action = "revoke" then do
    if opts~option("rule", "") = "" then return .Array~of(.nil, "missing required option: --rule")
    args = .Array~of("gcloud", "compute", "firewall-rules", "delete", opts~option("rule", ""), "--quiet")
  end
  else return .Array~of(.nil, "unsupported firewall action: " || action)
  self~addProject(args, opts)
  return .Array~of(args, "")


::class AwsProvider subclass CloudProvider public
::method init
  self~init:super("aws", "aws", "Amazon Web Services")

::method addContext
  use arg args, opts
  self~addArg(args, "--region", opts~option("region", ""))
  self~addArg(args, "--profile", opts~option("aws_profile", ""))
  args~append("--no-cli-pager")

::method machineList
  use arg exec, opts
  args = .Array~of("aws", "ec2", "describe-instances", "--output", "json")
  self~addContext(args, opts)
  got = self~execJson(exec, args)
  if got[2] \= "" then return .CloudResult~error(got[2])
  root = got[1]
  r = .CloudResult~ok("AWS EC2 machine inventory")
  reservations = .CloudUtil~mapGet(root, "Reservations", .nil)
  if .CloudUtil~isArray(reservations) then do res over reservations
    instances = .CloudUtil~mapGet(res, "Instances", .nil)
    if .CloudUtil~isArray(instances) then do vm over instances
      id = .CloudUtil~mapGet(vm, "InstanceId", "")
      name = id
      tags = .CloudUtil~mapGet(vm, "Tags", .nil)
      if .CloudUtil~isArray(tags) then do tag over tags
        if .CloudUtil~mapGet(tag, "Key", "") = "Name" then name = .CloudUtil~mapGet(tag, "Value", id)
      end
      placement = .CloudUtil~mapGet(vm, "Placement", .nil)
      region = .CloudUtil~mapGet(placement, "AvailabilityZone", "")
      stateObj = .CloudUtil~mapGet(vm, "State", .nil)
      state = .CloudUtil~mapGet(stateObj, "Name", "")
      pub = .CloudUtil~mapGet(vm, "PublicIpAddress", "")
      priv = .CloudUtil~mapGet(vm, "PrivateIpAddress", "")
      r["data"]~append(self~machineRecord(id, name, region, state, pub, priv))
    end
  end
  return r

::method machineCommand
  use arg action, opts
  machine = opts~option("machine", "")
  if machine = "" then return .Array~of(.nil, "missing required option: --machine")
  select
    when action = "start" then verb = "start-instances"
    when action = "stop" then verb = "stop-instances"
    when action = "reboot" then verb = "reboot-instances"
    when action = "destroy" then verb = "terminate-instances"
    otherwise return .Array~of(.nil, "unsupported machine action: " || action)
  end
  args = .Array~of("aws", "ec2", verb, "--instance-ids", machine, "--output", "json")
  self~addContext(args, opts)
  return .Array~of(args, "")

::method machineCreate
  use arg opts
  missing = self~require(opts, .Array~of("name", "image", "size"))
  if missing \= "" then return .Array~of(.nil, missing)
  args = .Array~of("aws", "ec2", "run-instances", "--image-id", opts~option("image", ""), "--instance-type", opts~option("size", ""), "--min-count", "1", "--max-count", "1", "--tag-specifications", "ResourceType=instance,Tags=[{Key=Name,Value=" || opts~option("name", "") || "}]", "--output", "json")
  self~addArg(args, "--subnet-id", opts~option("subnet", ""))
  self~addArg(args, "--security-group-ids", opts~option("security_group", ""))
  self~addArg(args, "--key-name", opts~option("key_name", ""))
  self~addContext(args, opts)
  return .Array~of(args, "")

::method firewallList
  use arg exec, opts
  scope = opts~option("scope", "")
  if scope = "" then return .CloudResult~error("missing required option: --scope (AWS security-group id)")
  args = .Array~of("aws", "ec2", "describe-security-group-rules", "--filters", "Name=group-id,Values=" || scope, "--output", "json")
  self~addContext(args, opts)
  got = self~execJson(exec, args)
  if got[2] \= "" then return .CloudResult~error(got[2])
  r = .CloudResult~ok("AWS security-group rules")
  rows = .CloudUtil~mapGet(got[1], "SecurityGroupRules", .nil)
  if .CloudUtil~isArray(rows) then do rule over rows
    rid = .CloudUtil~mapGet(rule, "SecurityGroupRuleId", "")
    egress = .CloudUtil~mapGet(rule, "IsEgress", "false")
    if egress = "true" | egress = "1" then direction = "EGRESS"
    else direction = "INGRESS"
    protocol = .CloudUtil~mapGet(rule, "IpProtocol", "")
    fromp = .CloudUtil~mapGet(rule, "FromPort", "")
    top = .CloudUtil~mapGet(rule, "ToPort", "")
    if fromp = top then ports = fromp
    else if fromp = "" then ports = ""
    else ports = fromp || "-" || top
    source = .CloudUtil~firstNonEmpty(.CloudUtil~mapGet(rule, "CidrIpv4", ""), .CloudUtil~mapGet(rule, "CidrIpv6", ""), .CloudUtil~mapGet(rule, "ReferencedGroupInfo", ""), "")
    desc = .CloudUtil~mapGet(rule, "Description", "")
    r["data"]~append(self~firewallRecord(rid, scope, direction, protocol, ports, source, desc))
  end
  return r

::method firewallCommand
  use arg action, opts
  scope = opts~option("scope", "")
  if scope = "" then return .Array~of(.nil, "missing required option: --scope (AWS security-group id)")
  if action = "allow" then do
    missing = self~require(opts, .Array~of("protocol", "port", "source"))
    if missing \= "" then return .Array~of(.nil, missing)
    args = .Array~of("aws", "ec2", "authorize-security-group-ingress", "--group-id", scope, "--protocol", opts~option("protocol", ""), "--port", opts~option("port", ""), "--cidr", opts~option("source", ""), "--output", "json")
  end
  else if action = "revoke" then do
    if opts~option("rule", "") = "" then return .Array~of(.nil, "missing required option: --rule (AWS security-group-rule id)")
    args = .Array~of("aws", "ec2", "revoke-security-group-ingress", "--group-id", scope, "--security-group-rule-ids", opts~option("rule", ""), "--output", "json")
  end
  else return .Array~of(.nil, "unsupported firewall action: " || action)
  self~addContext(args, opts)
  return .Array~of(args, "")


::class OciProvider subclass CloudProvider public
::method init
  self~init:super("oci", "oci", "Oracle Cloud Infrastructure")

::method addContext
  use arg args, opts
  self~addArg(args, "--profile", opts~option("oci_profile", ""))
  self~addArg(args, "--region", opts~option("region", ""))
  self~addArg(args, "--auth", opts~option("oci_auth", ""))

::method machineList
  use arg exec, opts
  compartment = opts~option("compartment", "")
  if compartment = "" then return .CloudResult~error("OCI machine list requires --compartment")
  args = .Array~of("oci", "compute", "instance", "list", "--compartment-id", compartment, "--all", "--output", "json")
  self~addContext(args, opts)
  got = self~execJson(exec, args)
  if got[2] \= "" then return .CloudResult~error(got[2])
  r = .CloudResult~ok("OCI machine inventory (IP lookup is intentionally separate)")
  rows = .CloudUtil~mapGet(got[1], "data", .nil)
  if .CloudUtil~isArray(rows) then do vm over rows
    id = .CloudUtil~mapGet(vm, "id", "")
    name = .CloudUtil~mapGet(vm, "display-name", "")
    region = .CloudUtil~mapGet(vm, "availability-domain", "")
    state = .CloudUtil~mapGet(vm, "lifecycle-state", "")
    r["data"]~append(self~machineRecord(id, name, region, state, "", ""))
  end
  return r

::method machineCommand
  use arg action, opts
  machine = opts~option("machine", "")
  if machine = "" then return .Array~of(.nil, "missing required option: --machine")
  select
    when action = "start" then args = .Array~of("oci", "compute", "instance", "action", "--instance-id", machine, "--action", "START")
    when action = "stop" then args = .Array~of("oci", "compute", "instance", "action", "--instance-id", machine, "--action", "SOFTSTOP")
    when action = "reboot" then args = .Array~of("oci", "compute", "instance", "action", "--instance-id", machine, "--action", "SOFTRESET")
    when action = "destroy" then args = .Array~of("oci", "compute", "instance", "terminate", "--instance-id", machine, "--force")
    otherwise return .Array~of(.nil, "unsupported machine action: " || action)
  end
  self~addContext(args, opts)
  return .Array~of(args, "")

::method machineCreate
  use arg opts
  missing = self~require(opts, .Array~of("compartment", "availability_domain", "subnet", "image", "size", "name"))
  if missing \= "" then return .Array~of(.nil, missing)
  args = .Array~of("oci", "compute", "instance", "launch", "--compartment-id", opts~option("compartment", ""), "--availability-domain", opts~option("availability_domain", ""), "--subnet-id", opts~option("subnet", ""), "--image-id", opts~option("image", ""), "--shape", opts~option("size", ""), "--display-name", opts~option("name", ""))
  self~addArg(args, "--ssh-authorized-keys-file", opts~option("ssh_key", ""))
  self~addContext(args, opts)
  return .Array~of(args, "")

::method firewallList
  use arg exec, opts
  scope = opts~option("scope", "")
  if scope = "" then return .CloudResult~error("missing required option: --scope (OCI NSG OCID)")
  args = .Array~of("oci", "network", "nsg", "rules", "list", "--nsg-id", scope, "--all", "--output", "json")
  self~addContext(args, opts)
  got = self~execJson(exec, args)
  if got[2] \= "" then return .CloudResult~error(got[2])
  r = .CloudResult~ok("OCI NSG rules")
  rows = .CloudUtil~mapGet(got[1], "data", .nil)
  if .CloudUtil~isArray(rows) then do rule over rows
    rid = .CloudUtil~mapGet(rule, "id", "")
    direction = .CloudUtil~mapGet(rule, "direction", "")
    protocol = .CloudUtil~mapGet(rule, "protocol", "")
    source = .CloudUtil~firstNonEmpty(.CloudUtil~mapGet(rule, "source", ""), .CloudUtil~mapGet(rule, "destination", ""), "", "")
    desc = .CloudUtil~mapGet(rule, "description", "")
    ports = ""
    tcp = .CloudUtil~mapGet(rule, "tcp-options", .nil)
    if tcp \= .nil then do
      dpr = .CloudUtil~mapGet(tcp, "destination-port-range", .nil)
      if dpr \= .nil then do
        pmin = .CloudUtil~mapGet(dpr, "min", "")
        pmax = .CloudUtil~mapGet(dpr, "max", "")
        if pmin = pmax then ports = pmin
        else if pmin \= "" then ports = pmin || "-" || pmax
      end
    end
    r["data"]~append(self~firewallRecord(rid, scope, direction, protocol, ports, source, desc))
  end
  return r

::method firewallCommand
  use arg action, opts
  scope = opts~option("scope", "")
  if scope = "" then return .Array~of(.nil, "missing required option: --scope (OCI NSG OCID)")
  if action = "allow" then do
    missing = self~require(opts, .Array~of("protocol", "source"))
    if missing \= "" then return .Array~of(.nil, missing)
    protoName = .CloudUtil~lower(opts~option("protocol", ""))
    select
      when protoName = "tcp" then proto = "6"
      when protoName = "udp" then proto = "17"
      when protoName = "icmp" then proto = "1"
      when protoName = "all" then proto = "all"
      otherwise return .Array~of(.nil, "OCI protocol must be tcp, udp, icmp or all")
    end
    desc = opts~option("description", opts~option("rule", "cloudctl rule"))
    json = '[{"direction":"INGRESS","protocol":"' || proto || '","source":"' || opts~option("source", "") || '","sourceType":"CIDR_BLOCK","description":' || .CloudJson~quote(desc)
    if protoName = "tcp" | protoName = "udp" then do
      port = opts~option("port", "")
      if port = "" then return .Array~of(.nil, "OCI tcp/udp allow requires --port")
      optName = protoName || "Options"
      json = json || ',"' || optName || '":{"destinationPortRange":{"min":' || port || ',"max":' || port || '}}'
    end
    json = json || '}]'
    args = .Array~of("oci", "network", "nsg", "rules", "add", "--nsg-id", scope, "--security-rules", json)
  end
  else if action = "revoke" then do
    if opts~option("rule", "") = "" then return .Array~of(.nil, "missing required option: --rule (OCI security-rule id)")
    json = '["' || opts~option("rule", "") || '"]'
    args = .Array~of("oci", "network", "nsg", "rules", "remove", "--nsg-id", scope, "--security-rule-ids", json, "--force")
  end
  else return .Array~of(.nil, "unsupported firewall action: " || action)
  self~addContext(args, opts)
  return .Array~of(args, "")


::class VultrProvider subclass CloudProvider public
::method init
  self~init:super("vultr", "vultr-cli", "Vultr")

::method addContext
  use arg args, opts
  self~addArg(args, "--config", opts~option("vultr_config", ""))

::method machineList
  use arg exec, opts
  args = .Array~of("vultr-cli", "instance", "list", "--output", "json")
  self~addContext(args, opts)
  got = self~execJson(exec, args)
  if got[2] \= "" then return .CloudResult~error(got[2])
  root = got[1]
  rows = root
  if root~isA(.Directory) then do
    rows = .CloudUtil~mapGet(root, "instances", .CloudUtil~mapGet(root, "Instances", .nil))
  end
  r = .CloudResult~ok("Vultr machine inventory")
  if .CloudUtil~isArray(rows) then do vm over rows
    id = .CloudUtil~mapGet(vm, "id", "")
    name = .CloudUtil~firstNonEmpty(.CloudUtil~mapGet(vm, "label", ""), .CloudUtil~mapGet(vm, "hostname", ""), id, "")
    region = .CloudUtil~mapGet(vm, "region", "")
    state = .CloudUtil~firstNonEmpty(.CloudUtil~mapGet(vm, "status", ""), .CloudUtil~mapGet(vm, "server_status", ""), "", "")
    pub = .CloudUtil~firstNonEmpty(.CloudUtil~mapGet(vm, "main_ip", ""), .CloudUtil~mapGet(vm, "mainIp", ""), "", "")
    priv = .CloudUtil~firstNonEmpty(.CloudUtil~mapGet(vm, "internal_ip", ""), .CloudUtil~mapGet(vm, "internalIp", ""), "", "")
    r["data"]~append(self~machineRecord(id, name, region, state, pub, priv))
  end
  return r

::method machineCommand
  use arg action, opts
  machine = opts~option("machine", "")
  if machine = "" then return .Array~of(.nil, "missing required option: --machine")
  select
    when action = "start" then verb = "start"
    when action = "stop" then verb = "stop"
    when action = "reboot" then verb = "restart"
    when action = "destroy" then verb = "delete"
    otherwise return .Array~of(.nil, "unsupported machine action: " || action)
  end
  args = .Array~of("vultr-cli", "instance", verb, machine, "--output", "json")
  self~addContext(args, opts)
  return .Array~of(args, "")

::method machineCreate
  use arg opts
  missing = self~require(opts, .Array~of("name", "region", "size"))
  if missing \= "" then return .Array~of(.nil, missing)
  if opts~option("os", "") = "" & opts~option("image", "") = "" then return .Array~of(.nil, "Vultr create requires --os or --image")
  args = .Array~of("vultr-cli", "instance", "create", "--region", opts~option("region", ""), "--plan", opts~option("size", ""), "--label", opts~option("name", ""), "--output", "json")
  self~addArg(args, "--os", opts~option("os", ""))
  self~addArg(args, "--image", opts~option("image", ""))
  self~addArg(args, "--ssh-keys", opts~option("ssh_keys", ""))
  self~addArg(args, "--firewall-group", opts~option("firewall_group", ""))
  self~addArg(args, "--tags", opts~option("tags", ""))
  self~addContext(args, opts)
  return .Array~of(args, "")

::method firewallList
  use arg exec, opts
  scope = opts~option("scope", "")
  if scope = "" then return .CloudResult~error("missing required option: --scope (Vultr firewall-group id)")
  args = .Array~of("vultr-cli", "firewall", "rule", "list", scope, "--output", "json")
  self~addContext(args, opts)
  got = self~execJson(exec, args)
  if got[2] \= "" then return .CloudResult~error(got[2])
  root = got[1]
  rows = root
  if root~isA(.Directory) then rows = .CloudUtil~mapGet(root, "firewall_rules", .CloudUtil~mapGet(root, "rules", .nil))
  r = .CloudResult~ok("Vultr firewall rules")
  if .CloudUtil~isArray(rows) then do rule over rows
    rid = .CloudUtil~mapGet(rule, "id", "")
    protocol = .CloudUtil~mapGet(rule, "protocol", "")
    ports = .CloudUtil~mapGet(rule, "port", "")
    subnet = .CloudUtil~mapGet(rule, "subnet", "")
    size = .CloudUtil~mapGet(rule, "subnet_size", .CloudUtil~mapGet(rule, "subnetSize", ""))
    if subnet \= "" & size \= "" then source = subnet || "/" || size
    else source = subnet
    desc = .CloudUtil~mapGet(rule, "notes", "")
    r["data"]~append(self~firewallRecord(rid, scope, "INGRESS", protocol, ports, source, desc))
  end
  return r

::method firewallCommand
  use arg action, opts
  scope = opts~option("scope", "")
  if scope = "" then return .Array~of(.nil, "missing required option: --scope (Vultr firewall-group id)")
  if action = "allow" then do
    missing = self~require(opts, .Array~of("protocol", "source"))
    if missing \= "" then return .Array~of(.nil, missing)
    cidr = .CloudUtil~splitCidr(opts~option("source", ""))
    if cidr[1]~pos(":") > 0 then ipType = "v6"
    else ipType = "v4"
    args = .Array~of("vultr-cli", "firewall", "rule", "create", "--id", scope, "--ip-type", ipType, "--protocol", opts~option("protocol", ""), "--subnet", cidr[1], "--size", cidr[2], "--output", "json")
    self~addArg(args, "--port", opts~option("port", ""))
    self~addArg(args, "--notes", opts~option("description", opts~option("rule", "")))
  end
  else if action = "revoke" then do
    if opts~option("rule", "") = "" then return .Array~of(.nil, "missing required option: --rule")
    args = .Array~of("vultr-cli", "firewall", "rule", "delete", scope, opts~option("rule", ""), "--output", "json")
  end
  else return .Array~of(.nil, "unsupported firewall action: " || action)
  self~addContext(args, opts)
  return .Array~of(args, "")


::class CloudRegistry public
::method init
  expose providers aliases
  providers = .Directory~new
  aliases = .Directory~new
  self~put(.AzureProvider~new)
  self~put(.VultrProvider~new)
  self~put(.GcpProvider~new)
  self~put(.AwsProvider~new)
  self~put(.OciProvider~new)
  aliases["az"] = "azure"
  aliases["azure"] = "azure"
  aliases["vultr"] = "vultr"
  aliases["gcloud"] = "gcp"
  aliases["google"] = "gcp"
  aliases["gcp"] = "gcp"
  aliases["amazon"] = "aws"
  aliases["amazon-web-services"] = "aws"
  aliases["aws"] = "aws"
  aliases["oci"] = "oci"
  aliases["oracle"] = "oci"

::method put private
  expose providers
  use arg provider
  providers[provider~id] = provider

::method resolve
  expose providers aliases
  use arg name
  key = .CloudUtil~lower(name)
  if aliases~hasIndex(key) then key = aliases[key]
  if providers~hasIndex(key) then return providers[key]
  return .nil

::method all
  expose providers
  a = .Array~new
  do id over providers~allIndexes
    a~append(providers[id])
  end
  return a


::class CloudRenderer public
::method render
  use arg reply, jsonMode
  if jsonMode then do
    say .CloudJson~encode(reply)
    return
  end
  say reply["status"] || ": " || reply["message"]
  if reply~hasIndex("workspace") then say "Workspace: " || reply["workspace"]
  if reply~hasIndex("command") then say "Command:   " || reply["command"]
  data = reply["data"]
  if data~items = 0 then return
  first = data[1]
  if first~hasIndex("handle") then self~machineTable(data)
  else if first~hasIndex("rule") then self~firewallTable(data)
  else self~genericRows(data)

::method machineTable private
  use arg data
  say ""
  say "PROVIDER HANDLE                       NAME                 REGION/ZONE          STATE          PUBLIC IP"
  say "-------- ---------------------------- -------------------- -------------------- -------------- ----------------"
  do row over data
    say .CloudUtil~truncate(row["provider"],8)~left(8) .CloudUtil~truncate(row["handle"],28)~left(28) .CloudUtil~truncate(row["name"],20)~left(20) .CloudUtil~truncate(row["region"],20)~left(20) .CloudUtil~truncate(row["state"],14)~left(14) .CloudUtil~truncate(row["public_ip"],16)~left(16)
  end

::method firewallTable private
  use arg data
  say ""
  say "PROVIDER RULE                         DIR      PROTO   PORTS        SOURCE                   SCOPE"
  say "-------- ---------------------------- -------- ------- ------------ ------------------------ ------------------------"
  do row over data
    say .CloudUtil~truncate(row["provider"],8)~left(8) .CloudUtil~truncate(row["rule"],28)~left(28) .CloudUtil~truncate(row["direction"],8)~left(8) .CloudUtil~truncate(row["protocol"],7)~left(7) .CloudUtil~truncate(row["ports"],12)~left(12) .CloudUtil~truncate(row["source"],24)~left(24) .CloudUtil~truncate(row["scope"],24)~left(24)
  end

::method genericRows private
  use arg data
  do row over data
    say .CloudJson~encode(row)
  end


::class CloudApp public
::method init
  expose registry renderer
  registry = .CloudRegistry~new
  renderer = .CloudRenderer~new

::method run
  expose registry renderer
  use arg raw
  argFile = .CloudUtil~env("OOREXX_CLOUDCTL_ARGFILE", "")
  if argFile \= "" then do
    tokens = .CloudUtil~readLines(argFile)
    if tokens~items = 0 then return self~interactive
    return self~runCommand("", .false, tokens)
  end
  if strip(raw) = "" then return self~interactive
  return self~runCommand(raw, .false)

::method runTokens
  use arg tokens, interactiveMode
  if arg() < 2 then interactiveMode = .false
  return self~runCommand("", interactiveMode, tokens)

::method runCommand
  expose registry renderer
  use arg raw, interactiveMode, tokens
  supplied = arg()
  if supplied < 3 then parsed = .CloudArgs~new(raw)
  else parsed = .CloudArgs~new(raw, tokens)
  if parsed~error \= "" then do
    r = .CloudResult~error(parsed~error)
    renderer~render(r, parsed~option("json", "false") = "true")
    return 2
  end
  if parsed~option("version", "false") = "true" then do
    say "ooRexx Cloud Console 0.1-dev2"
    return 0
  end
  defaultWorkspace = .CloudUtil~env("OOREXX_CLOUDCTL_WORKSPACE", directory())
  workspace = parsed~option("workspace", defaultWorkspace)
  workspace = .CloudUtil~canonicalDirectory(workspace)
  if workspace == .nil then do
    r = .CloudResult~error("workspace does not exist or is not accessible")
    renderer~render(r, parsed~option("json", "false") = "true")
    return 2
  end
  specPath = parsed~option("spec", "")
  if specPath \= "" then parsed~mergeSpec(.CloudSpec~load(specPath, workspace))
  if parsed~error \= "" then do
    r = .CloudResult~error(parsed~error)
    renderer~render(r, parsed~option("json", "false") = "true")
    return 2
  end
  jsonMode = parsed~option("json", "false") = "true"
  wordsA = parsed~words
  if parsed~option("help", "false") = "true" | wordsA~items = 0 then do
    self~help
    return 0
  end
  noun = .CloudUtil~lower(wordsA[1])
  if noun = "help" then do; self~help; return 0; end
  exec = .CloudExec~new(workspace)
  if noun = "providers" then do
    r = self~providers(exec)
    r["workspace"] = workspace
    renderer~render(r, jsonMode)
    if r["status"] = "ERROR" then return 1
    return 0
  end
  if noun = "doctor" then do
    r = self~providers(exec)
    r["message"] = "Provider CLI availability (credentials are not authority and are not inspected)"
    r["workspace"] = workspace
    renderer~render(r, jsonMode)
    return 0
  end
  if noun = "workspace" then do
    r = .CloudResult~ok("Current provider-CLI working directory")
    r["workspace"] = workspace
    renderer~render(r, jsonMode)
    return 0
  end
  if noun = "instance" then noun = "machine"
  if wordsA~items < 2 then do
    r = .CloudResult~error("expected action after " || noun)
    renderer~render(r, jsonMode)
    return 2
  end
  action = .CloudUtil~lower(wordsA[2])
  providerName = parsed~option("provider", "")
  provider = registry~resolve(providerName)
  if provider == .nil then do
    r = .CloudResult~error("unknown or missing --provider; use azure, vultr, gcp, aws, or oci")
    renderer~render(r, jsonMode)
    return 2
  end
  if noun = "machine" then r = self~machine(provider, action, exec, parsed, interactiveMode)
  else if noun = "firewall" then r = self~firewall(provider, action, exec, parsed, interactiveMode)
  else r = .CloudResult~error("unknown command: " || noun)
  r["workspace"] = workspace
  renderer~render(r, jsonMode)
  if r["status"] = "ERROR" then return 1
  return 0

::method providers private
  expose registry
  use arg exec
  r = .CloudResult~ok("Supported cloud providers")
  do p over registry~all
    row = .Directory~new
    row["provider"] = p~id
    row["title"] = p~title
    row["executable"] = p~executable
    probeArgs = .Array~of("sh", "-c", "command -v " || p~executable)
    probe = exec~run(probeArgs)
    if probe["rc"] = "0" then row["available"] = "yes"
    else row["available"] = "no"
    r["data"]~append(row)
  end
  return r

::method machine private
  use arg provider, action, exec, opts, interactiveMode
  if action = "list" then return provider~machineList(exec, opts)
  if action = "create" then built = provider~machineCreate(opts)
  else built = provider~machineCommand(action, opts)
  if built == .nil then return .CloudResult~error("provider could not build machine action")
  if built[1] == .nil then return .CloudResult~error(built[2])
  return self~mutation(provider, "machine." || action, built[1], exec, opts, interactiveMode)

::method firewall private
  use arg provider, action, exec, opts, interactiveMode
  if action = "list" then return provider~firewallList(exec, opts)
  built = provider~firewallCommand(action, opts)
  if built == .nil then return .CloudResult~error("provider could not build firewall action")
  if built[1] == .nil then return .CloudResult~error(built[2])
  return self~mutation(provider, "firewall." || action, built[1], exec, opts, interactiveMode)

::method mutation private
  use arg provider, action, args, exec, opts, interactiveMode
  cmd = exec~commandText(args)
  if cmd == .nil then return .CloudResult~error("unsafe provider command argument")
  apply = opts~option("apply", "false") = "true"
  if action = "machine.destroy" then do
    machine = opts~option("machine", "")
    confirm = opts~option("confirm", "")
    if apply & confirm \= machine then return .CloudResult~error("destroy requires --apply --confirm EXACT_MACHINE_HANDLE")
  end
  if \apply then return .CloudResult~planned("No cloud mutation executed. Re-run with --apply after reviewing the command.", provider~id, action, cmd)
  if interactiveMode then do
    say ""
    say "About to APPLY: " || cmd
    say "Type APPLY to continue:"
    pull answer
    if .CloudUtil~upper(strip(answer)) \= "APPLY" then return .CloudResult~planned("Interactive apply cancelled", provider~id, action, cmd)
  end
  raw = exec~run(args)
  if raw["rc"] \= "0" then do
    msg = strip(raw["stderr"])
    if msg = "" then msg = strip(raw["stdout"])
    if msg = "" then msg = "provider command failed rc=" || raw["rc"]
    r = .CloudResult~error(msg)
    r["provider"] = provider~id
    r["action"] = action
    r["command"] = cmd
    return r
  end
  return .CloudResult~applied("Provider command completed", provider~id, action, cmd, raw["stdout"])

::method interactive private
  expose registry
  say "ooRexx Cloud Console 0.1-dev2"
  say "Provider-neutral lifecycle + firewall console"
  say "Mutations are PLAN-only unless --apply is present; interactive apply asks again."
  say "Type help, or quit."
  provider = ""
  workspace = .CloudUtil~canonicalDirectory(.CloudUtil~env("OOREXX_CLOUDCTL_WORKSPACE", directory()))
  if workspace == .nil then workspace = directory()
  do forever
    if provider = "" then prompt = "cloud[none]> "
    else prompt = "cloud[" || provider || "]> "
    call charout , prompt
    pull line
    line = strip(line)
    if line = "" then iterate
    low = .CloudUtil~lower(line)
    if low = "quit" | low = "exit" then return 0
    if low~left(4) = "use " then do
      wanted = strip(low~substr(5))
      p = registry~resolve(wanted)
      if p == .nil then say "Unknown provider: " || wanted
      else do; provider = p~id; say "Provider: " || provider; end
      iterate
    end
    if low~left(10) = "workspace " then do
      wanted = strip(line~substr(11))
      resolved = .CloudUtil~canonicalDirectory(wanted)
      if resolved == .nil then say "Workspace not accessible: " || wanted
      else do; workspace = resolved; say "Workspace: " || workspace; end
      iterate
    end
    if low = "help" then do; self~interactiveHelp; iterate; end
    cmd = line
    if provider \= "" & line~pos("--provider") = 0 then cmd = cmd || " --provider " || provider
    oldWorkspace = value("OOREXX_CLOUDCTL_WORKSPACE",, "ENVIRONMENT")
    call value "OOREXX_CLOUDCTL_WORKSPACE", workspace, "ENVIRONMENT"
    self~runCommand(cmd, .true)
    call value "OOREXX_CLOUDCTL_WORKSPACE", oldWorkspace, "ENVIRONMENT"
  end

::method interactiveHelp private
  say ""
  say "Interactive commands:"
  say "  use azure|vultr|gcp|aws|oci"
  say "  workspace /path/for/provider-cli-cwd"
  say "  machine list"
  say "  machine start|stop|reboot --machine HANDLE [--zone ZONE] [--apply]"
  say "  machine destroy --machine HANDLE --apply --confirm HANDLE"
  say "  machine create --spec examples/specs/... [--apply]"
  say "  firewall list --scope SCOPE"
  say "  firewall allow --scope SCOPE --rule NAME --protocol tcp --port 22 --source CIDR [--apply]"
  say "  firewall revoke --scope SCOPE --rule RULE_ID_OR_NAME [--apply]"
  say "  quit"

::method help private
  say "ooRexx Cloud Console 0.1-dev2"
  say ""
  say "Usage:"
  say "  cloudctl.rex providers [--json] [--workspace DIR]"
  say "  cloudctl.rex workspace [--json] [--workspace DIR]"
  say "  cloudctl.rex machine list --provider P [provider context] [--json]"
  say "  cloudctl.rex machine start|stop|reboot --provider P --machine HANDLE [--zone Z] [--apply]"
  say "  cloudctl.rex machine destroy --provider P --machine HANDLE --apply --confirm HANDLE"
  say "  cloudctl.rex machine create --provider P --spec FILE [--apply]"
  say "  cloudctl.rex firewall list --provider P --scope SCOPE [--json]"
  say "  cloudctl.rex firewall allow --provider P --scope SCOPE --rule NAME --protocol tcp --port 22 --source CIDR [--apply]"
  say "  cloudctl.rex firewall revoke --provider P --scope SCOPE --rule RULE_ID_OR_NAME [--apply]"
  say ""
  say "Providers and aliases: azure/az, vultr, gcp/gcloud, aws/amazon, oci/oracle"
  say ""
  say "Safety:"
  say "  * mutations are plans unless --apply is explicit"
  say "  * destroy additionally requires --confirm to exactly equal --machine"
  say "  * credentials are never accepted as command/spec fields; provider CLIs own authentication"
  say "  * --workspace changes provider CLI working directory only; it is not authority or identity"
  say "  * OOREXX_CLOUDCTL_WORKSPACE is the robust Codex/automation override, including paths with spaces"
  say "  * values containing whitespace belong in a --spec key=value file"
  say ""
  say "Provider context:"
  say "  Azure: --subscription ID, --group RG; firewall scope RG:NSG"
  say "  GCP: --project ID, --configuration NAME; mutations require --zone; firewall scope NETWORK"
  say "  AWS: --region REGION, --aws_profile NAME; firewall scope SECURITY_GROUP_ID"
  say "  OCI: --compartment OCID, --region REGION, --oci_profile NAME, --oci_auth TYPE; firewall scope NSG_OCID"
  say "  Vultr: --vultr_config PATH; firewall scope FIREWALL_GROUP_ID"
