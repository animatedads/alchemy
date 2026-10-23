/* Shared isolation helpers for NoSQLServer smoke tests. */
::class NoSQLServerTestSupport public

::method createBlankDatabase class
  use arg label = "test"
  target = SysTempFileName("/tmp/nosqlserver-" || label || "-??????")
  if SysMkDir(target) \= 0 then raise syntax 93.900 additional("Unable to create test root:" target)
  if SysMkDir(target || "/tables") \= 0 then raise syntax 93.900 additional("Unable to create test tables directory:" target)
  catalogPath = target || "/database.yaml"
  call lineout catalogPath, "name: " || label
  call lineout catalogPath, "formatVersion: 1"
  call lineout catalogPath, "tables: []"
  call lineout catalogPath
  return target

::method cloneDatabase class
  use arg source, label = "test"
  source = source~strip
  do while source~right(1) = "/"
    source = source~left(source~length - 1)
  end
  call SysFileTree source || "/database.yaml", "anchor.", "FO"
  if anchor.0 \= 1 then raise syntax 93.900 additional("Source database does not exist:" source)
  marker = "/database.yaml"
  markerPos = anchor.1~lastpos(marker)
  if markerPos = 0 then raise syntax 93.900 additional("Unable to resolve source database root:" source)
  source = anchor.1~left(markerPos - 1)

  target = SysTempFileName("/tmp/nosqlserver-" || label || "-??????")
  if SysMkDir(target) \= 0 then raise syntax 93.900 additional("Unable to create test clone:" target)

  call SysFileTree source || "/*", "dirs.", "DOS"
  do i = 1 to dirs.0
    relative = dirs.i~substr(source~length + 1)
    call SysMkDir target || relative
  end

  call SysFileTree source || "/*", "files.", "FOS"
  do i = 1 to files.0
    relative = files.i~substr(source~length + 1)
    if SysFileCopy(files.i, target || relative) \= 0 then -
      raise syntax 93.900 additional("Unable to copy test file:" files.i)
  end
  return target

::method removeDatabase class
  use arg target
  if target = "" then return
  call SysFileTree target || "/*", "files.", "FOS"
  do i = 1 to files.0
    call SysFileDelete files.i
  end
  call SysFileTree target || "/*", "dirs.", "DOS"
  do i = dirs.0 to 1 by -1
    call SysRmDir dirs.i
  end
  call SysRmDir target
  return 0
