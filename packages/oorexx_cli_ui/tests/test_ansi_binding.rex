renderer=.CliUiAnsiRenderer~new(0,1,8,60)
renderer~beginFrame
renderer~drawText(1,1,'CLI UI ANSI Rexx binding','status')
renderer~drawText(2,1,'renderer-only native projection','default')
renderer~setCursor(3,1)
renderer~endFrame
renderer~close
say 'PASS ooRexx native ANSI renderer binding'
::requires 'CliUiAnsiRenderer.cls'
