parse arg statePath
if statePath="" then do; say "usage: rexx test_mtboot_pre_map_state.rex pre-map.state"; exit 2; end
state=.KL10State~new
cpu=state~load(statePath)
m=state~metadata
call eq m["checkpoint"],"mtboot.pre-map","label"
call eq cpu~pc,oct("772512"),"PC"
call eq cpu~instructionCount,273068,"ICOUNT"
call eq cpu~pag~pageEnabled,1,"paging live"
call eq cpu~ioBus~hasDevice(128),1,"DTE attached"
call eq cpu~dte~monitorMode,1,"monitor mode"
call eq cpu~dte~txHex,"0D0A424F4F54205631312E3028333135290D0A","banner"
p=cpu~preview
call eq p["mnemonic"],"MAP","next proposal"
call eq p["instruction"],oct("257040762000"),"MAP word"
say "PASS test_mtboot_pre_map_state"; exit
oct: procedure; use arg t; n=0; do i=1 to length(t); n=n*8+substr(t,i,1); end; return n
eq: procedure; use arg a,e,l; if a\=e then do; say "FAIL" l e a; exit 1; end; return
::requires "../KL10IPL.cls"
