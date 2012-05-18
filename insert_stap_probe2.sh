#!/bin/bash

# This probe trace bio which reads or writes dirty pagecache, which
# has memory error.

mount -t debugfs none /sys/kernel/debug
modprobe mce-inject hwpoison-inject

tmpf=`mktemp`

# mce_rdmsrl mce_log
probes=( NULL )

probes_inline=( NULL )

target_process="user5"

cat <<EOF > ${tmpf}.stp
#!/usr/bin/stap

global window = 0
global target_pfn
global target_page
global target_bio
EOF

echo_stp() { echo "$@" >> ${tmpf}.stp; }

printbase='printf("%30s %10s %5d %3d %d:", probefunc(), execname(), pid(), cpu(), gettimeofday_us())'

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
%}

function get_list_entry:long (val:long) %{
    THIS->__retvalue = (long)list_entry((struct list_head *)THIS->val, struct page, lru);
%}

function get_page:long (val:long) %{
    THIS->__retvalue = (long)list_entry((struct list_head *)THIS->val, struct page, lru);
%}

function get_pfn:long (val:long) %{
    THIS->__retvalue = (long)page_to_pfn((struct page *)THIS->val);
%}

function get_page_from_pfn:long (val:long) %{
    THIS->__retvalue = (long)pfn_to_page(THIS->val);
%}

function get_page_flag:long (val:long) %{
    THIS->__retvalue = (long)((struct page *)THIS->val)->flags;
%}

function get_page_mapcount:long (val:long) %{
    THIS->__retvalue = (long)page_mapcount((struct page *)THIS->val);
%}

function get_page_mapping:long (val:long) %{
    THIS->__retvalue = (long)((struct page *)THIS->val)->mapping;
%}

function get_mapping_flag:long (val:long) %{
    THIS->__retvalue = (long)((struct address_space *)THIS->val)->flags;
%}

function get_mapping_nrpages:long (val:long) %{
    THIS->__retvalue = (long)((struct address_space *)THIS->val)->nrpages;
%}

probe kernel.function("__memory_failure") {
    if (execname() == "$target_process") {
        tmppage = get_page_from_pfn(\$pfn);
        tmppagemapping = get_page_mapping(tmppage);
        target_pfn = \$pfn;
        target_page = tmppage;
        $printbase ; printf("pfn %x, page %p, mapping %p\n", \$pfn, tmppage, tmppagemapping);
    }
}

probe kernel.function("me_pagecache_dirty") {
    $printbase ; printf("p %p, mapping %x\n", \$p, \$p->mapping);
}

probe syscall.read {
    if (execname() == "$target_process") {
        $printbase ; printf("fd %d buf %p\n", \$fd, \$buf);
        window = 1;
    } else {
        window = 0;
    }
}

probe syscall.fsync {
    $printbase ; printf("\n");
}

probe kernel.function("do_mpage_readpage").return {
    if (window == 1) {
        $printbase ; printf("bio %p\n", returnval());
        target_bio = returnval();
    }
}

probe kernel.statement("mpage_end_io_read@fs/mpage.c+6") {
    if (target_bio == \$bio) {
        $printbase ;
        printf("end bio %p\n", \$bio);
        printf("bio vcnt %x, bisize %x\n", \$bio->bi_vcnt, \$bio->bi_size);
        tmppage = \$bio->bi_io_vec->bv_page;
        $printbase ; printf("page %p\n", tmppage);
        if (target_page == tmppage) {
            tmppfn = get_pfn(tmppage);
            tmpflag = get_page_flag(tmppage);
            tmpmcount = get_page_mapcount(tmppage);
            tmpmapping = get_page_mapping(tmppage);
            tmpmapping = get_page_mapping(tmppage);
            tmpmappingflag = get_mapping_flag(tmpmapping);
            tmpmappingnrpages = get_mapping_nrpages(tmpmapping);
            $printbase ; printf("page %p\n", tmppage);
            $printbase ; printf("page pfn %x\n", tmppfn);
            $printbase ; printf("page flags %x\n", tmpflag);
            $printbase ; printf("page mapcount %x\n", tmpmcount);
            $printbase ; printf("page mapping %x\n", tmpmapping);
            $printbase ; printf("mapping flag %x\n", tmpmappingflag);
            $printbase ; printf("mapping nrpages %x\n", tmpmappingnrpages);
            # printf("bio bv_len %d\n", \$bio->bi_io_vec->bv_len);
            # printf("bio bv_offset %d\n", \$bio->bi_io_vec->bv_offset);
            # printf("bio vecpage next %p\n", \$bio->bi_io_vec->bv_page->lru->next);
        }
    }
}

probe kernel.function("filemap_fdatawait").return {
    if (returnval() != 0) {
        $printbase ; printf("ret %x\n", returnval());
        print_backtrace();
    }
}

probe kernel.function("filemap_write_and_wait_range") {
    $printbase ; printf("nrpages %x\n", \$mapping->nrpages);
}

probe kernel.function("__filemap_fdatawrite_range") {
    $printbase ; printf("\n");
}

probe kernel.trace("ext4_sync_file") {
    $printbase ; printf("\n");
}

# probe syscall.write {
#     if (execname() == "$target_process") {
#         $printbase ; printf("fd %d buf %p\n", \$fd, \$buf);
#     }
# }
# 
# # probe kernel.function("mpage_readpages") {
# #     if (window == 1) {
# ###         target_page = get_list_entry(\$pages);
# #         $printbase ; printf("page %p, %p\n", \$pages, target_page);
# #     }
# # }
# 
# probe kernel.function("find_get_page").return {
#     if (execname() == "$target_process") {
#         tmppage = returnval();
#         if (tmppage == target_page) {
#             tmppfn = get_pfn(tmppage);
#             tmpflag = get_page_flag(tmppage);
#             tmpmcount = get_page_mapcount(tmppage);
#             tmpmapping = get_page_mapping(tmppage);
#             tmpmappingflag = get_mapping_flag(tmpmapping);
#             tmpmappingnrpages = get_mapping_nrpages(tmpmapping);
#             $printbase ; printf("page %p\n", tmppage);
#             $printbase ; printf("page pfn %x\n", tmppfn);
#             $printbase ; printf("page flags %x\n", tmpflag);
#             $printbase ; printf("page mapcount %x\n", tmpmcount);
#             $printbase ; printf("page mapping %x\n", tmpmapping);
#             $printbase ; printf("mapping flag %x\n", tmpmappingflag);
#             $printbase ; printf("mapping nrpages %x\n", tmpmappingnrpages);
#         }
#     }
# }
EOF

cat ${tmpf}.stp
stap ${tmpf}.stp -g --vp 11111 -d jbd2

rm -f ${tmpf}*
