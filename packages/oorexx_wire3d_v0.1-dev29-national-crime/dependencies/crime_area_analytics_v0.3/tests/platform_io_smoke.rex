/* Proves all structured text I/O is delegated to ooRexx distribution classes. */

root = directory()
tmp = root || '/tests/.platform_io_fixture.csv'

out = .CsvStream~new(tmp, .false)
out~open('WRITE REPLACE')
out~csvLineOut(.array~of('id', 'text'))
out~csvLineOut(.array~of('A', 'contains, comma'))
out~csvLineOut(.array~of('B', 'contains "quote"'))
out~csvLineOut(.array~of('C', 'line one' || .endOfLine || 'line two'))
out~close

input = .CsvStream~new(tmp, .true, .true)
input~open('READ')
expected = .array~of('contains, comma', 'contains "quote"', 'line one' || .endOfLine || 'line two')
i = 0
do while input~chars > 0
  ignore = input~csvLineIn
  i += 1
  if input~values['text'] <> expected[i] then do
    say 'FAIL CsvStream field' i input~values['text']
    exit 1
  end
end
input~close
call SysFileDelete tmp
if i <> 3 then do
  say 'FAIL CsvStream row count' i
  exit 1
end

catalog = .PoliceUKCrimeFilterCatalogJson~load(root || '/data/police_uk_filter_catalog_2025-08_2025-09.json')
if catalog~definition('period')~values~items <> 2 then do
  say 'FAIL json.cls period catalogue'
  exit 1
end
if catalog~definition('crimeType')~values~items <> 14 then do
  say 'FAIL json.cls crime type catalogue' catalog~definition('crimeType')~values~items
  exit 1
end

say 'PASS crime_area_analytics platform structured I/O smoke'
exit 0

::requires 'CrimeFilterModel.cls'
::requires 'csvStream.cls'
