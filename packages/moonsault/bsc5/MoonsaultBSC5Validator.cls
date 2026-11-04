/* Moonsault BSC5 CSV input qualification (ooRexx 5.3.0).
 * Source layout: ra,dec,mag,bv,spectral,hd,hip,dist_pc,name
 * Does not claim these positions are navigationally corrected. */
::class MoonsaultBSC5Validator public
::method scan
  use arg filename, expectedCount = 9096
  report = .directory~new
  report['ok'] = .true
  report['errors'] = .array~new
  report['rows'] = .array~new
  report['count'] = 0
  report['missingHIP'] = 0
  report['missingBV'] = 0
  report['missingDistance'] = 0
  report['missingName'] = 0
  if filename = '' | stream(filename, 'c', 'query exists') = '' then do
    ignore = self~failure(report, 'Source CSV not found: ' || filename)
    return report
  end
  seenHD = .table~new
  seenHIP = .table~new
  sourceLine = 0
  call stream filename, 'c', 'open read'
  do while lines(filename) > 0
    raw = linein(filename)
    sourceLine += 1
    if raw = '' then iterate
    if left(raw, 1) = '#' then iterate
    fields = self~parseCsvRow(raw)
    if fields~items \= 9 then do
      ignore = self~failure(report, 'Line ' || sourceLine || ': expected 9 CSV columns')
      iterate
    end
    ra=strip(fields[1]); dec=strip(fields[2]); mag=strip(fields[3]); bv=strip(fields[4])
    spectral=strip(fields[5]); hd=strip(fields[6]); hip=strip(fields[7]); distance=strip(fields[8])
    name=strip(fields[9])
    good = .true
    if \datatype(ra,'N') | \datatype(dec,'N') | \datatype(mag,'N') then good = .false
    if \datatype(hd,'W') then good = .false
    if bv \= '' then if \datatype(bv,'N') then good = .false
    if hip \= '' then if \datatype(hip,'W') then good = .false
    if distance \= '' then if \datatype(distance,'N') then good = .false
    if \good then do
      ignore = self~failure(report, 'Line ' || sourceLine || ': invalid numeric field')
      iterate
    end
    if ra < 0 | ra >= 360 | dec < -90 | dec > 90 | hd <= 0 then do
      ignore = self~failure(report, 'Line ' || sourceLine || ': coordinates / HD outside range')
      iterate
    end
    if hip \= '' then if hip <= 0 then do
      ignore = self~failure(report, 'Line ' || sourceLine || ': invalid HIP')
      iterate
    end
    if distance \= '' then if distance <= 0 then do
      ignore = self~failure(report, 'Line ' || sourceLine || ': nonpositive distance')
      iterate
    end
    if seenHD[hd] \== .nil then do
      ignore = self~failure(report, 'Line ' || sourceLine || ': duplicate HD ' || hd)
      iterate
    end
    if hip \= '' then if seenHIP[hip] \== .nil then do
      ignore = self~failure(report, 'Line ' || sourceLine || ': duplicate HIP ' || hip)
      iterate
    end
    seenHD[hd] = sourceLine
    if hip \= '' then seenHIP[hip] = sourceLine
    if hip = '' then report['missingHIP'] += 1
    if bv = '' then report['missingBV'] += 1
    if distance = '' then report['missingDistance'] += 1
    if name = '' then report['missingName'] += 1
    record = .directory~new
    record['ra'] = ra; record['dec'] = dec; record['mag'] = mag
    record['bv'] = bv; record['spectral'] = spectral; record['hd'] = hd
    record['hip'] = hip; record['distance'] = distance; record['name'] = name
    report['rows']~append(record)
  end
  call stream filename, 'c', 'close'
  report['count'] = report['rows']~items
  if report['count'] \= expectedCount then ignore = self~failure(report, 'Expected ' || expectedCount || ' records, got ' || report['count'])
  return report

::method parseCsvRow private
  use arg source
  fields = .array~new
  start = 1
  do i=1 to length(source)
    if substr(source,i,1) = ',' then do
      fields~append(substr(source,start,i-start))
      start = i+1
    end
  end
  fields~append(substr(source,start))
  return fields

::method failure private
  use arg report, message
  report['ok'] = .false
  if report['errors']~items < 20 then report['errors']~append(message)
  return .nil
