/* Authenticated post-paging checkpoint exposes nested DTE proposal. */
parse arg statePath
if statePath="" then do
 say "usage: rexx test_mtboot_pre_dte_state.rex pre-dte.kl10state"
 exit 2
end
state=.KL10State~new
cpu=state~load(statePath)
meta=state~metadata
call eq meta["checkpoint"],"mtboot.pre-dte-probe","checkpoint label"
call eq meta["parent_checkpoint"],"mtboot.pre-paging-enable","parent label"
call eq cpu~pc,oct("772431"),"PC"
call eq cpu~instructionCount,272638,"ICOUNT"
call eq cpu~pag~pageEnabled,1,"pager live"
call eq cpu~pag~ebPtr,oct("765000"),"EBR"
call eq cpu~memory~physicalWord(oct("772146")),oct("777"),"detected high physical page"
p=cpu~preview
call eq p["mnemonic"],"XCT","outer proposal"
call eq p["xctMnemonic"],"CONSO","nested proposal"
call eq p["xctDeviceName"],"DTE","requested device"
call eq p["xctIoFunction"],7,"CONSO"
say "PASS test_mtboot_pre_dte_state"
exit 0
oct: procedure
 use arg t
 n=0; do i=1 to length(t); n=n*8+substr(t,i,1); end; return n
eq: procedure
 use arg a,e,l
 if a \= e then do; say "FAIL" l "expected="e "actual="a; exit 1; end
 return
::requires "../KL10IPL.cls"
