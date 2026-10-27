/* Alchemy ADDRESS environment boundary probe; requires ooRexx RFE #882.
 * This is NOT a ConnectSelector transport implementation.
 * Package prolog runs on ::REQUIRES in each interpreter instance.
 * The handler refuses all commands except explicitly named probes.
 */
.CommandHandler~register("ALCHEMY_CS_PROBE", .AlchemyCsProbeHandler~new)

::class AlchemyCsProbeHandler inherit CommandHandler

/* The interpreter calls this on the issuing Rexx activity.
 * caller is the CommandContext; deliberately do not mutate it here.
 * Unknown commands never fall through to an operating-system shell.
 */
::method command
  use arg command, caller
  opcode = translate(strip(command))
  select
    when opcode = "PING" then return 0
    when opcode = "DENY" then return 13
    otherwise return 64
  end
