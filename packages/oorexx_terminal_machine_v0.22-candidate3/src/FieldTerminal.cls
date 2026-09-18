/* Generic mutable field-terminal model v0.6 above CharacterGridModel. */

::class MutableTerminalField public
::attribute fieldId get
::attribute row get
::attribute column get
::attribute length get
::attribute value get
::attribute inputCapable get
::attribute protected get
::attribute nonDisplay get
::attribute modified get
::attribute numeric get

::method init
  expose fieldId row column length value inputCapable protected nonDisplay modified numeric attributes
  use arg fieldIdArg, rowArg, columnArg, lengthArg, valueArg = "", inputArg = .false, protectedArg = .true, nonDisplayArg = .false, modifiedArg = .false, numericArg = .false, attributesArg = .nil
  fieldId = fieldIdArg~string
  row = rowArg
  column = columnArg
  length = lengthArg
  value = valueArg~string
  inputCapable = inputArg == .true
  protected = protectedArg == .true
  nonDisplay = nonDisplayArg == .true
  modified = modifiedArg == .true
  numeric = numericArg == .true
  attributes = .TerminalUtil~copyDirectory(attributesArg)

::method attribute
  expose attributes
  use arg nameArg
  return attributes[nameArg~string]

::method setValueInternal
  expose value modified inputCapable protected length
  use arg newValue, markModified = .true
  if \inputCapable | protected then return .TerminalResult~failure("FIELD_PROTECTED", "field is not input capable")
  text = newValue~string
  if text~length > length then return .TerminalResult~failure("FIELD_OVERFLOW", "value exceeds field length")
  value = text
  if markModified then modified = .true
  return .TerminalResult~success

::method setHostValueInternal
  expose value modified length
  use arg newValue, preserveModified = .false
  text = newValue~string
  if text~length > length then text = text~left(length)
  value = text
  if \preserveModified then modified = .false
  return self

::method setHostCharInternal
  expose value length
  use arg offsetArg, charArg
  if offsetArg < 1 | offsetArg > length then return .TerminalResult~failure("FIELD_RANGE", offsetArg)
  full = value~left(length)
  leftPart = ""
  if offsetArg > 1 then leftPart = full~left(offsetArg - 1)
  rightPart = ""
  if offsetArg < length then rightPart = full~substr(offsetArg + 1)
  value = leftPart || charArg~string~substr(1, 1) || rightPart
  return .TerminalResult~success

::method setOperatorCharInternal
  expose modified
  use arg offsetArg, charArg
  changed = self~setHostCharInternal(offsetArg, charArg)
  if changed~ok then modified = .true
  return changed

::method clearModifiedInternal
  expose modified
  modified = .false
  return self

::method setModifiedInternal
  expose modified
  use arg stateArg = .true
  modified = stateArg == .true
  return self

::method snapshot
  expose fieldId row column length value inputCapable protected nonDisplay modified numeric attributes
  safeValue = value
  if nonDisplay then safeValue = "<SECRET>"
  return .TerminalFieldSnapshot~new(fieldId, row, column, length, safeValue, inputCapable, protected, nonDisplay, modified, numeric, attributes)

::method wireSnapshot
  expose fieldId row column length value inputCapable protected nonDisplay modified numeric attributes
  return .TerminalFieldSnapshot~new(fieldId, row, column, length, value, inputCapable, protected, nonDisplay, modified, numeric, attributes)

::class FieldTerminalModel subclass CharacterGridModel public
::method init
  expose fields fieldOrder
  use arg terminalTypeArg, rowsArg = 24, columnsArg = 80, capabilitiesArg = .nil
  self~init:super(terminalTypeArg, rowsArg, columnsArg, capabilitiesArg)
  fields = .table~new
  fieldOrder = .array~new

::method clear
  expose fields fieldOrder
  self~clear:super
  fields = .table~new
  fieldOrder = .array~new
  return self

::method clearFormatTable
  expose fields fieldOrder
  fields = .table~new
  fieldOrder = .array~new
  return self

::method defineField
  expose fields fieldOrder
  use arg fieldId, rowArg, columnArg, lengthArg, valueArg = "", inputArg = .false, protectedArg = .true, nonDisplayArg = .false, numericArg = .false, attributesArg = .nil, modifiedArg = .false
  id = fieldId~string
  if fields~at(id) \== .nil then return .TerminalResult~failure("FIELD_EXISTS", id)
  startPos = self~linearPosition(rowArg, columnArg)
  if startPos == 0 then return .TerminalResult~failure("FIELD_RANGE", id)
  if lengthArg < 1 | startPos + lengthArg - 1 > self~rows * self~columns then return .TerminalResult~failure("FIELD_RANGE", id)
  f = .MutableTerminalField~new(id, rowArg, columnArg, lengthArg, valueArg, inputArg, protectedArg, nonDisplayArg, modifiedArg, numericArg, attributesArg)
  fields~put(f, id)
  fieldOrder~append(id)
  self~renderField(f)
  return .TerminalResult~success(f)

::method renderField private
  use arg field
  if field~nonDisplay then text = copies("*", field~length)
  else text = field~value~left(field~length)
  self~writeLinearText(field~row, field~column, text)

::method field
  expose fields
  use arg fieldId
  return fields~at(fieldId~string)

::method fieldsForDriver
  expose fields fieldOrder
  resultArray = .array~new
  do id over fieldOrder
    if fields~at(id) \== .nil then resultArray~append(fields[id])
  end
  return resultArray

::method fieldAtMutable
  expose fields columns
  use arg rowArg, columnArg
  wanted = self~linearPosition(rowArg, columnArg)
  if wanted == 0 then return .nil
  do id over fields
    f = fields[id]
    startPos = self~linearPosition(f~row, f~column)
    lastPos = startPos + f~length - 1
    if wanted >= startPos & wanted <= lastPos then return f
  end
  return .nil

::method setFieldValue
  expose fields
  use arg fieldId, valueArg
  f = fields~at(fieldId~string)
  if f == .nil then return .TerminalResult~failure("FIELD_NOT_FOUND", fieldId)
  outcome = f~setValueInternal(valueArg)
  if outcome~ok then self~renderField(f)
  return outcome

::method hostFieldValue
  expose fields
  use arg fieldId, valueArg
  f = fields~at(fieldId~string)
  if f == .nil then return .TerminalResult~failure("FIELD_NOT_FOUND", fieldId)
  f~setHostValueInternal(valueArg)
  self~renderField(f)
  return .TerminalResult~success

/* Host/datastream write.  If it lands in a field, update the field backing
 * value while keeping nondisplay contents out of the visible grid. */
::method hostWriteCharacter
  use arg rowArg, columnArg, charArg
  f = self~fieldAtMutable(rowArg, columnArg)
  if f == .nil then return self~writeText(rowArg, columnArg, charArg~string~substr(1,1))
  fieldStart = self~linearPosition(f~row, f~column)
  here = self~linearPosition(rowArg, columnArg)
  offset = here - fieldStart + 1
  outcome = f~setHostCharInternal(offset, charArg)
  if \outcome~ok then return outcome
  if f~nonDisplay then visible = "*"
  else visible = charArg~string~substr(1,1)
  return self~writeText(rowArg, columnArg, visible)

::method clearModifiedFields
  expose fields
  do id over fields
    fields[id]~clearModifiedInternal
  end
  return self

::method clearInputFieldData
  expose fields
  do id over fields
    f = fields[id]
    if f~inputCapable & \f~protected then do
      f~setHostValueInternal("")
      self~renderField(f)
    end
  end
  return self

::method modifiedFields
  expose fields fieldOrder
  fieldsOut = .array~new
  do id over fieldOrder
    f = fields[id]
    if f~modified then fieldsOut~append(f~snapshot)
  end
  return fieldsOut

/* Driver/codec path only.  These objects may contain nondisplay field bytes. */
::method modifiedFieldsForWire
  expose fields fieldOrder
  fieldsOut = .array~new
  do id over fieldOrder
    f = fields[id]
    if f~modified then fieldsOut~append(f~wireSnapshot)
  end
  return fieldsOut

::method snapshot
  expose fields fieldOrder
  base = self~snapshot:super
  fieldSnapshots = .array~new
  do id over fieldOrder
    if fields~at(id) \== .nil then fieldSnapshots~append(fields[id]~snapshot)
  end
  return .TerminalSnapshot~new(base~generation, base~terminalType, base~rows, base~columns, base~cursorRow, base~cursorColumn, base~keyboardState, base~sessionState, base~textRows, fieldSnapshots, base~capabilities, base~metadata, base~contentDigest, base~layoutFingerprint, base~timestamp)


/* Replace-or-create is for host format-table maintenance.  It preserves
 * deterministic field order when an existing start address is redefined. */
::method defineOrReplaceField
  expose fields fieldOrder
  use arg fieldId, rowArg, columnArg, lengthArg, valueArg = "", inputArg = .false, protectedArg = .true, nonDisplayArg = .false, numericArg = .false, attributesArg = .nil, modifiedArg = .false
  id = fieldId~string
  existing = fields~at(id)
  if existing \== .nil then fields~remove(id)
  else fieldOrder~append(id)
  startPos = self~linearPosition(rowArg, columnArg)
  if startPos == 0 then return .TerminalResult~failure("FIELD_RANGE", id)
  if lengthArg < 1 | startPos + lengthArg - 1 > self~rows * self~columns then return .TerminalResult~failure("FIELD_RANGE", id)
  f = .MutableTerminalField~new(id, rowArg, columnArg, lengthArg, valueArg, inputArg, protectedArg, nonDisplayArg, modifiedArg, numericArg, attributesArg)
  fields~put(f, id)
  self~renderField(f)
  return .TerminalResult~success(f)

::method fieldByStart
  expose fields fieldOrder
  use arg rowArg, columnArg
  wanted = self~linearPosition(rowArg, columnArg)
  if wanted == 0 then return .nil
  do id over fieldOrder
    f = fields~at(id)
    if f == .nil then iterate
    if self~linearPosition(f~row, f~column) = wanted then return f
  end
  return .nil

::method firstInputField
  expose fields fieldOrder
  do id over fieldOrder
    f = fields~at(id)
    if f == .nil then iterate
    if f~inputCapable & \f~protected then return f
  end
  return .nil

/* Navigation order is presentation order, not incidental hash/table order.
 * IBM describes entry fields as top-to-bottom and left-to-right for field
 * progression; bypass/protected fields are skipped for ordinary input. */
::method inputFieldsForNavigation
  expose fields
  out = .array~new
  do id over fields
    f = fields[id]
    if \f~inputCapable | f~protected then iterate
    insertAt = out~items + 1
    fpos = self~linearPosition(f~row, f~column)
    do i = 1 to out~items
      other = out[i]
      opos = self~linearPosition(other~row, other~column)
      if fpos < opos then do
        insertAt = i
        leave
      end
    end
    if insertAt > out~items then out~append(f)
    else do
      shifted = .array~new
      do i = 1 to out~items + 1
        if i < insertAt then shifted~append(out[i])
        else if i = insertAt then shifted~append(f)
        else shifted~append(out[i - 1])
      end
      out = shifted
    end
  end
  return out

::method nextInputField
  use arg rowArg, columnArg
  ordered = self~inputFieldsForNavigation
  if ordered~items = 0 then return .nil
  here = self~linearPosition(rowArg, columnArg)
  if here = 0 then return ordered[1]
  containing = self~fieldAtMutable(rowArg, columnArg)
  if containing \== .nil then do
    if containing~inputCapable & \containing~protected then do
      do i = 1 to ordered~items
        if ordered[i] == containing then do
          if i < ordered~items then return ordered[i + 1]
          return ordered[1]
        end
      end
    end
  end
  do f over ordered
    if self~linearPosition(f~row, f~column) > here then return f
  end
  return ordered[1]

::method previousInputField
  use arg rowArg, columnArg
  ordered = self~inputFieldsForNavigation
  if ordered~items = 0 then return .nil
  here = self~linearPosition(rowArg, columnArg)
  if here = 0 then return ordered[ordered~items]
  containing = self~fieldAtMutable(rowArg, columnArg)
  if containing \== .nil then do
    if containing~inputCapable & \containing~protected then do
      do i = 1 to ordered~items
        if ordered[i] == containing then do
          if i > 1 then return ordered[i - 1]
          return ordered[ordered~items]
        end
      end
    end
  end
  previous = .nil
  do f over ordered
    if self~linearPosition(f~row, f~column) >= here then leave
    previous = f
  end
  if previous \== .nil then return previous
  return ordered[ordered~items]

::method operatorWriteCharacter
  use arg rowArg, columnArg, charArg
  f = self~fieldAtMutable(rowArg, columnArg)
  if f == .nil then return .TerminalResult~failure("FIELD_PROTECTED", "cursor is not in an input field")
  if \f~inputCapable | f~protected then return .TerminalResult~failure("FIELD_PROTECTED", f~fieldId)
  fieldStart = self~linearPosition(f~row, f~column)
  here = self~linearPosition(rowArg, columnArg)
  offset = here - fieldStart + 1
  changed = f~setOperatorCharInternal(offset, charArg)
  if \changed~ok then return changed
  self~renderField(f)
  return .TerminalResult~success(f)

::method allInputFieldsForWire
  expose fields fieldOrder
  out = .array~new
  do id over fieldOrder
    f = fields~at(id)
    if f == .nil then iterate
    if f~inputCapable & \f~protected then out~append(f~wireSnapshot)
  end
  return out

::method clearModifiedNonBypassFields
  expose fields
  do id over fields
    f = fields[id]
    if f~inputCapable & \f~protected then f~clearModifiedInternal
  end
  return self

::method clearModifiedAllFields
  return self~clearModifiedFields

::method nullNonBypassFields
  expose fields
  use arg onlyModified = .false
  /* IBM WTD CC0 treats nulling and MDT reset as independent operations.
   * Preserve the pre-existing MDT here; callers perform any requested MDT
   * reset explicitly according to Table 15-2. */
  do id over fields
    f = fields[id]
    if f~inputCapable & \f~protected then do
      if \onlyModified | f~modified then do
        f~setHostValueInternal("", .true)
        self~renderField(f)
      end
    end
  end
  return self

/* Clear every field backing value while preserving the format table.
 * This is deliberately host-only: it must not mark fields modified. */
::method nullAllFieldsPreserveFormat
  expose fields
  do id over fields
    f = fields[id]
    f~setHostValueInternal("")
    self~renderField(f)
  end
  return self

::method setFieldModifiedById
  expose fields
  use arg fieldId, stateArg = .true
  f = fields~at(fieldId~string)
  if f == .nil then return .TerminalResult~failure("FIELD_NOT_FOUND", fieldId)
  f~setModifiedInternal(stateArg)
  return .TerminalResult~success(f)

::requires "CharacterGridTerminal.cls"
