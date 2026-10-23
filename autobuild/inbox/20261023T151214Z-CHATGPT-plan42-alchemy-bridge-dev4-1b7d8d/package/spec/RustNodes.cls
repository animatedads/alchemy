/* RustNodes.cls -- OO Rust code-generation node tree for Plan42        */
/* Each class represents one Rust construct.                             */
/* Usage: build a tree of RustNode objects from the spec, then call     */
/*        root~render('') to get the complete Rust source.              */
/* Convention: all generated variables prefixed _p42_ to avoid clashes  */
/* String type used everywhere; .clone() / .to_string() as needed.      */

/* ================================================================== */
/* RustNode -- abstract base                                            */
/* ================================================================== */
::class RustNode public
::method render
  use arg ind
  if ind = .nil then ind = ''
  return ''


/* ================================================================== */
/* Leaf / expression nodes                                             */
/* ================================================================== */

::class RustLiteral subclass RustNode public
::method init
  expose _val
  use arg val
  _val = val
::method val
  expose _val
  return _val
::method render
  expose _val
  use arg ind
  if ind = .nil then ind = ''
  v = _val
  if v = .nil then return 'None'
  if v~isA(.Array) then do
    out = 'vec!['
    do i = 1 to v~items
      if i > 1 then out = out||', '
      out = out||(.RustLiteral~new(v~at(i))~render(''))
    end
    return out||']'
  end
  if v~isA(.Directory) then do
    out = '{'
    out = out||'let mut _m = std::collections::HashMap::new(); '
    first = .true
    do k over v~allIndexes
      out = out||'_m.insert('
      out = out||(.RustLiteral~new(k)~render(''))||'.to_string(), '
      out = out||(.RustLiteral~new(v~at(k))~render(''))||'.to_string()); '
      first = .false
    end
    return out||'_m}'
  end
  s = ''||v
  if datatype(s, 'N') then return s
  /* true/false booleans */
  if s = '1' | translate(s) = 'TRUE'  then return 'true'
  if s = '0' | translate(s) = 'FALSE' then return 'false'
  s = s~changeStr('\', '\\')
  s = s~changeStr('"', '\"')
  s = s~changeStr('0a'x, '\n')
  s = s~changeStr('09'x, '\t')
  s = s~changeStr('0d'x, '\r')
  return '"'||s||'"'


::class RustVar subclass RustNode public
::method init
  expose _name
  use arg name
  _name = name
::method render
  expose _name
  use arg ind
  if ind = .nil then ind = ''
  return _name


::class RustConcat subclass RustNode public
::method init
  expose _l _r
  use arg l, r
  _l = l; _r = r
::method render
  expose _l _r
  use arg ind
  if ind = .nil then ind = ''
  return 'format!("{}{}", '||_l~render('')||', '||_r~render('')||')'


::class RustFormat subclass RustNode public
/* FORMAT op: template with named slots {name}                          */
::method init
  expose _tmpl _args
  use arg tmpl, args
  _tmpl = tmpl; _args = args
::method render
  expose _tmpl _args
  use arg ind
  if ind = .nil then ind = ''
  /* Build format!("template", args...) */
  /* Replace {name} slots with {} and collect arg expressions          */
  fmtStr = _tmpl
  argStr = ''
  if _args \= .nil then do
    do k over _args~allIndexes
      fmtStr = fmtStr~changeStr('{'||k||'}', '{}')
      if argStr \= '' then argStr = argStr||', '
      argStr = argStr||_args~at(k)~render('')
    end
  end
  if argStr = '' then return 'format!("'||fmtStr||'")'
  return 'format!("'||fmtStr||'", '||argStr||')'


::class RustBinOp subclass RustNode public
::method init
  expose _l _op _r
  use arg l, op, r
  _l = l; _op = op; _r = r
::method render
  expose _l _op _r
  use arg ind
  if ind = .nil then ind = ''
  return '('||_l~render('')||' '||_op||' '||_r~render('')||')'


::class RustNot subclass RustNode public
::method init
  expose _e
  use arg e
  _e = e
::method render
  expose _e
  use arg ind
  if ind = .nil then ind = ''
  return '!('||_e~render('')||')'


::class RustIn subclass RustNode public
::method init
  expose _item _coll
  use arg item, coll
  _item = item; _coll = coll
::method render
  expose _item _coll
  use arg ind
  if ind = .nil then ind = ''
  return _coll~render('')||'.contains(&'||_item~render('')||'.to_string())'


::class RustCast subclass RustNode public
::method init
  expose _expr _to
  use arg expr, to
  _expr = expr; _to = to
::method render
  expose _expr _to
  use arg ind
  if ind = .nil then ind = ''
  inner = _expr~render('')
  t = translate(_to)
  select
    when t = 'STR'   then return inner||'.to_string()'
    when t = 'INT'   then return inner||'.parse::<i64>().unwrap_or(0)'
    when t = 'FLOAT' then return inner||'.parse::<f64>().unwrap_or(0.0)'
    when t = 'BOOL'  then return '!'||inner||'.is_empty()'
    when t = 'LIST'  then return 'vec!['||inner||']'
    otherwise        return inner
  end


::class RustCallExpr subclass RustNode public
::method init
  expose _func _args
  use arg func, args
  _func = func; _args = args
::method render
  expose _func _args
  use arg ind
  if ind = .nil then ind = ''
  argStr = ''
  if _args \= .nil then do
    do i = 1 to _args~items
      if i > 1 then argStr = argStr||', '
      argStr = argStr||_args~at(i)~render('')
    end
  end
  return _func||'('||argStr||')'


::class RustIndex subclass RustNode public
::method init
  expose _obj _idx
  use arg obj, idx
  _obj = obj; _idx = idx
::method render
  expose _obj _idx
  use arg ind
  if ind = .nil then ind = ''
  return _obj~render('')||'.get('||_idx~render('')||').map(|v| v.as_str().unwrap_or("")).unwrap_or("")'


::class RustMethodExpr subclass RustNode public
::method init
  expose _obj _meth _args
  use arg obj, meth, args
  _obj = obj; _meth = meth; _args = args
::method render
  expose _obj _meth _args
  use arg ind
  if ind = .nil then ind = ''
  obj  = _obj~render('')
  meth = _meth
  argStr = ''
  if _args \= .nil then do
    do i = 1 to _args~items
      if i > 1 then argStr = argStr||', '
      argStr = argStr||_args~at(i)~render('')
    end
  end
  /* Map Python-ism method names to Rust equivalents                   */
  select
    when meth = '__len__'      then return obj||'.len()'
    when meth = '__contains__' then do
      a = argStr~changeStr('.as_str()', '')
      return obj||'.contains(&'||a||')'
    end
    when meth = '__bool__'     then return '!'||obj||'.is_empty()'
    when meth = 'strip'        then return obj||'.trim().to_string()'
    when meth = 'upper'        then return obj||'.to_uppercase()'
    when meth = 'lower'        then return obj||'.to_lowercase()'
    when meth = 'split'        then return obj||'.split('||argStr||').collect::<Vec<_>>()'
    when meth = 'join'         then return argStr||'.join('||obj||')'
    when meth = 'get'          then do
      if _args \= .nil then do
        if _args~items >= 2 then do
          key  = _args~at(1)~render('')
          dflt = _args~at(2)~render('')
          /* HashMap fn call (ends in ()) -- use .get() not panic index */
          if right(obj, 2) = '()' then
            return obj||'.get('||key||').map(|v| v.as_str().unwrap_or("")).unwrap_or('||dflt||')'
          /* serde_json::Value -- subscript OK (returns Null not panic) */
          return obj||'['||key||'].as_str().unwrap_or('||dflt||')'
        end
        if _args~items = 1 then
          return obj||'.get('||_args~at(1)~render('')||')'
      end
      return obj||'.get("")'
    end
    when meth = 'startswith'   then return obj||'.starts_with('||argStr||')'
    when meth = 'endswith'     then return obj||'.ends_with('||argStr||')'
    otherwise                  return obj||'.'||meth||'('||argStr||')'
  end


::class RustTernary subclass RustNode public
::method init
  expose _cond _then _else
  use arg cond, thenv, elsev
  _cond = cond; _then = thenv; _else = elsev
::method render
  expose _cond _then _else
  use arg ind
  if ind = .nil then ind = ''
  return 'if '||_cond~render('')||' { '||_then~render('')||' } else { '||_else~render('')||' }'


/* ================================================================== */
/* Statement nodes                                                     */
/* ================================================================== */

::class RustLet subclass RustNode public
::method init
  expose _name _type _expr
  use arg name, typ, expr
  _name = name; _type = typ; _expr = expr
::method render
  expose _name _type _expr
  use arg ind
  if ind = .nil then ind = ''
  /* R1: no type? let Rust infer rather than guess String           */
  if _type = .nil then do
    if _expr = .nil then
      return ind||'let mut '||_name||' = String::new(); /* Plan42: infer */'
    return ind||'let mut '||_name||' = '||_expr~render('')||';'
  end
  typeStr = self~rustType(_type)
  if _expr = .nil then
    return ind||'let mut '||_name||': '||typeStr||' = '||self~defaultVal(_type)||';'
  val = _expr~render('')
  /* str-typed lets: ensure owned String from &str expressions        */
  if typeStr = 'String' then do
    /* Don't double-wrap if already .to_string()              */
    if right(val, 12) = '.to_string()' then
      return ind||'let mut '||_name||': String = '||val||';'
    return ind||'let mut '||_name||': String = '||val||'.to_string();'
  end
  return ind||'let mut '||_name||': '||typeStr||' = '||val||';'
::method rustType
  /* Parse Plan42 type annotation to Rust type.                        */
  /* Supports: str, int, float, bool, list, dict, option,             */
  /*           list<T>, dict<K,V>, option<T>, result<T,E>             */
  use arg t
  if t = .nil then return 'String'
  /* Already a concrete Rust type -- pass through unchanged           */
  if pos('<', t) > 0             then return t
  if left(t,3) = 'Vec'           then return t
  if left(t,7) = 'HashMap'       then return t
  if left(t,6) = 'Option'        then return t
  if left(t,6) = 'Result'        then return t
  if left(t,4) = 'impl'          then return t
  if t = 'Handles'               then return t
  if t = '()'                    then return t
  if t = 'serde_json::Value'     then return t
  tUp = translate(strip(t))
  /* Generic types: list<T>, dict<K,V>, option<T>, result<T,E>        */
  if pos('<', t) > 0 then do
    base  = translate(strip(left(t, pos('<', t)-1)))
    inner = strip(substr(t, pos('<', t)+1))
    if right(inner, 1) = '>' then inner = left(inner, length(inner)-1)
    select
      when base = 'LIST'   then return 'Vec<'||self~innerType(inner)||'>'
      when base = 'DICT'   then do
        comma = pos(',', inner)
        if comma > 0 then do
          k = strip(left(inner, comma-1))
          v = strip(substr(inner, comma+1))
          return 'HashMap<'||self~innerType(k)||', '||self~innerType(v)||'>'
        end
        return 'HashMap<String, String>'
      end
      when base = 'OPTION' then return 'Option<'||self~innerType(inner)||'>'
      when base = 'RESULT' then do
        comma = pos(',', inner)
        if comma > 0 then do
          ok  = strip(left(inner, comma-1))
          err = strip(substr(inner, comma+1))
          return 'Result<'||self~innerType(ok)||', '||self~innerType(err)||'>'
        end
        return 'Result<'||self~innerType(inner)||', Box<dyn std::error::Error>>'
      end
      otherwise return 'String'
    end
  end
  /* Primitive types */
  select
    when tUp = 'STR'    then return 'String'
    when tUp = 'INT'    then return 'i64'
    when tUp = 'FLOAT'  then return 'f64'
    when tUp = 'BOOL'   then return 'bool'
    when tUp = 'LIST'   then return 'Vec<String>'
    when tUp = 'DICT'   then return 'HashMap<String, String>'
    when tUp = 'OPTION' then return 'Option<String>'
    when tUp = 'NIL'    then return 'Option<String>'
    when tUp = 'BYTES'  then return 'Vec<u8>'
    when tUp = 'ERROR'  then return 'Box<dyn std::error::Error>'
    otherwise           return 'String'
  end

::method innerType
  /* Convert inner type annotation to Rust type (no generics)         */
  use arg t
  if t = .nil then return 'String'
  select
    when translate(t) = 'STR'   then return 'String'
    when translate(t) = 'INT'   then return 'i64'
    when translate(t) = 'FLOAT' then return 'f64'
    when translate(t) = 'BOOL'  then return 'bool'
    when translate(t) = 'BYTES' then return 'Vec<u8>'
    otherwise                   return 'String'
  end

::method paramType
  /* For function params: prefer &str over String for string inputs,  */
  /* owned types for collections.                                      */
  use arg t
  if t = .nil then return '&str'
  tUp = translate(strip(t))
  if pos('<', t) > 0 then return self~rustType(t)  /* generics: owned */
  select
    when tUp = 'STR'    then return '&str'
    when tUp = 'INT'    then return 'i64'
    when tUp = 'FLOAT'  then return 'f64'
    when tUp = 'BOOL'   then return 'bool'
    when tUp = 'LIST'   then return '&[String]'
    when tUp = 'DICT'   then return '&HashMap<String, String>'
    when tUp = 'OPTION' then return 'Option<&str>'
    otherwise           return '&str'
  end
::method defaultVal
  use arg t
  if t = .nil then return 'String::new()'
  /* Already a Rust type -- pass through                             */
  if pos('<', t) > 0             then return t
  if left(t,3) = 'Vec'           then return t
  if left(t,7) = 'HashMap'       then return t
  if left(t,6) = 'Option'        then return t
  if left(t,6) = 'Result'        then return t
  if left(t,4) = 'impl'          then return t
  if t = 'Handles'               then return t
  if t = '()'                    then return t
  if t = 'serde_json::Value'     then return t
  tUp = translate(strip(t))
  if pos('<', t) > 0 then do
    base = translate(strip(left(t, pos('<', t)-1)))
    select
      when base = 'LIST'   then return 'Vec::new()'
      when base = 'DICT'   then return 'HashMap::new()'
      when base = 'OPTION' then return 'None'
      when base = 'RESULT' then return 'Ok(())'
      otherwise            return 'String::new()'
    end
  end
  select
    when tUp = 'STR'    then return 'String::new()'
    when tUp = 'INT'    then return '0'
    when tUp = 'FLOAT'  then return '0.0'
    when tUp = 'BOOL'   then return 'false'
    when tUp = 'LIST'   then return 'Vec::new()'
    when tUp = 'DICT'   then return 'HashMap::new()'
    when tUp = 'OPTION' then return 'None'
    when tUp = 'NIL'    then return 'None'
    when tUp = 'BYTES'  then return 'Vec::new()'
    otherwise           return 'String::new()'
  end


::class RustAssign subclass RustNode public
::method init
  expose _name _expr
  use arg name, expr
  _name = name; _expr = expr
::method render
  expose _name _expr
  use arg ind
  if ind = .nil then ind = ''
  return ind||_name||' = '||_expr~render('')||';'


::class RustReturn subclass RustNode public
::method init
  expose _e
  use arg e
  _e = e
::method render
  expose _e
  use arg ind
  if ind = .nil then ind = ''
  if _e = .nil then return ind||'return;'
  return ind||_e~render('')  /* last expression = implicit return */


::class RustExprStmt subclass RustNode public
::method init
  expose _e
  use arg e
  _e = e
::method render
  expose _e
  use arg ind
  if ind = .nil then ind = ''
  return ind||_e~render('')||';'


::class RustPrintln subclass RustNode public
::method init
  expose _e
  use arg e
  _e = e
::method render
  expose _e
  use arg ind
  if ind = .nil then ind = ''
  return ind||'println!("{}", '||_e~render('')||');'


::class RustContinue subclass RustNode public
::method render
  use arg ind
  if ind = .nil then ind = ''
  return ind||'continue;'


::class RustBreak subclass RustNode public
::method render
  use arg ind
  if ind = .nil then ind = ''
  return ind||'break;'


::class RustIf subclass RustNode public
::method init
  expose _cond _body _else
  use arg cond, body, elsebody
  _cond = cond; _body = body; _else = elsebody
::method render
  expose _cond _body _else
  use arg ind
  if ind = .nil then ind = ''
  lf   = '0a'x
  bInd = ind||'    '
  out  = ind||'if '||_cond~render('')||' {'
  if _body = .nil | _body~items = 0 then
    out = out||lf||bInd||'// pass'
  else do
    do stmt over _body; out = out||lf||stmt~render(bInd); end
  end
  out = out||lf||ind||'}'
  if _else \= .nil then do
    if _else~items > 0 then do
      out = out||' else {'
      do stmt over _else; out = out||lf||stmt~render(bInd); end
      out = out||lf||ind||'}'
    end
  end
  return out


::class RustFor subclass RustNode public
::method init
  expose _var _in _body
  use arg var, inExpr, body
  _var = var; _in = inExpr; _body = body
::method render
  expose _var _in _body
  use arg ind
  if ind = .nil then ind = ''
  lf   = '0a'x
  bInd = ind||'    '
  out  = ind||'for '||_var||' in '||_in~render('')||' {'
  if _body = .nil | _body~items = 0 then
    out = out||lf||bInd||'// pass'
  else do
    do stmt over _body; out = out||lf||stmt~render(bInd); end
  end
  return out||lf||ind||'}'


::class RustWhile subclass RustNode public
::method init
  expose _cond _body
  use arg cond, body
  _cond = cond; _body = body
::method render
  expose _cond _body
  use arg ind
  if ind = .nil then ind = ''
  lf   = '0a'x
  bInd = ind||'    '
  out  = ind||'while '||_cond~render('')||' {'
  if _body = .nil | _body~items = 0 then
    out = out||lf||bInd||'// pass'
  else do
    do stmt over _body; out = out||lf||stmt~render(bInd); end
  end
  return out||lf||ind||'}'


::class RustMatch subclass RustNode public
::method init
  expose _expr _arms
  use arg expr, arms
  _expr = expr; _arms = arms
::method render
  expose _expr _arms
  use arg ind
  if ind = .nil then ind = ''
  lf   = '0a'x
  bInd = ind||'    '
  out  = ind||'match '||_expr~render('')||' {'
  if _arms \= .nil then do
    do i = 1 to _arms~items
      arm = _arms~at(i)
      pat = arm~at('pattern')
      if pat = .nil then
        out = out||lf||bInd||'_ => {'
      else
        out = out||lf||bInd||.RustLiteral~new(pat)~render('')||' => {'
      armBody = arm~at('body')
      if armBody \= .nil then do
        do stmt over armBody
          out = out||lf||bInd||'    '||stmt~render(bInd||'    ')~strip('L')
        end
      end
      out = out||lf||bInd||'}'
    end
  end
  return out||lf||ind||'}'


::class RustTry subclass RustNode public
::method init
  expose _body _catches
  use arg body, catches
  _body = body; _catches = catches
::method render
  expose _body _catches
  use arg ind
  if ind = .nil then ind = ''
  lf   = '0a'x
  bInd = ind||'    '
  /* Rust uses Result/? pattern -- emit as closure with match        */
  out = ind||'/* try */ (|| -> Result<(), Box<dyn std::error::Error>> {'
  if _body \= .nil then do
    do stmt over _body; out = out||lf||stmt~render(bInd); end
  end
  out = out||lf||bInd||'Ok(())'
  out = out||lf||ind||'})().unwrap_or_else(|_p42_err| {'
  if _catches \= .nil then do
    do i = 1 to _catches~items
      catch = _catches~at(i)
      cv = catch~at('var')
      if cv \= .nil then
        out = out||lf||bInd||'let '||cv||' = _p42_err.to_string();'
      catchBody = catch~at('body')
      if catchBody \= .nil then do
        do stmt over catchBody; out = out||lf||stmt~render(bInd); end
      end
    end
  end
  return out||lf||ind||'});'


::class RustRaise subclass RustNode public
::method init
  expose _msg
  use arg msg
  _msg = msg
::method render
  expose _msg
  use arg ind
  if ind = .nil then ind = ''
  if _msg = .nil then return ind||'panic!("Plan42 raise");'
  return ind||'panic!("{}", '||_msg~render('')||');'


/* ================================================================== */
/* Function definition                                                 */
/* ================================================================== */

::class RustFn subclass RustNode public
::method init
  expose _name _params _ptypes _rettype _body
  use arg name, params, ptypes, rettype, body
  _name = name; _params = params; _ptypes = ptypes
  _rettype = rettype; _body = body
::method render
  expose _name _params _ptypes _rettype _body
  use arg ind
  if ind = .nil then ind = ''
  lf   = '0a'x
  bInd = ind||'    '
  /* Build param signature                                             */
  paramStr = ''
  if _params \= .nil then do
    do i = 1 to _params~items
      pname = _params~at(i)
      if i > 1 then paramStr = paramStr||', '
      ptype = '&str'
      if _ptypes \= .nil then do
        pt = _ptypes~at(pname)
        if pt \= .nil then ptype = self~paramType(pt)
      end
      paramStr = paramStr||pname||': '||ptype
    end
  end
  /* Return type                                                       */
  retStr = ''
  if _rettype \= .nil then do
    if translate(_rettype) \= 'VOID' then
      retStr = ' -> '||self~rustType(_rettype)
  end
  out = ind||'fn '||_name||'('||paramStr||')'||retStr||' {'
  if _body = .nil | _body~items = 0 then
    out = out||lf||bInd||'// pass'
  else do
    do stmt over _body; out = out||lf||stmt~render(bInd); end
  end
  return out||lf||ind||'}'
::method rustType
  /* Parse Plan42 type annotation to Rust type.                        */
  /* Supports: str, int, float, bool, list, dict, option,             */
  /*           list<T>, dict<K,V>, option<T>, result<T,E>             */
  use arg t
  if t = .nil then return 'String'
  /* Already a concrete Rust type -- pass through unchanged           */
  if pos('<', t) > 0             then return t
  if left(t,3) = 'Vec'           then return t
  if left(t,7) = 'HashMap'       then return t
  if left(t,6) = 'Option'        then return t
  if left(t,6) = 'Result'        then return t
  if left(t,4) = 'impl'          then return t
  if t = 'Handles'               then return t
  if t = '()'                    then return t
  if t = 'serde_json::Value'     then return t
  tUp = translate(strip(t))
  /* Generic types: list<T>, dict<K,V>, option<T>, result<T,E>        */
  if pos('<', t) > 0 then do
    base  = translate(strip(left(t, pos('<', t)-1)))
    inner = strip(substr(t, pos('<', t)+1))
    if right(inner, 1) = '>' then inner = left(inner, length(inner)-1)
    select
      when base = 'LIST'   then return 'Vec<'||self~innerType(inner)||'>'
      when base = 'DICT'   then do
        comma = pos(',', inner)
        if comma > 0 then do
          k = strip(left(inner, comma-1))
          v = strip(substr(inner, comma+1))
          return 'HashMap<'||self~innerType(k)||', '||self~innerType(v)||'>'
        end
        return 'HashMap<String, String>'
      end
      when base = 'OPTION' then return 'Option<'||self~innerType(inner)||'>'
      when base = 'RESULT' then do
        comma = pos(',', inner)
        if comma > 0 then do
          ok  = strip(left(inner, comma-1))
          err = strip(substr(inner, comma+1))
          return 'Result<'||self~innerType(ok)||', '||self~innerType(err)||'>'
        end
        return 'Result<'||self~innerType(inner)||', Box<dyn std::error::Error>>'
      end
      otherwise return 'String'
    end
  end
  /* Primitive types */
  select
    when tUp = 'STR'    then return 'String'
    when tUp = 'INT'    then return 'i64'
    when tUp = 'FLOAT'  then return 'f64'
    when tUp = 'BOOL'   then return 'bool'
    when tUp = 'LIST'   then return 'Vec<String>'
    when tUp = 'DICT'   then return 'HashMap<String, String>'
    when tUp = 'OPTION' then return 'Option<String>'
    when tUp = 'NIL'    then return 'Option<String>'
    when tUp = 'BYTES'  then return 'Vec<u8>'
    when tUp = 'ERROR'  then return 'Box<dyn std::error::Error>'
    otherwise           return 'String'
  end

::method innerType
  /* Convert inner type annotation to Rust type (no generics)         */
  use arg t
  if t = .nil then return 'String'
  select
    when translate(t) = 'STR'   then return 'String'
    when translate(t) = 'INT'   then return 'i64'
    when translate(t) = 'FLOAT' then return 'f64'
    when translate(t) = 'BOOL'  then return 'bool'
    when translate(t) = 'BYTES' then return 'Vec<u8>'
    otherwise                   return 'String'
  end

::method paramType
  /* For function params: prefer &str over String for string inputs,  */
  /* owned types for collections.                                      */
  use arg t
  if t = .nil then return '&str'
  tUp = translate(strip(t))
  if pos('<', t) > 0 then return self~rustType(t)  /* generics: owned */
  select
    when tUp = 'STR'    then return '&str'
    when tUp = 'INT'    then return 'i64'
    when tUp = 'FLOAT'  then return 'f64'
    when tUp = 'BOOL'   then return 'bool'
    when tUp = 'LIST'   then return '&[String]'
    when tUp = 'DICT'   then return '&HashMap<String, String>'
    when tUp = 'OPTION' then return 'Option<&str>'
    otherwise           return '&str'
  end


::class RustConst subclass RustNode public
::method init
  expose _name _type _expr
  use arg name, typ, expr
  _name = name; _type = typ; _expr = expr
::method rawVal
  expose _expr
  if _expr~isA(.RustLiteral) then return _expr~val
  return .nil
::method render
  expose _name _type _expr
  use arg ind
  if ind = .nil then ind = ''
  lf  = '0a'x
  raw = self~rawVal
  /* R4: Array -> static &[&str]                                      */
  if raw \= .nil then do
    if raw~isA(.Array) then do
      out = 'static '||_name||': &[&str] = &['
      do i = 1 to raw~items
        if i > 1 then out = out||', '
        s = (''||raw~at(i))~changeStr('"', '\"')
        out = out||'"'||s||'"'
      end
      return out||'];'
    end
    /* Dict -> static pairs slice + accessor fn                       */
    if raw~isA(.Directory) then do
      out = 'static '||_name||'_PAIRS: &[(&str,&str)] = &['
      first = .true
      do k over raw~allIndexes
        if \first then out = out||', '
        ks = (''||k)~changeStr('"', '\"')
        vs = (''||raw~at(k))~changeStr('"', '\"')
        out = out||'("'||ks||'","'||vs||'")'
        first = .false
      end
      out = out||'];'||lf
      out = out||'fn '||_name||'() -> std::collections::HashMap<String,String> {'||lf
      out = out||'    '||_name||'_PAIRS.iter()'
      out = out||'.map(|(k,v)| (k.to_string(),v.to_string())).collect()'||lf
      out = out||'}'
      return out
    end
  end
  /* Scalar */
  val = _expr~render('')
  if left(val,1) = '"' then return 'const '||_name||': &str = '||val||';'
  if datatype(val,'N')  then return 'const '||_name||': i64 = '||val||';'
  return '/* const '||_name||' = '||val||' */'


/* ================================================================== */
/* RustRawBlock -- pre-formed Rust (runtime helpers, use decls, etc.) */
/* ================================================================== */
::class RustRawBlock subclass RustNode public
::method init
  expose _lines
  use arg lines
  _lines = lines
::method render
  expose _lines
  use arg ind
  lf  = '0a'x
  out = ''
  do line over _lines; out = out||line||lf; end
  return out


/* ================================================================== */
/* RustModule -- top-level container                                   */
/* ================================================================== */
::class RustModule subclass RustNode public
::method init
  expose _items
  _items = .Array~new
::method add
  expose _items
  use arg node
  _items~append(node)
::method render
  expose _items
  use arg ind
  if ind = .nil then ind = ''
  lf  = '0a'x
  out = ''
  do item over _items; out = out||item~render(ind)||lf; end
  return out


/* ================================================================== */
/* Plan42RustBuilder                                                   */
/* Converts Plan42 spec JSON -> RustModule tree -> Rust source         */
/* ================================================================== */
::class Plan42RustBuilder public

::method init
  expose _gen _dictConsts _varTypes
  use arg gen
  _gen = gen
  _dictConsts = .Set~new      /* dict constant names emitted as fn()  */
  _varTypes   = .Directory~new /* varname -> Rust type for coercions   */

/* ---- name helpers ---- */
::method safeImplFuncName
  expose _gen
  use arg implName
  safe = implName~changeStr('.','_')~changeStr('-','_')
  safe = translate(safe,'abcdefghijklmnopqrstuvwxyz','ABCDEFGHIJKLMNOPQRSTUVWXYZ')
  if translate(left(implName,10)) = 'PREFERRED.' then return 'p42_'||safe
  if translate(left(implName,4))  = 'WIK.'       then return 'p42_'||safe
  if _gen~_resolveImplNode(implName) \= .nil      then return 'p42_impl_'||safe
  return safe

::method rustType
  /* Parse Plan42 type annotation to Rust type.                        */
  /* Supports: str, int, float, bool, list, dict, option,             */
  /*           list<T>, dict<K,V>, option<T>, result<T,E>             */
  use arg t
  if t = .nil then return 'String'
  /* Already a concrete Rust type -- pass through unchanged           */
  if pos('<', t) > 0             then return t
  if left(t,3) = 'Vec'           then return t
  if left(t,7) = 'HashMap'       then return t
  if left(t,6) = 'Option'        then return t
  if left(t,6) = 'Result'        then return t
  if left(t,4) = 'impl'          then return t
  if t = 'Handles'               then return t
  if t = '()'                    then return t
  if t = 'serde_json::Value'     then return t
  tUp = translate(strip(t))
  /* Generic types: list<T>, dict<K,V>, option<T>, result<T,E>        */
  if pos('<', t) > 0 then do
    base  = translate(strip(left(t, pos('<', t)-1)))
    inner = strip(substr(t, pos('<', t)+1))
    if right(inner, 1) = '>' then inner = left(inner, length(inner)-1)
    select
      when base = 'LIST'   then return 'Vec<'||self~innerType(inner)||'>'
      when base = 'DICT'   then do
        comma = pos(',', inner)
        if comma > 0 then do
          k = strip(left(inner, comma-1))
          v = strip(substr(inner, comma+1))
          return 'HashMap<'||self~innerType(k)||', '||self~innerType(v)||'>'
        end
        return 'HashMap<String, String>'
      end
      when base = 'OPTION' then return 'Option<'||self~innerType(inner)||'>'
      when base = 'RESULT' then do
        comma = pos(',', inner)
        if comma > 0 then do
          ok  = strip(left(inner, comma-1))
          err = strip(substr(inner, comma+1))
          return 'Result<'||self~innerType(ok)||', '||self~innerType(err)||'>'
        end
        return 'Result<'||self~innerType(inner)||', Box<dyn std::error::Error>>'
      end
      otherwise return 'String'
    end
  end
  /* Primitive types */
  select
    when tUp = 'STR'    then return 'String'
    when tUp = 'INT'    then return 'i64'
    when tUp = 'FLOAT'  then return 'f64'
    when tUp = 'BOOL'   then return 'bool'
    when tUp = 'LIST'   then return 'Vec<String>'
    when tUp = 'DICT'   then return 'HashMap<String, String>'
    when tUp = 'OPTION' then return 'Option<String>'
    when tUp = 'NIL'    then return 'Option<String>'
    when tUp = 'BYTES'  then return 'Vec<u8>'
    when tUp = 'ERROR'  then return 'Box<dyn std::error::Error>'
    otherwise           return 'String'
  end

::method innerType
  /* Convert inner type annotation to Rust type (no generics)         */
  use arg t
  if t = .nil then return 'String'
  select
    when translate(t) = 'STR'   then return 'String'
    when translate(t) = 'INT'   then return 'i64'
    when translate(t) = 'FLOAT' then return 'f64'
    when translate(t) = 'BOOL'  then return 'bool'
    when translate(t) = 'BYTES' then return 'Vec<u8>'
    otherwise                   return 'String'
  end

::method paramType
  /* For function params: prefer &str over String for string inputs,  */
  /* owned types for collections.                                      */
  use arg t
  if t = .nil then return '&str'
  tUp = translate(strip(t))
  if pos('<', t) > 0 then return self~rustType(t)  /* generics: owned */
  select
    when tUp = 'STR'    then return '&str'
    when tUp = 'INT'    then return 'i64'
    when tUp = 'FLOAT'  then return 'f64'
    when tUp = 'BOOL'   then return 'bool'
    when tUp = 'LIST'   then return '&[String]'
    when tUp = 'DICT'   then return '&HashMap<String, String>'
    when tUp = 'OPTION' then return 'Option<&str>'
    otherwise           return '&str'
  end

/* ---- expressions ---- */
::method buildExpr
  expose _gen _dictConsts _varTypes
  use arg node
  if node = .nil then return .RustLiteral~new(.nil)
  if node~isA(.String)    then do
    if _dictConsts~hasIndex(node) then return .RustVar~new(node||'()')
    return .RustVar~new(node)
  end
  if node~isA(.Array)     then return .RustLiteral~new(node)
  if node~isA(.Directory) & node~at('op') = .nil then
    return .RustLiteral~new(node)
  op = translate(node~at('op'))
  select
    when op = 'LITERAL'  then return .RustLiteral~new(node~at('value'))
    when op = 'NIL'      then return .RustVar~new('None')
    when op = 'VAR'      then do
      vname = node~at('name')
      if _dictConsts~hasIndex(vname) then
        return .RustVar~new(vname||'()')
      return .RustVar~new(vname)
    end
    when op = 'CAST'     then return .RustCast~new(self~buildExpr(node~at('expr')), node~at('to'))
    when op = 'CONCAT'   then do
      /* Handle multi-arg concat from Regina spec format              */
      args = node~at('args')
      if args \= .nil then do
        if args~isA(.Array) then do
          if args~items > 1 then do
            acc = self~buildExpr(args~at(1))
            do i = 2 to args~items
              acc = .RustConcat~new(acc, self~buildExpr(args~at(i)))
            end
            return acc
          end
        end
      end
      return .RustConcat~new(self~buildExpr(node~at('left')), self~buildExpr(node~at('right')))
    end
    when op = 'FORMAT'   then do
      argNodes = .Directory~new
      specArgs = node~at('args')
      if specArgs \= .nil then do
        do k over specArgs~allIndexes
          argNodes~put(self~buildExpr(specArgs~at(k)), k)
        end
      end
      return .RustFormat~new(node~at('template'), argNodes)
    end
    when op = 'ADD'      then return .RustBinOp~new(self~buildExpr(node~at('left')), '+',  self~buildExpr(node~at('right')))
    when op = 'SUB'      then return .RustBinOp~new(self~buildExpr(node~at('left')), '-',  self~buildExpr(node~at('right')))
    when op = 'MUL'      then return .RustBinOp~new(self~buildExpr(node~at('left')), '*',  self~buildExpr(node~at('right')))
    when op = 'DIV'      then return .RustBinOp~new(self~buildExpr(node~at('left')), '/',  self~buildExpr(node~at('right')))
    when op = 'MOD'      then return .RustBinOp~new(self~buildExpr(node~at('left')), '%',  self~buildExpr(node~at('right')))
    when op = 'EQ'       then do
      l = self~buildExpr(node~at('left'))
      r = self~buildExpr(node~at('right'))
      rval = r~render('')
      /* &[String] == "" -> .is_empty()                               */
      if rval = '""' | rval = '"".to_string()' then
        return .RustVar~new(l~render('')||'.is_empty()')
      /* None/Null comparison -> .is_null() unconditionally           */
      if rval = 'None' | rval = 'serde_json::Value::Null' then
        return .RustVar~new(l~render('')||'.is_null()')
      return .RustBinOp~new(l, '==', r)
    end
    when op = 'NEQ'      then return .RustBinOp~new(self~buildExpr(node~at('left')), '!=', self~buildExpr(node~at('right')))
    when op = 'GT'       then return .RustBinOp~new(self~buildExpr(node~at('left')), '>',  self~buildExpr(node~at('right')))
    when op = 'LT'       then return .RustBinOp~new(self~buildExpr(node~at('left')), '<',  self~buildExpr(node~at('right')))
    when op = 'GTE'      then return .RustBinOp~new(self~buildExpr(node~at('left')), '>=', self~buildExpr(node~at('right')))
    when op = 'LTE'      then return .RustBinOp~new(self~buildExpr(node~at('left')), '<=', self~buildExpr(node~at('right')))
    when op = 'AND'      then return .RustBinOp~new(self~buildExpr(node~at('left')), '&&', self~buildExpr(node~at('right')))
    when op = 'OR'       then return .RustBinOp~new(self~buildExpr(node~at('left')), '||', self~buildExpr(node~at('right')))
    when op = 'NOT'      then return .RustNot~new(self~buildExpr(node~at('value')))
    when op = 'IN'       then return .RustIn~new(self~buildExpr(node~at('item')), self~buildExpr(node~at('collection')))
    when op = 'INDEX'    then return .RustIndex~new(self~buildExpr(node~at('obj')), self~buildExpr(node~at('index')))
    when op = 'TERNARY'  then return .RustTernary~new(self~buildExpr(node~at('cond')), self~buildExpr(node~at('then')), self~buildExpr(node~at('else')))
    when op = 'IMPL_USE' then return self~buildCallExpr(node~at('name'), node~at('args'))
    when op = 'CALL'     then return self~buildCallExpr(node~at('routine'), node~at('args'))
    when op = 'METHOD'   then do
      aExprs = self~buildArgList(node~at('args'))
      return .RustMethodExpr~new(self~buildExpr(node~at('obj')), node~at('name'), aExprs)
    end
    otherwise return .RustVar~new('/* expr:'||op||' */')
  end

::method buildCallExpr
  expose _gen _dictConsts _varTypes
  use arg implName, argsArr
  funcName = self~safeImplFuncName(implName)
  argExprs = self~buildArgList(argsArr)
  /* multiwrite_write: inject &mut on handles (first arg)             */
  if implName = 'preferred.file.multiwrite_write' then do
    if argExprs~items >= 1 then do
      first = argExprs~at(1)
      argExprs~put(.RustVar~new('&mut '||first~render('')), 1)
    end
  end
  return .RustCallExpr~new(funcName, argExprs)

::method buildArgList
  expose _gen _dictConsts _varTypes
  use arg arr
  out = .Array~new
  if arr = .nil         then return out
  if \arr~isA(.Array)  then return out
  do i = 1 to arr~items
    argNode = arr~at(i)
    expr    = self~buildExpr(argNode)
    val     = expr~render('')
    /* CONCAT/format! -> &() so String coerces to &str in call        */
    if argNode~isA(.Directory) then do
      if translate(argNode~at('op')) = 'CONCAT' then
        expr = .RustVar~new('&('||val||')')
    end
    else if argNode~isA(.String) then do
      vtype = _varTypes~at(translate(argNode))
      select
        /* String var -> .as_str() for &str params                   */
        when vtype = 'String' then
          expr = .RustVar~new(argNode||'.as_str()')
        /* serde_json::Value -> &val for &Value params               */
        when vtype = 'serde_json::Value' then
          expr = .RustVar~new('&'||argNode)
        /* HashMap/Vec owned -> & prefix for &ref params             */
        when left(vtype, 7) = 'HashMap' then
          expr = .RustVar~new('&'||argNode)
        when left(vtype, 3) = 'Vec' then
          expr = .RustVar~new('&'||argNode)
        otherwise nop
      end
    end
    out~append(expr)
  end
  return out

/* ---- statements ---- */
::method implReturnType
  /* R2: map preferred/wik impl names to concrete Rust return types   */
  use arg implName
  select
    when implName = 'preferred.file.multiwrite_open'     then return 'Handles'
    when implName = 'preferred.file.stream_lines'        then return 'impl Iterator<Item=String>'
    when implName = 'preferred.data.jsonl_parse'        then return 'serde_json::Value'
    when implName = 'preferred.data.soundex_from_ipa'    then return 'HashMap<String,Vec<String>>'
    when implName = 'preferred.file.write_tsv'           then return '()'
    when implName = 'preferred.file.multiwrite_write'    then return '()'
    when implName = 'preferred.file.multiwrite_close'    then return '()'
    when implName = 'preferred.ui.progress'              then return '()'
    when implName = 'preferred.data.soundex'             then return 'String'
    when implName = 'preferred.string.normalise_unicode' then return 'String'
    when implName = 'wik.extract_topics'                 then return 'Vec<String>'
    when implName = 'wik.first_ipa'                      then return 'String'
    when implName = 'wik.normalise_topic'                then return 'String'
    when implName = 'wik.collapse_words'                 then return '()'
    when implName = 'wik.collapse_scope'                 then return '()'
    when implName = 'wik.collapse_ipa'                   then return '()'
    otherwise                                            return .nil
  end

::method buildBody
  expose _gen _dictConsts _varTypes
  use arg arr
  stmts = .Array~new
  if arr = .nil        then return stmts
  if \arr~isA(.Array) then return stmts
  do i = 1 to arr~items
    s = self~buildStmt(arr~at(i))
    if s \= .nil then stmts~append(s)
  end
  return stmts

::method buildStmt
  expose _gen _dictConsts _varTypes
  use arg node
  if node = .nil then return .nil
  op = translate(node~at('op'))
  select
    when op = 'DECLARE'  then do
      typ = node~at('type')
      val = node~at('value')
      /* R2: infer type from impl_use return type when not annotated  */
      if typ = .nil & val \= .nil then do
        if val~isA(.Directory) then do
          if translate(val~at('op')) = 'IMPL_USE' then
            typ = self~implReturnType(val~at('name'))
        end
      end
      /* Track variable type for coercions in call args              */
      if typ \= .nil then do
        rtype = self~rustType(typ)
        _varTypes~put(rtype, translate(node~at('name')))
      end
      if val = .nil then
        return .RustLet~new(node~at('name'), typ, .nil)
      return .RustLet~new(node~at('name'), typ, self~buildExpr(val))
    end
    when op = 'ASSIGN'   then return .RustAssign~new(node~at('name'), self~buildExpr(node~at('value')))
    when op = 'RETURN'   then return .RustReturn~new(self~buildExpr(node~at('expr')))
    when op = 'OUTPUT'   then return .RustPrintln~new(self~buildExpr(node~at('expr')))
    when op = 'CONTINUE' then return .RustContinue~new
    when op = 'BREAK'    then return .RustBreak~new
    when op = 'IF'       then do
      /* Support both 'body'/'then' for if-body and 'else_body'/'else' */
      tbody = node~at('body')
      if tbody = .nil then tbody = node~at('then')
      ebody = node~at('else_body')
      if ebody = .nil then ebody = node~at('else')
      return .RustIf~new(self~buildExpr(node~at('cond')), self~buildBody(tbody), self~buildBody(ebody))
    end
    when op = 'FOR_EACH' then do
      inNode = node~at('in')
      inExpr = self~buildExpr(inNode)
      body   = self~buildBody(node~at('body'))
      /* impl Iterator returns -- iterate directly, no .iter() needed */
      inOp = ''
      if inNode~isA(.Directory) then inOp = translate(inNode~at('op'))
      if inOp = 'IMPL_USE' | inOp = 'CALL' then
        return .RustFor~new(node~at('var'), inExpr, body)
      /* Array literal needs .iter(); vars/iterators iterate directly */
      if inNode~isA(.Array) then do
        iterExpr = .RustVar~new(inExpr~render('')||'.iter()')
        return .RustFor~new(node~at('var'), iterExpr, body)
      end
      return .RustFor~new(node~at('var'), inExpr, body)
    end
    when op = 'FOR_RANGE' then do
      fromE = self~buildExpr(node~at('from'))
      toE   = self~buildExpr(node~at('to'))
      rangeExpr = .RustVar~new(fromE~render('')||'..'||toE~render(''))
      return .RustFor~new(node~at('var'), rangeExpr, self~buildBody(node~at('body')))
    end
    when op = 'WHILE'    then return .RustWhile~new(self~buildExpr(node~at('cond')), self~buildBody(node~at('body')))
    when op = 'MATCH'    then return .RustMatch~new(self~buildExpr(node~at('expr')), node~at('arms'))
    when op = 'TRY'      then return .RustTry~new(self~buildBody(node~at('body')), node~at('catches'))
    when op = 'RAISE'    then return .RustRaise~new(self~buildExpr(node~at('message')))
    when op = 'IMPL_USE' then do
      call = self~buildCallExpr(node~at('name'), node~at('args'))
      res  = node~at('result')
      if res \= .nil then do
        if res \= 'The NIL object' then
          return .RustLet~new(res, .nil, call)
      end
      return .RustExprStmt~new(call)
    end
    otherwise return .RustVar~new('/* '||op||' */')
  end

/* ---- impl helpers ---- */
::method buildImplHelper
  expose _gen
  use arg implNode, implName, params, ptypes
  implDef = _gen~resolveImpl(implNode)
  if implDef = .nil then return .nil
  inlineCode = implDef~at('inline')
  if inlineCode = .nil then return .nil
  code = inlineCode
  if params \= .nil then do
    do pi = 1 to params~items
      pname = params~at(pi)
      code  = code~changeStr('{'||pname||'}', pname)
    end
  end
  paramStr = ''
  if params \= .nil then do
    do pi = 1 to params~items
      if pi > 1 then paramStr = paramStr||', '
      pname = params~at(pi)
      ptype = 'String'
      if ptypes \= .nil then do
        pt = ptypes~at(pname)
        if pt \= .nil then ptype = self~rustType(pt)
      end
      paramStr = paramStr||'mut '||pname||': '||ptype
    end
  end
  funcName = self~safeImplFuncName(implName)
  body = .Array~new
  body~append(.RustVar~new('    '||code))
  return .RustRawBlock~new(.Array~of('fn '||funcName||'('||paramStr||') -> String {', '    '||code, '}', ''))

/* ---- full module ---- */
::method buildModule
  expose _gen _dictConsts _varTypes
  use arg spec
  module = .RustModule~new
  /* Header */
  hdr = .Array~new
  hdr~append('// Generated from Plan42 -- '||spec~name)
  hdr~append('// Cargo.toml dependencies: serde = {features=["derive"]}, serde_json = "1"')
  hdr~append('#![allow(unused_mut, unused_variables, dead_code, non_snake_case)]')
  hdr~append('use std::collections::HashMap;')
  hdr~append('use std::io::{self, BufRead, Write, BufWriter};')
  hdr~append('use std::fs::{self, File};')
  hdr~append('use std::path::Path;')
  hdr~append('extern crate serde_json;')
  hdr~append('')
  module~add(.RustRawBlock~new(hdr))
  /* Runtime helpers */
  module~add(.RustRawBlock~new(self~runtimeHelperLines))
  /* Custom impl helpers */
  do i = 1 to spec~nodes~items
    node = spec~nodes~at(i)
    if node = .nil then iterate
    if translate(node~at('op')) \= 'IMPL' then iterate
    implName = node~at('name')
    implNode = _gen~_resolveImplNode(implName)
    if implNode = .nil then iterate
    helper = self~buildImplHelper(implNode, implName, node~at('params'), node~at('param_types'))
    if helper \= .nil then module~add(helper)
  end
  /* Consts -- track dict ones as function names                      */
  do i = 1 to spec~nodes~items
    node = spec~nodes~at(i)
    if node = .nil then iterate
    if translate(node~at('op')) \= 'CONST' then iterate
    cname = node~at('name')
    cexpr = self~buildExpr(node~at('value'))
    /* If raw value is a Directory, it becomes a fn -- track it      */
    raw = .nil
    if cexpr~isA(.RustLiteral) then raw = cexpr~val
    if raw \= .nil then do
      if raw~isA(.Directory) then _dictConsts~put(cname)
    end
    module~add(.RustConst~new(cname, node~at('type'), cexpr))
    module~add(.RustRawBlock~new(.Array~of('')))
  end
  /* Routines */
  do i = 1 to spec~nodes~items
    node = spec~nodes~at(i)
    if node = .nil then iterate
    if translate(node~at('op')) \= 'ROUTINE' then iterate
    rName   = node~at('name')
    if rName = 'main' then rName = 'p42_main'  /* R3: avoid fn main() collision */
    pArr    = node~at('params')
    ptypes  = node~at('param_types')
    rettype = node~at('return_type')
    body    = self~buildBody(node~at('body'))
    module~add(.RustFn~new(rName, pArr, ptypes, rettype, body))
    module~add(.RustRawBlock~new(.Array~of('')))
  end
  return module

/* ---- runtime helper lines ---- */
::method runtimeHelperLines
  lines = .Array~new

  call addLine 'fn p42_unresolved_impl(name: &str) -> ! {'
  call addLine '    panic!("Plan42 impl unresolved: {}", name);'
  call addLine '}'
  call addLine ''
  call addLine 'fn p42_preferred_file_stream_lines(path: &str) -> impl Iterator<Item=String> {'
  call addLine '    let file = File::open(path).expect("cannot open file");'
  call addLine '    io::BufReader::new(file).lines().filter_map(|l| l.ok())'
  call addLine '}'
  call addLine ''
  call addLine 'fn p42_preferred_data_jsonl_parse(line: &str) -> serde_json::Value {'
  call addLine '    let raw = line.trim();'
  call addLine '    if raw.is_empty() { return serde_json::Value::Null; }'
  call addLine '    serde_json::from_str(raw).unwrap_or(serde_json::Value::Null)'
  call addLine '}'
  call addLine ''
  call addLine 'fn p42_preferred_ui_progress(counter: i64, interval: i64, label: impl std::fmt::Display) {'
  call addLine '    if interval > 0 && counter % interval == 0 {'
  call addLine '        eprintln!("{} {}", counter, label);'
  call addLine '    }'
  call addLine '}'
  call addLine ''
  call addLine 'type Handles = HashMap<(String,String), BufWriter<File>>;'
  call addLine ''
  call addLine 'fn p42_preferred_file_multiwrite_open(output_dir: &str, keys: &[String], suffixes: &[&str]) -> Handles {'
  call addLine '    fs::create_dir_all(output_dir).unwrap();'
  call addLine '    let mut handles = HashMap::new();'
  call addLine '    for k in keys {'
  call addLine '        for s in suffixes {'
  call addLine '            let path = format!("{}/{}.{}", output_dir, k, s);'
  call addLine '            let file = File::create(&path).unwrap();'
  call addLine '            handles.insert((k.clone(), s.to_string()), BufWriter::new(file));'
  call addLine '        }'
  call addLine '    }'
  call addLine '    handles'
  call addLine '}'
  call addLine ''
  call addLine 'fn p42_preferred_file_multiwrite_write(handles: &mut Handles, key: &str, suffix: &str, line: &str) {'
  call addLine '    if let Some(h) = handles.get_mut(&(key.to_string(), suffix.to_string())) {'
  call addLine '        h.write_all(line.as_bytes()).unwrap();'
  call addLine '    }'
  call addLine '}'
  call addLine ''
  call addLine 'fn p42_preferred_file_multiwrite_close(handles: Handles) { drop(handles); }'
  call addLine ''
  call addLine 'fn p42_preferred_file_write_tsv(data: &HashMap<String,Vec<String>>, path: &str) {'
  call addLine '    let out = File::create(path).unwrap();'
  call addLine '    let mut w = BufWriter::new(out);'
  call addLine '    let mut keys: Vec<&String> = data.keys().collect();'
  call addLine '    keys.sort();'
  call addLine '    for k in keys {'
  call addLine '        writeln!(w, "{}\t{}", k, data[k].join(" ")).unwrap();'
  call addLine '    }'
  call addLine '}'
  call addLine ''
  call addLine 'fn p42_soundex_key(text: &str) -> String {'
  call addLine '    let s: String = text.chars().filter(|c| c.is_alphabetic()).collect::<String>().to_uppercase();'
  call addLine '    if s.is_empty() { return "Z000".to_string(); }'
  call addLine '    let codes = [("BFPV","1"),("CGJKQSXZ","2"),("DT","3"),("L","4"),("MN","5"),("R","6")];'
  call addLine '    let mut out = s.chars().next().unwrap().to_string();'
  call addLine '    let mut prev = String::new();'
  call addLine '    for ch in s.chars().skip(1) {'
  call addLine '        let code = codes.iter().find(|(k,_)| k.contains(ch)).map(|(_,v)| *v).unwrap_or("");'
  call addLine '        if !code.is_empty() && code != prev {'
  call addLine '            out.push_str(code);'
  call addLine '            if out.len() >= 4 { break; }'
  call addLine '        }'
  call addLine '        if !code.is_empty() { prev = code.to_string(); }'
  call addLine '    }'
  call addLine '    format!("{:0<4}", &out[..out.len().min(4)])'
  call addLine '}'
  call addLine ''

  call addLine ''
  call addLine 'fn p42_preferred_data_soundex_from_ipa(output_dir: &str, lang: &str) -> HashMap<String,Vec<String>> {'
  call addLine '    let path = format!("{}/{}.ipa", output_dir, lang);'
  call addLine '    let mut buckets: HashMap<String,Vec<String>> = HashMap::new();'
  call addLine '    if !std::path::Path::new(&path).exists() { return buckets; }'
  call addLine '    let f = File::open(&path).unwrap();'
  call addLine '    for line in io::BufReader::new(f).lines().filter_map(|l| l.ok()) {'
  call addLine '        if line.is_empty() || !line.contains('"'"'\t'"'"') { continue; }'
  call addLine '        let pos = line.find('"'"'\t'"'"').unwrap();'
  call addLine '        let (word, ipa) = (&line[..pos], &line[pos+1..]);'
  call addLine '        let key = p42_soundex_key(if ipa.is_empty() { word } else { ipa });'
  call addLine '        buckets.entry(key).or_default().push(word.to_string());'
  call addLine '    }'
  call addLine '    buckets'
  call addLine '}'
  call addLine ''
  call addLine 'fn p42_normalise_topic(raw: &str) -> String {'
  call addLine '    let noise = ["noun","verb","adjective","adverb","pronoun","plural",'
  call addLine '                 "singular","masculine","feminine","neuter","uncountable",'
  call addLine '                 "transitive","intransitive","obsolete","countable","common"];'
  call addLine '    let t = raw.trim().to_lowercase();'
  call addLine '    let words: Vec<&str> = t.split_whitespace().filter(|w| !noise.contains(w)).collect();'
  call addLine '    let r = words.join(" ");'
  call addLine '    if r.len() >= 3 { r } else { String::new() }'
  call addLine '}'
  call addLine ''
  call addLine 'fn p42_wik_extract_topics(entry: &serde_json::Value) -> Vec<String> {'
  call addLine '    let mut found = std::collections::HashSet::new();'
  call addLine '    for key in &["topics","categories","tags","raw_tags"] {'
  call addLine '        if let Some(arr) = entry[key].as_array() {'
  call addLine '            for v in arr { if let Some(s) = v.as_str() {'
  call addLine '                let n = p42_normalise_topic(s);'
  call addLine '                if !n.is_empty() { found.insert(n); }'
  call addLine '            }}'
  call addLine '        }'
  call addLine '    }'
  call addLine '    if let Some(senses) = entry["senses"].as_array() {'
  call addLine '        for sense in senses {'
  call addLine '            for key in &["topics","categories","tags","raw_tags"] {'
  call addLine '                if let Some(arr) = sense[key].as_array() {'
  call addLine '                    for v in arr { if let Some(s) = v.as_str() {'
  call addLine '                        let n = p42_normalise_topic(s);'
  call addLine '                        if !n.is_empty() { found.insert(n); }'
  call addLine '                    }}'
  call addLine '                }'
  call addLine '            }'
  call addLine '        }'
  call addLine '    }'
  call addLine '    let mut v: Vec<String> = found.into_iter().collect();'
  call addLine '    v.sort(); v'
  call addLine '}'
  call addLine ''
  call addLine 'fn p42_wik_first_ipa(entry: &serde_json::Value) -> String {'
  call addLine '    if let Some(sounds) = entry["sounds"].as_array() {'
  call addLine '        for s in sounds {'
  call addLine '            if let Some(ipa) = s["ipa"].as_str() {'
  call addLine '                if !ipa.is_empty() {'
  call addLine '                    return ipa.trim_matches(|c| "/[] ".contains(c)).to_string();'
  call addLine '                }'
  call addLine '            }'
  call addLine '        }'
  call addLine '    }'
  call addLine '    String::new()'
  call addLine '}'
  call addLine ''
  call addLine 'fn p42_collapse_tsv(path: &str, merge: bool) {'
  call addLine '    let p = std::path::Path::new(path);'
  call addLine '    if !p.exists() { return; }'
  call addLine '    let mut rows: Vec<(String,String)> = Vec::new();'
  call addLine '    let mut idx: HashMap<String,usize> = HashMap::new();'
  call addLine '    {'
  call addLine '        let f = File::open(p).unwrap();'
  call addLine '        for line in io::BufReader::new(f).lines().filter_map(|l| l.ok()) {'
  call addLine '            if line.is_empty() { continue; }'
  call addLine '            let (k,v) = if let Some(t) = line.find('"'"'\t'"'"') {'
  call addLine '                (line[..t].to_string(), line[t+1..].to_string())'
  call addLine '            } else { (line.clone(), String::new()) };'
  call addLine '            if let Some(&i) = idx.get(&k) {'
  call addLine '                if merge {'
  call addLine '                    let mut s: std::collections::HashSet<String> ='
  call addLine '                        rows[i].1.split_whitespace().map(String::from).collect();'
  call addLine '                    s.extend(v.split_whitespace().map(String::from));'
  call addLine '                    let mut sv: Vec<String> = s.into_iter().collect();'
  call addLine '                    sv.sort(); rows[i].1 = sv.join(" ");'
  call addLine '                }'
  call addLine '            } else { idx.insert(k.clone(), rows.len()); rows.push((k, v)); }'
  call addLine '        }'
  call addLine '    }'
  call addLine '    let tmp = format!("{}.tmp", path);'
  call addLine '    { let f = File::create(&tmp).unwrap();'
  call addLine '      let mut w = BufWriter::new(f);'
  call addLine '      for (k,v) in &rows { writeln!(w, "{}\t{}", k, v).unwrap(); }'
  call addLine '    }'
  call addLine '    std::fs::rename(&tmp, path).unwrap();'
  call addLine '}'
  call addLine ''
  call addLine 'fn p42_wik_collapse_words(output_dir: &str, lang: &str) {'
  call addLine '    p42_collapse_tsv(&format!("{}/{}.words", output_dir, lang), false); }'
  call addLine 'fn p42_wik_collapse_scope(output_dir: &str, lang: &str) {'
  call addLine '    p42_collapse_tsv(&format!("{}/{}.scope", output_dir, lang), true); }'
  call addLine 'fn p42_wik_collapse_ipa(output_dir: &str, lang: &str) {'
  call addLine '    p42_collapse_tsv(&format!("{}/{}.ipa", output_dir, lang), false); }'
  call addLine ''

  return lines

addLine:
  use arg txt
  lines~append(txt)
  return

