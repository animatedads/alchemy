/*
  Narrow ooRexx -> Java bridge for wire_ui_swing_v0.2-dev3.

  It deliberately exposes one WireSwingRuntime rather than arbitrary Swing
  widgets. Wire .Table/.Directory/.Array values are recursively converted to
  java.util.LinkedHashMap/java.util.ArrayList before crossing the BSF boundary.
*/
::class WireUISwingBridge public

::method init
  expose runtime mapClass listClass desktopWindow
  runtime=bsf.loadClass("org.alchemy.wireui.swing.WireSwingRuntime")~create
  mapClass=bsf.loadClass("java.util.Map")
  listClass=bsf.loadClass("java.util.List")
  desktopWindow=.nil

::method runtime
  expose runtime
  return runtime

::method hello
  expose runtime
  use arg applicationId="", sessionId="", accessPointId=""
  return self~fromJava(runtime~hello(applicationId, sessionId, accessPointId))

::method accept
  expose runtime
  use arg message
  runtime~accept(self~toJava(message))
  return self

::method pollAction
  expose runtime
  return self~fromJava(runtime~pollAction)

::method drainOutbound
  expose runtime
  return self~fromJava(runtime~drainOutbound)

::method revision
  expose runtime
  return runtime~revision

::method rootComponent
  expose runtime
  return runtime~rootComponent

::method openDesktopWindow
  expose runtime desktopWindow
  use arg title="Wire UI", width=1100, height=700
  if desktopWindow<>.nil then desktopWindow~close
  desktopClass=bsf.loadClass("org.alchemy.wireui.swing.WireSwingDesktopWindow")
  desktopWindow=desktopClass~create(runtime,title,width,height)
  desktopWindow~showWindow
  return self

::method closeDesktopWindow
  expose desktopWindow
  if desktopWindow<>.nil then desktopWindow~close
  desktopWindow=.nil
  return self

::method desktopWindowVisible
  expose desktopWindow
  if desktopWindow==.nil then return .false
  return desktopWindow~isVisible

::method toJava private
  use arg value
  if value==.nil then return .nil

  if value~isA(.Table) | value~isA(.Directory) then do
    target=.bsf~new("java.util.LinkedHashMap")
    do key over value
      target~put(key~string, self~toJava(value[key]))
    end
    return target
  end

  if value~isA(.Array) then do
    target=.bsf~new("java.util.ArrayList")
    do item over value
      target~add(self~toJava(item))
    end
    return target
  end

  return value

::method fromJava private
  expose mapClass listClass
  use arg value
  if value==.nil then return .nil

  if mapClass~isInstance(value) then do
    target=.table~new
    do with index key item item over value
      target[key~string]=self~fromJava(item)
    end
    return target
  end

  if listClass~isInstance(value) then do
    target=.array~new
    do item over value
      target~append(self~fromJava(item))
    end
    return target
  end

  return value

::requires "BSF.CLS"
