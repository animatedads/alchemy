source=.EventSource~new('USB')
adb=.AdbAttach~new

/* Application code states the relationship; provider code remains elsewhere. */
source~when(.EventFilter~new('USB.ADB.INTERFACE.APPEARED','USB'))~fire(adb,'attach')
source~emit('USB.ADB.INTERFACE.APPEARED','device-17')
call syssleep .05

::class AdbAttach
::method attach
  use strict arg event
  say 'attach' event~data

::requires "src/EventRuntime.cls"
