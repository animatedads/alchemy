#!/usr/bin/env python3
"""Add only RTO2 work handling to the installed Grid source, preserving deployed FAST/registration fixes."""
import argparse
import hashlib
import pathlib
import shutil


def stage(source,target,overlay):
    source=pathlib.Path(source).resolve();target=pathlib.Path(target).resolve();overlay=pathlib.Path(overlay).resolve()
    if not (source/'guest/init-grid.c').is_file() or not (source/'scripts/build_grid_mn_initramfs.sh').is_file():
        raise ValueError('not a Grid source root')
    if target.exists():raise ValueError('refusing existing output path')
    handler_path=source/'host/qf-xtp-handler.rex'
    if not handler_path.is_file():raise ValueError('current installed handler absent')
    handler=handler_path.read_text()
    branch=(overlay/'rexx/qf-xtp-handler.rto2.rex').read_text()
    begin='if command[1]="RTO2_WORK" then do'
    end='if command[1]="PROBE" then do'
    if branch.count(begin)!=1 or branch.count(end)!=1:raise ValueError('candidate RTO2 branch not uniquely located')
    section=branch[branch.index(begin):branch.index(end)]
    if handler.count(end)!=1 or handler.count(begin)!=0:
        raise ValueError('installed handler has divergent dispatch shape; manual source reconciliation required')
    for name in ['emitFailure:','emitResponse:','::requires "ObjectQueueXTPTransport.cls"']:
        if name not in handler:raise ValueError('installed handler lacks required compatible API '+name)
    newhandler=handler.replace(end,section+end,1)
    for req in ('RTO2CountJob.cls','AlchemyRTO.cls'):
        directive='::requires "'+req+'"'
        if directive not in newhandler:newhandler+='\n'+directive+'\n'
    builder_path=source/'scripts/build_grid_mn_initramfs.sh'
    builder=builder_path.read_text()
    needle='cp "$HERE/rto2/RexxOSFastCryptoProbe.cls" "$W/root/opt/rexxos/lib/"'
    if builder.count(needle)!=1:raise ValueError('unrecognised initramfs builder; cannot inject classes safely')
    builder=builder.replace(needle,'cp "$HERE/rto2/RexxOSFastCryptoProbe.cls" "$HERE/rto2/RTO2CountJob.cls" "$HERE/rto2/AlchemyClusteredApp.cls" "$HERE/rto2/AlchemyRTO.cls" "$W/root/opt/rexxos/lib/"')
    initpath=source/'guest/init-grid.c';init=initpath.read_text()
    needle='setenv("QF_XTP_PEERS","/etc/grid/peers.manifest",1);'
    if init.count(needle)!=1:raise ValueError('unrecognised init bootstrap; cannot enable RTO2 safely')
    # Make the grant to the guest worker explicit and never change existing XTP networking.
    init=init.replace(needle,needle+'setenv("GRID_NODE_ID",node,1);setenv("GRID_MU_ID",mu,1);setenv("QF_XTP_RTO2_ENABLED","1",1);')
    # Fail closed rather than alter a working deployed tree.
    shutil.copytree(source,target,symlinks=True)
    (target/'host/qf-xtp-handler.rex').write_text(newhandler)
    (target/'scripts/build_grid_mn_initramfs.sh').write_text(builder)
    (target/'guest/init-grid.c').write_text(init)
    # Provenance, no secrets or runtime configuration embedded in build receipt.
    receipt=target/'RTO2_SOURCE_MERGE_RECEIPT.txt'
    receipt.write_text('\n'.join((
        'overlay=RTO2_WORK additive handler branch',
        'source_handler_sha256='+hashlib.sha256(handler.encode()).hexdigest(),
        'merged_handler_sha256='+hashlib.sha256(newhandler.encode()).hexdigest(),
        'source_preserved_including_FAST_and_registration=yes',
        'guest_must_pass_image_preflight=yes',
    ))+'\n')
    return target

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--grid',required=True);p.add_argument('--output',required=True)
    args=p.parse_args()
    print(stage(args.grid,args.output,pathlib.Path(__file__).resolve().parent.parent))
