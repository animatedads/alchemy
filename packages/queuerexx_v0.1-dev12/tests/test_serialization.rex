d = .Directory~new
d["schema"] = "test.v1"
d["ok"] = .JSONBoolean~true
j = .QueueSerialization~toJson(d)
p = .QueueSerialization~fromJson(j)
if p["schema"] \= "test.v1" then do; say "FAIL json"; exit 1; end

y = .QueueSerialization~toYaml(d)
if y~pos("schema") = 0 then do; say "FAIL yaml"; exit 1; end

call SysFileDelete "serialization.json"
if \.QueueSerialization~toJsonFile(d, "serialization.json") then do; say "FAIL json file write"; exit 1; end
jf = .QueueSerialization~fromJsonFile("serialization.json")
if jf["schema"] \= "test.v1" then do; say "FAIL json file roundtrip"; exit 1; end
call SysFileDelete "serialization.json"

call SysFileDelete "serialization.yaml"
if \.QueueSerialization~toYamlFile(d, "serialization.yaml") then do; say "FAIL yaml file write"; exit 1; end
yf = .QueueSerialization~fromYamlFile("serialization.yaml")
if yf["schema"] \= "test.v1" then do; say "FAIL yaml file roundtrip"; exit 1; end
call SysFileDelete "serialization.yaml"

rows = .Array~new
rows~append(.Array~of("a", "b"))
rows~append(.Array~of("one", "two words"))
call SysFileDelete "serialization.tsv"
if \.QueueSerialization~writeTsv("serialization.tsv", rows) then do; say "FAIL tsv write"; exit 1; end
s = .Stream~new("serialization.tsv"); s~open("READ"); l1=s~lineIn; l2=s~lineIn; s~close
if l1~pos("09"x) = 0 | l2~pos("09"x) = 0 then do; say "FAIL tsv delimiter"; exit 1; end
call SysFileDelete "serialization.tsv"
say "PASS test_serialization"
exit 0

::requires "../src/QueueRexxSerialization.cls"
