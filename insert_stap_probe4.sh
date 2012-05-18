#!/bin/bash

# This probe trace bio which reads or writes dirty pagecache, which
# has memory error.

stap=/usr/bin/stap
stap=/root/systemtap-1.7-5536/bin/stap

mount -t debugfs none /sys/kernel/debug
target_inode=`ls -i ./test.txt | cut -f1 -d' '`

tmpf=`mktemp`

# mce_rdmsrl mce_log
probes=( NULL )

probes_inline=( NULL )

target_process="dirty_page_cache"

cat <<EOF > ${tmpf}.stp
#!/usr/bin/stap

global target_mapping
global target_dentry
global target_struct_inode
global target_file
global wbwork
EOF

echo_stp() { echo "$@" >> ${tmpf}.stp; }

printbase='printf("%28s %12s %5d %2d:", probefunc(), execname(), pid(), cpu())'
printbase='printf("%28s %12s %5d %2d %d:", probefunc(), execname(), pid(), cpu(), gettimeofday_us())'
printbase='printf("%28s %12s %5d %2d %s:", probefunc(), execname(), pid(), cpu(), get_uptime())'

printwb='printf(" #f/#m/FF/FM %3d/%3d/%6x/%6x, %d/%d\n", get_cc_nrfreepages(ccont), get_cc_nrmigratepages(ccont), get_cc_freepfn(ccont), get_cc_migratepfn(ccont), get_cc_order(ccont), get_cc_migratetype(ccont))'

for probe in ${probes[@]} ; do
[ "$probe" = NULL ] && break
cat <<EOF >> ${tmpf}.stp
probe kernel.function("$probe") { $printbase ; printf("\n"); }
probe kernel.function("$probe").return { $printbase ; printf("ret\n"); }
EOF
done

for probe in ${probes_inline[@]} ; do
[ "$probe" = NULL ] && break
cat <<EOF >> ${tmpf}.stp
probe kernel.function("$probe").inline { $printbase ; printf("\n"); }
EOF
done

cat <<EOF >> ${tmpf}.stp
%{
#include <linux/mm.h>
#include <linux/fs.h>
#include <linux/list.h>
#include <linux/mmzone.h>
#include <linux/writeback.h>
#include <linux/coda.h>
#include <linux/time.h>
#include <linux/kernel.h>
#include <linux/fdtable.h>
#include <linux/path.h>
#include <linux/dcache.h>

struct wb_writeback_work {
        long nr_pages;
        struct super_block *sb;
        enum writeback_sync_modes sync_mode;
        int for_kupdate:1;
        int range_cyclic:1;
        int for_background:1;
        struct list_head list;
        struct completion *done;
};
%}

function get_wbc_start:long (val:long) %{
    THIS->__retvalue = (long)((struct writeback_control *)THIS->val)->range_start;
%}

function get_wbc_end:long (val:long) %{
    THIS->__retvalue = (long)((struct writeback_control *)THIS->val)->range_end;
%}

function get_wbc_nrwrite:long (val:long) %{
    THIS->__retvalue = (long)((struct writeback_control *)THIS->val)->nr_to_write;
%}

function get_wbc_cyclic:long (val:long) %{
    THIS->__retvalue = (long)((struct writeback_control *)THIS->val)->range_cyclic;
%}

function page_to_pfn:long (val:long) %{
    THIS->__retvalue = (long)page_to_pfn((struct page *)THIS->val);
%}

function pfn_to_page:long (val:long) %{
    THIS->__retvalue = (long)pfn_to_page(THIS->val);
%}

function get_uptime:string () %{
    char ut[16];
    struct timespec uptime;
    do_posix_clock_monotonic_gettime(&uptime);
    sprintf(ut, "%lu.%06lu", (unsigned long) uptime.tv_sec,
                             (uptime.tv_nsec / (NSEC_PER_SEC / 100)));
    strlcpy (THIS->__retvalue, ut, MAXSTRINGLEN);
%}

function get_file_mapping:long (val:long) %{
    THIS->__retvalue = (long)((struct file *)THIS->val)->f_mapping;
%}

function get_file_count:long (val:long) %{
    THIS->__retvalue = (long)atomic64_read(&((struct file *)THIS->val)->f_count);
%}

function get_dentry_to_inode:long (val:long) {
    return @cast(val, "dentry", "kernel")->d_inode;
}

function get_dentry_to_inodeno:long (val:long) {
    return @cast(val, "dentry", "kernel")->d_inode->i_ino;
}

function get_dentry_to_mapping:long (val:long) {
    return @cast(val, "dentry", "kernel")->d_inode->i_mapping;
}

function get_inode_to_inodeno:long (val:long) {
    return @cast(val, "inode", "kernel")->i_ino;
}

function get_inode_to_count:long (val:long) %{
    THIS->__retvalue = (long)atomic_read(&((struct inode *)THIS->val)->i_count);
%}

function get_inode_to_writeback_index:long (val:long) {
    return @cast(val, "inode", "kernel")->i_mapping->writeback_index;
}

function get_wbwork_sb:long (val:long) {
    return @cast(val, "wb_writeback_work", "kernel")->sb;
}

function get_wbwork_nrpages:long (val:long) {
    return @cast(val, "wb_writeback_work", "kernel")->nr_pages;
}

function get_wbwork_cyclic:long (val:long) {
    return @cast(val, "wb_writeback_work", "kernel")->range_cyclic;
}

function get_page_mapping:long (val:long) {
    return @cast(val, "page", "kernel")->mapping;
}

function get_page_index:long (val:long) {
    return @cast(val, "page", "kernel")->index;
}

function get_mapping_flags:long (val:long) {
    return @cast(val, "address_space", "kernel")->flags;
}

function get_mapping_nrpages:long (val:long) {
    return @cast(val, "address_space", "kernel")->nrpages;
}

function get_dentry_count:long (val:long) {
    return @cast(val, "dentry", "kernel")->d_count;
}

function get_path_str:string (val:long) {
    return sprint(@cast(val, "path", "kernel")->dentry->d_iname);
}

function get_path_inode:long (val:long) {
    return @cast(val, "path", "kernel")->dentry->d_inode->i_ino;
}

# function get_path_str:string (val:long) %{
#     return sprint(((struct path *)THIS->val)->dentry->d_iname);
# %}

function get_path_to_mappingflag:long (val:long) {
    return @cast(val, "path", "kernel")->dentry->d_inode->i_mapping->flags;
}

probe begin { printf("start\n"); }

probe kernel.function("__dentry_open") {
    if (get_dentry_to_inodeno(\$dentry) == $target_inode) {
        target_mapping = get_dentry_to_mapping(\$dentry);
        target_dentry = \$dentry;
        target_file = \$f;
        target_struct_inode = get_dentry_to_inode(\$dentry);
        $printbase ; printf(" d_count %x, mapping %x\n",
            get_dentry_count(\$dentry), target_mapping);
    }
}

probe kernel.function("memory_failure") {
    $printbase ; printf(" pfn %x, icount %x, dcount %x, fcount %x\n", \$pfn, get_inode_to_count(target_struct_inode), get_dentry_count(target_dentry), get_file_count(target_file));
}

probe kernel.function("memory_failure").return {
    $printbase ; printf(" mapping->flags %x, icount %x, dcount %x, fcount %x\n", get_mapping_flags(target_mapping), get_inode_to_count(target_struct_inode), get_dentry_count(target_dentry), get_file_count(target_file));
}

probe kernel.function("dput") {
    if (\$dentry == target_dentry) {
        $printbase ; printf(" mapping->flags %x, icount %x, dcount %x, fcount %x\n", get_mapping_flags(target_mapping), get_inode_to_count(target_struct_inode), get_dentry_count(target_dentry), get_file_count(target_file));
    }
}
    
probe syscall.open {
    if (execname() != "lsof" && target_mapping != 0) {
        $printbase ; printf(" icount %x, dcount %x, fcount %x\n", get_inode_to_count(target_struct_inode), get_dentry_count(target_dentry), get_file_count(target_file));
    }
}
    
probe syscall.close {
    if (\$fd == 3 && target_mapping != 0) {
        $printbase ; printf(" mapping->flags %x, icount %x, dcount %x, fcount %x\n", get_mapping_flags(target_mapping), get_inode_to_count(target_struct_inode), get_dentry_count(target_dentry), get_file_count(target_file));
    }
}

# probe kernel.function("iput@fs/inode.c") {
#     if (get_inode_to_inodeno(\$inode) == $target_inode) {
#         $printbase ; printf(" i_count %x\n", get_inode_to_count(\$inode));
#     }
# }

probe kernel.function("iput_final").inline {
    if (get_inode_to_inodeno(\$inode) == $target_inode) {
        $printbase ; printf(" mapping->flags %x, icount %x, dcount %x, fcount %x\n", get_mapping_flags(target_mapping), get_inode_to_count(target_struct_inode), get_dentry_count(target_dentry), get_file_count(target_file));
        print_backtrace();
    }
}

probe kernel.function("__fput").inline {
    if (get_file_mapping(\$file) == target_mapping) {
        $printbase ; printf(" mapping->flags %x, icount %x, dcount %x, fcount %x\n", get_mapping_flags(target_mapping), get_inode_to_count(target_struct_inode), get_dentry_count(target_dentry), get_file_count(target_file));
    }
}

# probe kernel.function("filp_close@fs/open.c") {
#     if (get_file_mapping(\$filp) == target_mapping) {
#         $printbase ; printf(" count %d\n", get_file_count(\$filp));
#     }
# }

# probe kernel.function("wb_writeback") {
#     tmpwbnpage = get_wbwork_nrpages(\$work);
#     tmpwbcyclic = get_wbwork_cyclic(\$work);
#     $printbase ; printf(" %x %d\n", tmpwbnpage, tmpwbcyclic);
#     wbwork = \$work;
# }

# function get_bio_sector:long (val:long) {
#     return @cast(val, "bio", "kernel")->bi_sector;
# }
# function get_bio_page:long (val:long) {
#     return @cast(val, "bio", "kernel")->bi_io_vec->bv_page;
# }
# function get_bio_bh:long (val:long) {
#     tmp = @cast(val, "bio", "kernel")->bi_io_vec->bv_page->private
#     if (tmp) {
#         return @cast(tmp, "buffer_head", "kernel")->b_blocknr;
#     } else {
#         return 0;
#     }
# }
# function get_bio_bh_bsize:long (val:long) {
#     tmp = @cast(val, "bio", "kernel")->bi_io_vec->bv_page->private
#     if (tmp) {
#         return @cast(tmp, "buffer_head", "kernel")->b_size;
#     } else {
#         return 0;
#     }
# }

# probe kernel.function("init_request_from_bio") {
#     tmp = get_bio_page(\$bio);
#     if (target_mapping == get_page_mapping(tmp)) {
#         $printbase ; printf(" pidx/sec/bh %8x/%14d\n",
#           get_page_index(tmp), get_bio_sector(\$bio));
#     }
# }

# probe kernel.function("writeback_single_inode") {
#     if ($target_inode == get_inode_to_inodeno(\$inode)) {
#         $printbase ; printf(" %6x\n", get_inode_to_writeback_index(\$inode));
#     }
# }

# probe module("ext4").function("ext4_writepage") {
#     if (target_mapping == get_page_mapping(\$page)) {
#         $printbase ; printf(" %6x %6x\n", page_to_pfn(\$page), get_page_index(\$page));
#     }
# }

# probe kernel.function("wait_on_page_writeback_range") {
#     if (target_mapping == \$mapping) {
#         $printbase ; printf(" %10x %10x\n", \$start, \$end);
#         system("pkill -SIGUSR1 -f dirty_page_cache");
#     }
# }
EOF

cat ${tmpf}.stp
$stap ${tmpf}.stp -g --vp 11111 # -o /tmp/stap.log

rm -f ${tmpf}*
