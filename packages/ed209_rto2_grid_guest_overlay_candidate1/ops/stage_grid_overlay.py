#!/usr/bin/env python3
"""Merge only the RTO2 branch into verified Grid source; preserve local FAST and registration corrections."""
import argparse,hashlib,pathlib,shutil
def stage(source,target,overlay):
    source=pathlib.Path(source).resolve();target=pathlib.Path(target).resolve();overlay=pathlib.Path(overlay).resolve()
    if not (source/'guest/init-grid.c').is_file() or not (source/'scripts/build_grid_mn_initramfs.sh').is_file():
        raise ValueError('not a Grid source root')
    if target.exists():raise ValueError('refusing existing output path')
    src=source/'host/qf-xtp-handler.rex'
    if not src.is_file():raise ValueError('installed Grid handler absent')
    handler=src.read_text()
    branch=(overlay/'rexx/rto2_work_dispatch.rex.inc').read_text()
    begin='if command[1]="RTO2_WORK" then do'
    needle='if command[1]="PROBE" then do'
    if branch.count(begin)!=1 or handler.count(needle)!=1 or begin in handler:
        raise ValueError('unrecognised or divergent handler dispatch shape')
    for mark in ['emitFailure:','emitResponse:','::requires "ObjectQueueXTPTransport.cls"']:
        if mark not in handler:raise ValueError('installed handler lacks compatible API '+mark)
    merged=handler.replace(needle,branch+'\n'+needle,1)
    for cls in ['RTO2CountJob.cls','AlchemyRTO.cls']:
        mark='::requires "'+cls+'"'
        if mark not in merged:merged+='\n'+mark+'\n'
    builder=(source/'scripts/build_grid_mn_initramfs.sh').read_text()
    before='cp "$HERE/rto2/RexxOSFastCryptoProbe.cls" "$W/root/opt/rexxos/lib/"'
    if builder.count(before)!=1:raise ValueError('unrecognised initramfs builder')
    after='cp "$HERE/rto2/RexxOSFastCryptoProbe.cls" "$HERE/rto2/RTO2CountJob.cls" "$HERE/rto2/AlchemyClusteredApp.cls" "$HERE/rto2/AlchemyRTO.cls" "$W/root/opt/rexxos/lib/"'
    builder=builder.replace(before,after)
    init=(source/'guest/init-grid.c').read_text()
    before='setenv("QF_XTP_PEERS","/etc/grid/peers.manifest",1);'
    if init.count(before)!=1:raise ValueError('unrecognised guest init')
    init=init.replace(before,before+'setenv("GRID_NODE_ID",node,1);setenv("GRID_MU_ID",mu,1);setenv("QF_XTP_RTO2_ENABLED","1",1);')
    shutil.copytree(source,target,symlinks=True)
    (target/'host/qf-xtp-handler.rex').write_text(merged)
    (target/'scripts/build_grid_mn_initramfs.sh').write_text(builder)
    (target/'guest/init-grid.c').write_text(init)
    (target/'RTO2_SOURCE_MERGE_RECEIPT.txt').write_text(
      'overlay=RTO2_WORK additive branch\nsource_handler_sha256='+hashlib.sha256(handler.encode()).hexdigest()+
      '\nmerged_handler_sha256='+hashlib.sha256(merged.encode()).hexdigest()+
      '\nsource_preserved_including_FAST_and_registration=yes\nguest_must_pass_image_preflight=yes\n')
    return target
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--grid',required=True);p.add_argument('--output',required=True)
    a=p.parse_args();print(stage(a.grid,a.output,pathlib.Path(__file__).resolve().parent.parent))
