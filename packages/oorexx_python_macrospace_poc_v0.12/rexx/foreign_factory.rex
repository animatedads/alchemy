use strict arg kind, arg1 = .nil
select
  when kind == "OBJECT_COLLECTION" then return .ObjectCollection~new
  when kind == "PYTHON_PROXY" then return .PythonObjectProxy~new(arg1)
  otherwise raise syntax 93.900 array ("unknown factory kind: " || kind)
end
::requires "animals.cls"
