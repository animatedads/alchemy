/* NotNotes Web consumer adapter extension. All durable edits go through
   MiniNotesApp public methods; Wire BrowserRenderer holds presentation only. */
::class NotNotesWireExtendedPort subclass NotNotesWebProjectionPort public

::method perform
  use strict arg action, detail=.nil
  if detail == .nil then detail=.Directory~new
  operation=action~string~upper
  select
    when operation='NOTNOTES.DESIGN_FORMAT' then return self~designFormat(detail)
    when operation='NOTNOTES.CREATE_USER_DOCUMENT' then return self~createUserDocument(detail)
    when operation='NOTNOTES.DESIGN_REPORT' then return self~designReport(detail)
    otherwise do
      out=self~perform:super(action,detail)
      if operation='NOTNOTES.RUN_REPORT' then do
        if out['ok'] then do
          out['status']='REPORTED'
        end
        else do
          if out['result']~hasIndex('STATUS') then out['status']=out['result']['STATUS']
        end
      end
      return out
    end
  end

::method fail
  use strict arg code
  out=.Directory~new
  out['ok']=.false
  out['status']=code
  return out

::method success
  use strict arg code
  out=.Directory~new
  out['ok']=.true
  out['status']=code
  return out

::method designFormat
  use strict arg detail
  app=self~application
  name=self~detailText(detail,'format')
  if name='' | name~length>64 then return self~fail('FORMAT_NAME_REQUIRED')
  if app~documentFormatCanonicalName(name)<>'' then return self~fail('FORMAT_EXISTS')
  fieldText=self~detailText(detail,'fields')
  if fieldText='' then return self~fail('FIELDS_REQUIRED')
  parts=fieldText~makeArray(';')
  if parts~items>16 then return self~fail('TOO_MANY_FIELDS')
  specs=.Array~new
  seen=.Directory~new
  reserved=' DOC_KEY DOCKEY TITLE AMOUNT RISK DEPENDSON DEPENDS_ON WORKFLOW APPROVALSTATUS '
  do part over parts
    cells=part~strip~makeArray('|')
    if cells~items<3 | cells~items>5 then return self~fail('FIELD_SYNTAX')
    key=cells[1]~strip~upper
    label=cells[2]~strip
    kind=cells[3]~strip~upper
    if key='' | label='' | key~length>40 | label~length>80 then return self~fail('FIELD_NAME_INVALID')
    if key~verify('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_')<>0 then return self~fail('FIELD_NAME_INVALID')
    if reserved~wordPos(key)>0 | seen~hasIndex(key) then return self~fail('DUPLICATE_OR_RESERVED_FIELD')
    if kind<>'TEXT' & kind<>'NUMBER' & kind<>'MONEY' & kind<>'USER_REFERENCE' & kind<>'DOCUMENT_REFERENCE' then return self~fail('FIELD_TYPE_INVALID')
    seen[key]=.true
    spec=.Directory~new
    spec['NAME']=key
    spec['LABEL']=label
    spec['TYPE']=kind
    if kind='DOCUMENT_REFERENCE' then do
      if cells~items<4 then return self~fail('REFERENCE_TARGET_REQUIRED')
      target=app~documentFormatCanonicalName(cells[4]~strip)
      if target='' then return self~fail('REFERENCE_TARGET_UNKNOWN')
      cardinality='ONE'
      if cells~items>=5 then cardinality=cells[5]~strip~upper
      if cardinality<>'ONE' & cardinality<>'MANY' then return self~fail('CARDINALITY_INVALID')
      spec['REF_TARGET']=target
      spec['CARDINALITY']=cardinality
    end
    else if cells~items>3 then return self~fail('FIELD_SYNTAX')
    specs~append(spec)
  end
  if specs~items=0 then return self~fail('FIELDS_REQUIRED')
  ignore=app~installUserFormat(name,specs)
  return self~success('FORMAT_CREATED')

::method createUserDocument
  use strict arg detail
  app=self~application
  name=app~userFormatCanonicalName(self~detailText(detail,'format'))
  if name='' then return self~fail('FORMAT_NOT_FOUND')
  specs=app~userFormatFields(name)
  supplied=self~detailText(detail,'values')
  values=.Directory~new
  if supplied<>'' then do item over supplied~makeArray(';')
    parse var item key '=' value
    key=key~strip~upper
    if key='' then return self~fail('FIELD_SYNTAX')
    if app~userFormatFieldSpec(name,key)==.nil then return self~fail('UNKNOWN_FIELD')
    if values~hasIndex(key) then return self~fail('DUPLICATE_FIELD')
    spec=app~userFormatFieldSpec(name,key)
    if (spec['TYPE']='MONEY' | spec['TYPE']='NUMBER') & value~strip<>'' then if \value~strip~datatype('N') then return self~fail('INVALID_NUMBER')
    values[spec['NAME']]=value~strip
  end
  document=app~createUserDocument(name,specs,values)
  if document==.nil then return self~fail('DOCUMENT_VALIDATION_FAILED')
  ignore=app~select(document~DocKey)
  out=self~success('DOCUMENT_CREATED')
  out['key']=document~DocKey
  return out

::method designReport
  use strict arg detail
  app=self~application
  name=self~detailText(detail,'report')
  source=self~detailText(detail,'sourceForm')
  if name='' | name~length>64 then return self~fail('REPORT_NAME_REQUIRED')
  if app~reportDefinition(name)\==.nil then return self~fail('REPORT_EXISTS')
  source=app~documentFormatCanonicalName(source)
  if source='' then return self~fail('SOURCE_FORMAT_NOT_FOUND')
  text=self~detailText(detail,'columns')
  if text='' then return self~fail('REPORT_COLUMNS_REQUIRED')
  columns=.Array~new
  parts=text~makeArray(';')
  if parts~items>16 then return self~fail('TOO_MANY_REPORT_COLUMNS')
  do part over parts
    parse var part label '=' requested
    label=label~strip
    requested=requested~strip
    if label='' | requested='' then return self~fail('REPORT_COLUMN_SYNTAX')
    binding=app~resolveReportColumn(source,requested)
    if binding='' then return self~fail('UNKNOWN_REPORT_BINDING')
    column=.Directory~new
    column['LABEL']=label
    column['BINDING']=binding
    columns~append(column)
  end
  ignore=app~installReportDefinition(name,source,columns)
  return self~success('REPORT_CREATED')

::method detailText
  use strict arg detail,name
  if detail~hasIndex(name) then return detail[name]~string~strip
  if detail~hasIndex(name~upper) then return detail[name~upper]~string~strip
  return ''

::requires 'NotNotesWebProjectionPort.cls'
