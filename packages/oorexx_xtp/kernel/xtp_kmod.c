// SPDX-License-Identifier: GPL-2.0
/*
 * RexxOS XTP kernel residency hook.
 *
 * This dev6 module intentionally establishes the loadable/compiled-in build
 * boundary and protocol identity only.  It does not yet register AF_XTP or
 * consume protocol-36 / EtherType-0x817D traffic; userspace libxtp remains
 * authoritative until the kernel packet engine is ported behind the same API.
 */
#include <linux/init.h>
#include <linux/module.h>

#define XTP_IP_PROTOCOL 36
#define XTP_ETHERTYPE 0x817D

static int __init xtp_init(void)
{
    pr_info("xtp: RexxOS XTP kernel provider hook loaded (ipproto=%d ethertype=0x%04x)\n",
            XTP_IP_PROTOCOL, XTP_ETHERTYPE);
    return 0;
}
static void __exit xtp_exit(void) { pr_info("xtp: kernel provider hook unloaded\n"); }
module_init(xtp_init); module_exit(xtp_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("RexxOS XTP kernel provider hook");
MODULE_AUTHOR("RexxOS / Alchemy");
